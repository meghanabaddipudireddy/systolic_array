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

        vif.start <= 0;
        vif.a_in  <= '{default: 0};
        vif.b_in  <= '{default: 0};

        forever begin
            seq_item_port.get_next_item(txn);
            drive_transaction(txn);
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(systolic_transaction txn);
        // load first column of A and first row of B
        for (int i = 0; i < 4; i++) begin
            vif.a_in[i] <= txn.A[i][0];
            vif.b_in[i] <= txn.B[0][i];
        end

        // pulse start
        @(posedge vif.clk);
        vif.start <= 1;
        @(posedge vif.clk);
        vif.start <= 0;

        // feed remaining columns of A and rows of B
        for (int k = 1; k < 4; k++) begin
            @(posedge vif.clk);
            for (int i = 0; i < 4; i++) begin
                vif.a_in[i] <= txn.A[i][k];
                vif.b_in[i] <= txn.B[k][i];
            end
        end

        // wait for done
        @(posedge vif.clk iff vif.done);

        vif.start <= 0;
        vif.a_in  <= '{default: 0};
        vif.b_in  <= '{default: 0};
    endtask

endclass