module baud_gen #(
  parameter int CLK_FREQ = 50_000_000, 
  parameter int BAUD = 115200,
  parameter int OVERSAMPLE = 16
)(
  input  logic clk,
  input  logic rst_n,
  output logic tick,
  output logic tick_s
);
  localparam int DIV = CLK_FREQ / BAUD;
  localparam int DIV_S = CLK_FREQ / (BAUD * OVERSAMPLE); 

  logic [$clog2(DIV)-1:0] cnt;
  logic [$clog2(DIV_S)-1:0] cnt_s;

  // Baud tick logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 0;
      tick <= 0;
    end else begin
      if (cnt == DIV - 1) begin
        cnt <= 0;
        tick <= 1;
      end else begin
        cnt <= cnt + 1;
        tick <= 0;
      end
    end
  end

  // Oversample baud tick logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_s <= 0;
      tick_s <= 0;
    end else begin
      if (cnt_s == DIV_S - 1) begin
        cnt_s <= 0;
        tick_s <= 1;
      end else begin
        cnt_s <= cnt_s + 1;
        tick_s <= 0;
      end
    end
  end
endmodule