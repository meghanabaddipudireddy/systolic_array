class systolic_transaction extends uvm_sequence_item;
    //register with uvm factory
    `uvm_object_utils(systolic_transaction)

    //two input matricies
    rand logic [31:0] A [3:0][3:0];
    rand logic [31:0] B [3:0][3:0];

    //output result
    logic [63:0] C [3:0][3:0];

    //constructor
    function new(string name = "systolic_transaction");
        super.new(name);
    endfunction

    //constraints 
    constraint reasonable_values {
        foreach (A[i,j]) A[i][j] inside {[0:15]};
        foreach (B[i,j]) B[i][j] inside {[0:15]};
    }
    
endclass