`timescale 1ns/1ps

// --- Interface ---
interface uart_if #(parameter width = 8)(input logic clk);
  logic rst_n;

  // FIFO IN
  logic w_en;
  logic [width-1:0] din;
  logic full;

  // UART OUT
  logic rx, tx;
  logic rx_valid;
  logic [width-1:0] dout;

  // Clocking
  clocking drv_cb @(posedge clk);
    default input #1step output #1ns;
    input full;
    output w_en, din;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1ns;
    input w_en, rx_valid, rx, tx, din, dout, full;
  endclocking

  // Assertion
  property prevent_overflow;
    @(posedge clk) disable iff (!rst_n) 
    full |-> !w_en;
  endproperty
  
  assert property (prevent_overflow) else $error("[SVA] Wrote while Full");
endinterface

// Compile the classes AFTER the interface so virtual interfaces work properly
`include "uart_tb_class.sv"

// --- Top Module ---
module tb_top;
  logic clk;
  
  // Clock Generation (50MHz)
  initial begin
    clk = 0;
    forever #10 clk = ~clk; 
  end

  // Interface Instantiation
  uart_if #(8) vif(clk);
  assign vif.rx = vif.tx;
// Instantiating the DUT (UART TX/RX wrapped with FIFO)
  uart_fifo_top DUT (
      // Clock and Reset
      .clk      (clk),
      .rst_n    (vif.rst_n),

      // FIFO Write Interface (from Testbench to DUT)
      .w_en     (vif.w_en),
      .din      (vif.din),
      .full     (vif.full),

      // UART Serial Lines
      .rx       (vif.rx),
      .tx       (vif.tx),

      // Receiver Interface (from DUT to Testbench)
      .rx_valid (vif.rx_valid),
      .dout     (vif.dout)
  );
  // Testbench Environment execution
  environment #(8) env;

  initial begin
    // Reset Generation
    vif.rst_n = 0;
    #50;
    vif.rst_n = 1;

    // Start Environment
    env = new(vif);
    env.run();
  end
  
  // Dump waveforms for Vivado
  initial begin
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end
endmodule