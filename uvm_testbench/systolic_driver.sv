import uvm_pkg::*;
`include "uvm_macros.svh"

class systolic_driver extends uvm_driver #(systolic_transaction);

    `uvm_component_utils(systolic_driver)

    virtual systolic_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual systolic_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        systolic_transaction txn;

        vif.rst   = 1;
        vif.start = 0;
        vif.a_in  = '{default: 0};
        vif.b_in  = '{default: 0};

        // The driver owns reset, including startup and each independent multiply.
        repeat (4) @(negedge vif.clk);
        vif.rst = 0;

        forever begin
            seq_item_port.get_next_item(txn);
            drive_transaction(txn);
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(systolic_transaction txn);
        // Clear accumulators and flush the unreset skew chains with zeros.
        // All stimulus changes on falling edges, away from RTL sampling edges.
        @(negedge vif.clk);
        vif.rst = 1;
        vif.start = 0;
        vif.a_in = '{default: 0};
        vif.b_in = '{default: 0};
        repeat (4) @(negedge vif.clk);
        vif.rst = 0;
        vif.start = 1;

        // The next rising edge accepts start; operands stay zero until then.
        @(negedge vif.clk);
        vif.start = 0;
        for (int k = 0; k < 4; k++) begin
            for (int i = 0; i < 4; i++) begin
                vif.a_in[i] = txn.A[i][k];
                vif.b_in[i] = txn.B[k][i];
            end
            @(negedge vif.clk);
        end

        // Supply bubbles while the final products propagate through the array.
        vif.a_in = '{default: 0};
        vif.b_in = '{default: 0};
        @(posedge vif.clk iff vif.done);
        // Allow the output monitor to capture before another reset can occur.
        @(negedge vif.clk);
    endtask

endclass
