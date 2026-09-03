class systolic_env extends uvm_env;

    `uvm_component_utils(systolic_env)

    // components
    systolic_agent       agent;
    systolic_monitor_out monitor_out;
    systolic_scoreboard  scoreboard;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent       = systolic_agent::type_id::create("agent", this);
        monitor_out = systolic_monitor_out::type_id::create("monitor_out", this);
        scoreboard  = systolic_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // connect input monitor to scoreboard
        agent.ap.connect(scoreboard.ap_in);

        // connect output monitor to scoreboard
        monitor_out.ap.connect(scoreboard.ap_out);
    endfunction

endclass