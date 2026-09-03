class systolic_driver extends uvm_driver #(systolic_transaction);

    `uvm_component_utils(systolic_driver)

    // virtual interface 
    virtual systolic_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // get the virtual interface from the config database
        if (!uvm_config_db #(virtual systolic_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        systolic_transaction txn;

        // initialize signals
        vif.start <= 0;
        vif.a_in  <= '{default: 0};
        vif.b_in  <= '{default: 0};

        forever begin
            // get next transaction from sequence
            seq_item_port.get_next_item(txn);

            // drive the transaction
            drive_transaction(txn);

            // tell sequence we're done
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(systolic_transaction txn);
        // load matrix A rows and B columns
        for (int i = 0; i < 4; i++) begin
            vif.a_in[i] <= txn.A[i][0];  // feed one element per row per cycle
            vif.b_in[i] <= txn.B[0][i];  // feed one element per col per cycle
        end

        // pulse start
        @(posedge vif.clk);
        vif.start <= 1;
        @(posedge vif.clk);
        vif.start <= 0;

        // feed remaining columns of A and rows of B each cycle
        for (int k = 1; k < 4; k++) begin
            @(posedge vif.clk);
            for (int i = 0; i < 4; i++) begin
                vif.a_in[i] <= txn.A[i][k];
                vif.b_in[i] <= txn.B[k][i];
            end
        end

        // wait for done
        @(posedge vif.clk iff vif.done);

        // clear inputs
        vif.start <= 0;
        vif.a_in  <= '{default: 0};
        vif.b_in  <= '{default: 0};
    endtask

endclass