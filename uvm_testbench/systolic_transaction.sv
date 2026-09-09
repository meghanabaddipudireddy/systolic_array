import uvm_pkg::*;
`include "uvm_macros.svh"

class systolic_transaction extends uvm_sequence_item;

    `uvm_object_utils(systolic_transaction)

    rand logic [31:0] A [3:0][3:0];
    rand logic [31:0] B [3:0][3:0];
    logic [63:0]      C [3:0][3:0];

    function new(string name = "systolic_transaction");
        super.new(name);
    endfunction

    constraint reasonable_values {
        foreach (A[i,j]) A[i][j] inside {[0:15]};
        foreach (B[i,j]) B[i][j] inside {[0:15]};
    }

endclass