interface systolic_if (input logic clk);
    logic        rst;
    logic        start;
    logic [31:0] a_in [3:0];
    logic [31:0] b_in [3:0];
    logic        done;
    logic [63:0] y_out [3:0][3:0];
endinterface