module uart_tx #(parameter width = 8)(
  input  logic clk,
  input  logic rst_n,
  input  logic tick,
  input  logic d_valid,
  input  logic [width-1:0] din,
  output logic tx,
  output logic d_ready
);

  typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
  state_t state;

  logic [width-1:0] shift_reg;
  logic [3:0] bit_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      tx <= 1;
      bit_cnt <= 0;
    end else if (tick) begin
      case(state)
        IDLE: begin
          tx <= 1;
          if (d_valid) begin
            shift_reg <= din;
            state <= START;
          end
        end
        START: begin
          tx <= 0;
          state <= DATA;
          bit_cnt <= 0;
        end
        DATA: begin
          tx <= shift_reg[0];
          shift_reg <= shift_reg >> 1;
          bit_cnt <= bit_cnt + 1;
          if (bit_cnt == width - 1) begin
            state <= STOP;
          end
        end
        STOP: begin
          tx <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
  assign d_ready = (state == IDLE);
endmodule