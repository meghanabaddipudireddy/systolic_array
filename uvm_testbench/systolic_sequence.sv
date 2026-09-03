class systolic_sequence extends uvm_sequence #(systolic_transaction);

    `uvm_object_utils(systolic_sequence)

    // how many matrix multiplies to run
    int unsigned num_transactions = 10;

    function new(string name = "systolic_sequence");
        super.new(name);
    endfunction

    task body();
        systolic_transaction txn;

        repeat (num_transactions) begin
            // create a new transaction
            txn = systolic_transaction::type_id::create("txn");

            // start the transaction
            start_item(txn);

            // randomize it 
            if (!txn.randomize())
                `uvm_fatal("SEQ", "Randomization failed")

            // send it to the driver
            finish_item(txn);
        end
    endtask

endclass