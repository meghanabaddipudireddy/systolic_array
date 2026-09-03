class systolic_agent extends uvm_agent;

    `uvm_component_utils(systolic_agent)

    // components
    systolic_driver     driver;
    systolic_monitor_in monitor_in;
    uvm_sequencer #(systolic_transaction) sequencer;

    // TLM port
    uvm_analysis_port #(systolic_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver     = systolic_driver::type_id::create("driver", this);
        monitor_in = systolic_monitor_in::type_id::create("monitor_in", this);
        sequencer  = uvm_sequencer #(systolic_transaction)::type_id::create("sequencer", this);
        ap         = new("ap", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // connect driver to sequencer
        driver.seq_item_port.connect(sequencer.seq_item_export);
        // expose monitor's analysis port upward to environment
        monitor_in.ap.connect(ap);
    endfunction

endclass