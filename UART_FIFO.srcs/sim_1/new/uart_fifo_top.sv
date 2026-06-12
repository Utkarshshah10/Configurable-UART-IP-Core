module uart_fifo_top #(
  parameter width = 8,
  parameter oversample = 16
)(
  input  logic clk,
  input  logic rst_n,

  // FIFO Write Interface (from Testbench)
  input  logic w_en,
  input  logic [width-1:0] din,
  output logic full,

  // UART Serial Lines
  input  logic rx,
  output logic tx,

  // Receiver Interface (to Testbench)
  output logic rx_valid,
  output logic [width-1:0] dout
);

  // Internal connecting wires
  logic tick;            
  logic tick_s;          
  logic fifo_empty;
  logic tx_ready;        
  logic tx_start;        
  logic [width-1:0] tx_data; 

  // Start sending if FIFO is not empty AND TX is ready for new data
  assign tx_start = ~fifo_empty && tx_ready && tick;

  // 1. Baud Generator
  baud_gen BAUD_INST (
    .clk(clk),
    .rst_n(rst_n),
    .tick(tick),
    .tick_s(tick_s)
  );

  // 2. Transmit FIFO
  fifo #( .WIDTH(width), .DEPTH(16) ) TX_FIFO_INST (
    .clk(clk),
    .rst_n(rst_n),
    .w_en(w_en),
    .din(din),
    .r_en(tx_start),   // Read byte from FIFO when TX starts
    .dout(tx_data),
    .full(full),
    .empty(fifo_empty)
  );

  // 3. UART Transmitter
  uart_tx #(width) TX_INST (
    .clk(clk),
    .rst_n(rst_n),
    .tick(tick),
    .d_valid(tx_start), 
    .din(tx_data),
    .tx(tx),
    .d_ready(tx_ready)
  );

  // 4. UART Receiver
  uart_rx #(width, oversample) RX_INST (
    .clk(clk),
    .rst_n(rst_n),
    .tick_s(tick_s),
    .rx(rx),
    .d_valid(rx_valid),
    .dout(dout)
  );

endmodule