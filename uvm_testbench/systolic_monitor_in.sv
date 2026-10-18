import uvm_pkg::*;
`include "uvm_macros.svh"

class systolic_monitor_in extends uvm_monitor;

    `uvm_component_utils(systolic_monitor_in)

    virtual systolic_if vif;
    uvm_analysis_port #(systolic_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual systolic_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON_IN", "Could not get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        systolic_transaction txn;

        forever begin
            @(posedge vif.clk iff (vif.start && !vif.rst));

            txn = systolic_transaction::type_id::create("txn");

            // First operands are sampled one cycle after start is accepted.
            for (int k = 0; k < 4; k++) begin
                @(posedge vif.clk);
                for (int i = 0; i < 4; i++) begin
                    txn.A[i][k] = vif.a_in[i];
                    txn.B[k][i] = vif.b_in[i];
                end
            end

            ap.write(txn);
        end
    endtask

endclass