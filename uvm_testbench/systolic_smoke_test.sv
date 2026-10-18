// Deterministic end-to-end test: no external randomization solver required.
class systolic_smoke_sequence extends uvm_sequence #(systolic_transaction);
    `uvm_object_utils(systolic_smoke_sequence)
    function new(string name = "systolic_smoke_sequence");
        super.new(name);
    endfunction
    task body();
        systolic_transaction txn;
        for (int mode = 0; mode < 3; mode++) begin
            txn = systolic_transaction::type_id::create("txn");
            start_item(txn);
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 4; j++) begin
                    txn.A[i][j] = 4*i+j+1;
                    case (mode)
                        0: txn.B[i][j] = 4*i+j+1;
                        1: txn.B[i][j] = (i == j) ? 1 : 0;
                        2: txn.B[i][j] = 0;
                    endcase
                end
            finish_item(txn);
        end
    endtask
endclass

class systolic_smoke_test extends systolic_test;
    `uvm_component_utils(systolic_smoke_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        systolic_smoke_sequence seq;
        phase.raise_objection(this);
        seq = systolic_smoke_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        // Let monitor/scoreboard callbacks complete before checking totals.
        #20;
        if (env.scoreboard.pass_count != 48 || env.scoreboard.fail_count != 0 ||
            env.scoreboard.input_queue.size() != 0 ||
            env.scoreboard.output_queue.size() != 0)
            `uvm_fatal("SMOKE", "Expected exactly 48 matching outputs and empty scoreboard queues")
        else
            `uvm_info("SMOKE", "UVM_SMOKE_PASS: 3 matrices, 48 matching outputs", UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass
