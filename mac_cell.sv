module mac_cell (
  input logic clk,
  input logic rst,
  input logic mac_en,
  input logic [31:0] w_in,
  input logic [31:0] x_in,
  output logic [31:0] x_out,
  output logic [31:0] w_out,
  output logic [63:0] y
);

  always_ff @(posedge clk) begin
    if(rst) begin
      y <= '0;
      x_out <= '0;
      w_out <= '0;
    end
    else if (mac_en) begin
      y <= y + (w_in * x_in);
      x_out <= x_in;
      w_out <= w_in;
    end
  end
  
endmodule
