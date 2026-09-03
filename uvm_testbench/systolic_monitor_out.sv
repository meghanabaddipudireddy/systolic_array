// OUTPUT MONITOR: watches done and y_out
class systolic_monitor_out extends uvm_monitor;

    `uvm_component_utils(systolic_monitor_out)

    virtual systolic_if vif;

    uvm_analysis_port #(systolic_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual systolic_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON_OUT", "Could not get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        systolic_transaction txn;

        forever begin
            // wait for done to pulse
            @(posedge vif.clk iff vif.done);

            txn = systolic_transaction::type_id::create("txn");

            // capture all 16 results
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 4; j++)
                    txn.C[i][j] = vif.y_out[i][j];

            // send to scoreboard
            ap.write(txn);
        end
    endtask

endclass