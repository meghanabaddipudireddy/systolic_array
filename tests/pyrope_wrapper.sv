// Restore the original RTL's unpacked array ports for test_systolic.py.
module pyrope_wrapper (
  input wire clk,
  input wire rst,
  input wire start,
  input wire [31:0] a_in [3:0],
  input wire [31:0] b_in [3:0],
  output wire done,
  output wire [63:0] y_out [3:0][3:0]
);
  wire [127:0] a_packed, b_packed;
  wire [1023:0] y_packed;

  for (genvar i = 0; i < 4; i++) begin : rows
    assign a_packed[32*i +: 32] = a_in[i];
    assign b_packed[32*i +: 32] = b_in[i];
    for (genvar j = 0; j < 4; j++) begin : cols
      assign y_out[i][j] = y_packed[64*(4*i+j) +: 64];
    end
  end

  top dut (
    .clk(clk), .rst(rst), .start(start), .done(done),
    .a_in(a_packed), .b_in(b_packed), .y_out(y_packed)
  );
endmodule
