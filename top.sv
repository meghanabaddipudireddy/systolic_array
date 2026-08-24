
module top(
  input logic clk,
  input logic rst,
  input logic start,
  input logic [31:0] a_in [3:0],
  input logic [31:0] b_in [3:0],
  output logic done,
  output logic [63:0] y_out [3:0][3:0]
);

  //a_in - mac - mac - mac - mac
  logic [31:0] x_wire [3:0][4:0];
  //b_in - mac - mac - mac - mac
  logic [31:0] w_wire [4:0][3:0];

  // A matrix inputs to left boundary
  assign x_wire[0][0] = a_skew[0];
  assign x_wire[1][0] = a_skew[1];
  assign x_wire[2][0] = a_skew[2];
  assign x_wire[3][0] = a_skew[3];

  // B matrix inputs to top boundary
  assign w_wire[0][0] = b_skew[0];
  assign w_wire[0][1] = b_skew[1];
  assign w_wire[0][2] = b_skew[2];
  assign w_wire[0][3] = b_skew[3];

  // controller and counter logic
  logic mac_en;
  logic [2:0] count;
  logic count_done;
  // count is done is counter at 6
  assign count_done = (count == 3'd6);

  //counter should only run on compute (mac_en signal)
  always_ff @(posedge clk) begin
    if (rst)
        count <= 3'b0;
    else if (mac_en && !count_done)
        count <= count + 1;
    else if (!mac_en)
        count <= 3'b0;
  end

  //instantiate controller
  controller u_ctrl (
    .clk       (clk),
    .rst       (rst),
    .start     (start),
    .count_done(count_done),
    .done      (done),
    .mac_en    (mac_en)
  );

  // generate block to instantiate 16 MAC cells
  genvar i, j;
  generate
    for (i = 0; i < 4; i++) begin : row
        for (j = 0; j < 4; j++) begin : col
            mac_cell mac (
                .clk   (clk),
                .rst   (rst),
                .mac_en(mac_en),
                .x_in  (x_wire[i][j]),
                .w_in  (w_wire[i][j]),
                .x_out (x_wire[i][j+1]),
                .w_out (w_wire[i+1][j]),
                .y     (y_out[i][j])
            );
        end
    end
  endgenerate

  //skewing - needed or else wrong data will meet wrong data at each cell, so increase number of cycles
  //each row is delayed by row index
  logic [31:0] a_skew [3:0];

  //row 0 (no delay)
  assign a_skew[0] = a_in[0];

  //row 1 (1 cycle delay)
  always_ff @(posedge clk) begin
    a_skew[1] <= a_in[1];
  end

  //row 2 (2 cycle delay)
  logic [31:0] a_delay2;
  always_ff @(posedge clk) begin
    a_delay2  <= a_in[2];
    a_skew[2] <= a_delay2;
  end

  //row 3 (3 cycle delay)
  logic [31:0] a_delay3a, a_delay3b;
  always_ff @(posedge clk) begin
    a_delay3a <= a_in[3];
    a_delay3b <= a_delay3a;
    a_skew[3] <= a_delay3b;
  end

  //each column delayed by column index
  logic [31:0] b_skew [3:0];

  //column 0 (no delay)
  assign b_skew[0] = b_in[0];

  //column 1 (1 cycle delay)
  always_ff @(posedge clk) begin
    b_skew[1] <= b_in[1];
  end

  //column 2 (2 cycle delay)
  logic [31:0] b_delay2;
  always_ff @(posedge clk) begin
    b_delay2  <= b_in[2];
    b_skew[2] <= b_delay2;
  end

  //column 3 (3 cycle delay)
  logic [31:0] b_delay3a, b_delay3b;
  always_ff @(posedge clk) begin
    b_delay3a <= b_in[3];
    b_delay3b <= b_delay3a;
    b_skew[3] <= b_delay3b;
  end
  

endmodule
