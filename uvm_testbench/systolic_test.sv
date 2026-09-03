class systolic_test extends uvm_test;

    `uvm_component_utils(systolic_test)

    systolic_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = systolic_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        systolic_sequence seq;

        // tell UVM simulation shouldn't end yet
        phase.raise_objection(this);

        // create and start the sequence
        seq = systolic_sequence::type_id::create("seq");
        seq.num_transactions = 20;  // run 20 random matrix multiplies
        seq.start(env.agent.sequencer);

        // small delay then allow simulation to end
        #100;
        phase.drop_objection(this);
    endtask

endclass