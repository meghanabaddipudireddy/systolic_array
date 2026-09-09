import uvm_pkg::*;
`include "uvm_macros.svh"

class systolic_sequence extends uvm_sequence #(systolic_transaction);

    `uvm_object_utils(systolic_sequence)

    int unsigned num_transactions = 20;

    function new(string name = "systolic_sequence");
        super.new(name);
    endfunction

    task body();
        systolic_transaction txn;

        repeat (num_transactions) begin
            txn = systolic_transaction::type_id::create("txn");
            start_item(txn);
            if (!txn.randomize())
                `uvm_fatal("SEQ", "Randomization failed")
            finish_item(txn);
        end
    endtask

endclass