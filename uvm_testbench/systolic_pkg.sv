package systolic_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Include classes once, in dependency order.
    `include "systolic_transaction.sv"
    `include "systolic_sequence.sv"
    `include "systolic_driver.sv"
    `include "systolic_monitor_in.sv"
    `include "systolic_monitor_out.sv"
    `include "systolic_scoreboard.sv"
    `include "systolic_agent.sv"
    `include "systolic_env.sv"
    `include "systolic_test.sv"
    `include "systolic_smoke_test.sv"
endpackage
