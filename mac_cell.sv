module mac_cell (
  input logic clk,
  input logic rst,
  input logic mac_en,
  input logic w_in,
  input logic x_in,
  output logic x_out,
  output logic w_out,
  output logic y
);

  always_ff @(posedge clk) begin
    if(rst) begin
      y <= 1'b0;
      x_out <= 1'b0;
      w_out <= 1'b0;
    end
    else if (mac_en) begin
      y <= y + (w_in * x_in);
      x_out <= x_in;
      w_out <= x_out;
    end
  end
  
endmodule
