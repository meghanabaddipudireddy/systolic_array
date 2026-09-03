class systolic_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(systolic_scoreboard)

    // TLM ports to receive from both monitors
    uvm_analysis_imp_decl(_in)
    uvm_analysis_imp_decl(_out)

    uvm_analysis_imp_in  #(systolic_transaction, systolic_scoreboard) ap_in;
    uvm_analysis_imp_out #(systolic_transaction, systolic_scoreboard) ap_out;

    // queues to hold transactions until both sides arrive
    systolic_transaction input_queue  [$];
    systolic_transaction output_queue [$];

    // tracking
    int pass_count = 0;
    int fail_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_in  = new("ap_in",  this);
        ap_out = new("ap_out", this);
    endfunction

    // called when input monitor sends a transaction
    function void write_in(systolic_transaction txn);
        input_queue.push_back(txn);
        check_result();
    endfunction

    // called when output monitor sends a transaction
    function void write_out(systolic_transaction txn);
        output_queue.push_back(txn);
        check_result();
    endfunction

    function void check_result();
        systolic_transaction in_txn, out_txn;
        logic [63:0] expected [3:0][3:0];

        // only check if both input and output have arrived
        if (input_queue.size() == 0 || output_queue.size() == 0)
            return;

        // pop one from each queue
        in_txn  = input_queue.pop_front();
        out_txn = output_queue.pop_front();

        // compute expected C = A × B in software
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                expected[i][j] = 0;
                for (int k = 0; k < 4; k++)
                    expected[i][j] += (64'(in_txn.A[i][k]) * 64'(in_txn.B[k][j]));
            end
        end

        // compare expected vs actual
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                if (expected[i][j] !== out_txn.C[i][j]) begin
                    `uvm_error("SB", $sformatf(
                        "FAIL: C[%0d][%0d] expected %0d got %0d",
                        i, j, expected[i][j], out_txn.C[i][j]))
                    fail_count++;
                end else begin
                    pass_count++;
                end
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf(
            "Results: %0d passed, %0d failed",
            pass_count, fail_count), UVM_NONE)
        if (fail_count > 0)
            `uvm_fatal("SB", "TEST FAILED")
        else
            `uvm_info("SB", "ALL TESTS PASSED", UVM_NONE)
    endfunction

endclass