module fifo #(
  parameter WIDTH = 8,
  parameter DEPTH = 16
)(
  input  logic clk,
  input  logic rst_n,
  input  logic w_en,
  input  logic r_en,
  input  logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout,
  output logic full,
  output logic empty
);

  localparam ADDR_W = $clog2(DEPTH);
  
  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [ADDR_W:0]  count;
  logic [ADDR_W-1:0] w_ptr, r_ptr;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  
  // FWFT behavior: Data is available immediately without waiting for clock edge
  assign dout  = mem[r_ptr]; 

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_ptr <= 0;
      r_ptr <= 0;
      count <= 0;
    end else begin
      case ({w_en & ~full, r_en & ~empty})
        2'b10: begin // Write only
          mem[w_ptr] <= din;
          w_ptr <= w_ptr + 1;
          count <= count + 1;
        end
        2'b01: begin // Read only
          r_ptr <= r_ptr + 1;
          count <= count - 1;
        end
        2'b11: begin // Write and Read at the same time
          mem[w_ptr] <= din;
          w_ptr <= w_ptr + 1;
          r_ptr <= r_ptr + 1;
          // Count stays the same
        end
      endcase
    end
  end
endmodule