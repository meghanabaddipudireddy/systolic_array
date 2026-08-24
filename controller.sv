module controller(
  input logic clk,
  input logic rst,
  input logic start,
  input logic count_done,
  output logic done,
  output logic mac_en
);
  typedef enum logic [1:0] {IDLE, COMPUTE, DONE} state_t;
  state_t state, next_state;

  always_ff @(posedge clk) begin
    if(rst) begin
      state <= IDLE;
    end
    else begin
      state <= next_state;
    end
  end

  always_comb begin
    case(state)
      IDLE:
        if(start) begin
          next_state = COMPUTE;
        end
        else begin
          next_state = IDLE;
        end
      COMPUTE:
        if(count_done) begin
          next_state = DONE;
        end
        else begin
          next_state = COMPUTE;
        end
      DONE: next_state = IDLE;

      default: next_state = IDLE;
    endcase
  end

  assign done = (state == DONE);
  assign mac_en = (state == COMPUTE);
  
endmodule
      
