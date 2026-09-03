module systolic_tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // import all UVM classes
    `include "systolic_transaction.sv"
    `include "systolic_sequence.sv"
    `include "systolic_driver.sv"
    `include "systolic_monitor_in.sv"
    `include "systolic_monitor_out.sv"
    `include "systolic_scoreboard.sv"
    `include "systolic_agent.sv"
    `include "systolic_env.sv"
    `include "systolic_test.sv"

    // clock
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    // interface instance
    systolic_if vif (.clk(clk));

    // DUT
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
        // put interface in config database so components can get it
        uvm_config_db #(virtual systolic_if)::set(null, "uvm_test_top.*", "vif", vif);

        // reset
        vif.rst = 1;
        #20;
        vif.rst = 0;

        // start the test
        run_test("systolic_test");
    end

endmodule