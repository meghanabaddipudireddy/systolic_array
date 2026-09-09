import uvm_pkg::*;
`include "uvm_macros.svh"

module systolic_tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    systolic_if vif (.clk(clk));

    top uut (
        .clk   (clk),
        .rst   (vif.rst),
        .start (vif.start),
        .a_in  (vif.a_in),
        .b_in  (vif.b_in),
        .done  (vif.done),
        .y_out (vif.y_out)
    );

    initial begin
        uvm_config_db #(virtual systolic_if)::set(null, "uvm_test_top.*", "vif", vif);

        vif.rst = 1;
        #20;
        vif.rst = 0;

        run_test("systolic_test");
    end

endmodule