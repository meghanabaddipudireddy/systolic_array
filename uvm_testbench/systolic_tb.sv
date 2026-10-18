`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

module systolic_tb;

    import uvm_pkg::*;
    import systolic_pkg::*;
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

    // The UVM driver owns reset and holds it across clock edges.
    initial begin
        uvm_config_db #(virtual systolic_if)::set(null, "uvm_test_top.*", "vif", vif);
        run_test("systolic_test");
    end

    initial begin
        #100000;
        $fatal(1, "UVM simulation timed out");
    end
endmodule
