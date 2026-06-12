module uart_rx #(
  parameter width = 8,
  parameter oversample = 16
)(
  input  logic clk,
  input  logic rst_n,
  input  logic tick_s,
  input  logic rx,
  output logic d_valid,
  output logic [width-1:0] dout
);

  typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
  state_t state;

  logic [3:0] cnt;
  logic [3:0] cnt_s;
  logic [width-1:0] shift_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      d_valid <= 0;
      cnt <= 0;
      cnt_s <= 0;
    end else begin
      d_valid <= 0; 

      if (tick_s) begin
        case (state)
          IDLE: begin
            if (!rx) begin
              cnt_s <= 0;
              state <= START;
            end
          end
          START: begin
            if (cnt_s == oversample/2) begin
              if (!rx) begin
                state <= DATA;
                cnt <= 0;
                cnt_s <= 0;
              end else begin
                state <= IDLE;
              end
            end else begin
              cnt_s <= cnt_s + 1;
            end
          end
          DATA: begin
            if (cnt_s == oversample - 1) begin
              cnt_s <= 0;
              shift_reg <= {rx, shift_reg[width-1:1]};
              cnt <= cnt + 1;
              if (cnt == width - 1) begin
                state <= STOP;
              end
            end else begin
              cnt_s <= cnt_s + 1;
            end
          end 
          STOP: begin
            if (cnt_s == oversample - 1) begin
              dout <= shift_reg;
              d_valid <= 1;
              state <= IDLE;
            end else begin
              cnt_s <= cnt_s + 1;
            end
          end
        endcase
      end
    end
  end
endmodule