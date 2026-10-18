`timescale 1ns/1ps
module systolic_tb;
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst = 1, start = 0, done;
  logic [31:0] a_in [3:0], b_in [3:0];
  wire [63:0] y_out [3:0][3:0];
  logic [31:0] a [0:3][0:3], b [0:3][0:3];
  logic [63:0] expected;
  int errors = 0;
  top dut (.*);

  task automatic clear_inputs;
    for (int i = 0; i < 4; i++) begin
      a_in[i] = 0;
      b_in[i] = 0;
    end
  endtask

  task automatic run_case(input string name);
    int cycles;
    // Keep zeros through reset to flush the unreset skew registers.
    @(negedge clk);
    rst = 1;
    start = 0;
    clear_inputs();
    repeat (4) @(negedge clk);
    rst = 0;
    start = 1;
    @(negedge clk);
    start = 0;
    // A column k and B row k enter together; RTL performs skewing.
    for (int k = 0; k < 4; k++) begin
      for (int i = 0; i < 4; i++) begin
        a_in[i] = a[i][k];
        b_in[i] = b[k][i];
      end
      @(negedge clk);
    end
    clear_inputs();
    cycles = 4;
    while (!done && cycles < 20) begin
      @(negedge clk);
      cycles++;
    end
    $display("TEST %s: done=%0b after %0d compute cycles", name, done, cycles);
    if (!done) begin
      $display("FAIL: timeout");
      errors++;
    end
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        expected = 0;
        for (int k = 0; k < 4; k++)
          expected += 64'(a[i][k]) * 64'(b[k][j]);
        if (y_out[i][j] !== expected) begin
          $display("FAIL %s C[%0d][%0d]: expected %0d, got %0d", name, i, j, expected, y_out[i][j]);
          errors++;
        end
      end
      $display("  result row %0d: %0d %0d %0d %0d", i,
               y_out[i][0], y_out[i][1], y_out[i][2], y_out[i][3]);
    end
    @(negedge clk);
    if (done) begin
      $display("FAIL: done must pulse for one cycle");
      errors++;
    end
  endtask

  initial begin
    clear_inputs();
    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 4; j++) begin
        a[i][j] = 32'(4*i+j+1);
        b[i][j] = 32'(4*i+j+1);
      end
    run_case("A_times_A_1_to_16");
    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 4; j++) b[i][j] = 32'(i == j);
    run_case("A_times_identity");
    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 4; j++) b[i][j] = 0;
    run_case("A_times_zero");
    if (errors) $fatal(1, "%0d checks failed", errors);
    $display("PASS: all checks passed");
    $finish;
  end
  initial begin
    #5000;
    $fatal(1, "Global timeout");
  end
endmodule
