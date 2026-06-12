// --- Transaction ---
class uart_txn #(parameter width = 8);
  rand bit [width-1:0] data;
  rand bit [7:0] delay_cycles;

  constraint traffic_c {
    delay_cycles inside {[1:20]};
  }
endclass

// --- Generator ---
class generator #(parameter width = 8);
  mailbox #(uart_txn #(width)) gen2drv;
  int num_txn = 2000;
  event gen_done;

  function new(mailbox #(uart_txn #(width)) m);
    gen2drv = m;
  endfunction

  task run();
    uart_txn #(width) t;
    repeat (num_txn) begin
      t = new();
      if (!t.randomize()) $fatal ("[GEN] Randomization Failed!"); 
      gen2drv.put(t);
    end
    ->gen_done;
  endtask
endclass

// --- Driver --- 
class driver #(parameter width = 8); 
  mailbox #(uart_txn #(width)) gen2drv;
  virtual uart_if #(width) vif;

  function new(virtual uart_if #(width) vif, mailbox #(uart_txn #(width)) m);
    this.vif = vif;
    gen2drv = m;
  endfunction

  task run();
    uart_txn #(width) t;
    
    vif.drv_cb.w_en <= 0; 
    vif.drv_cb.din <= 0;

    forever begin
      gen2drv.get(t);
      repeat (t.delay_cycles) @(vif.drv_cb);

      while (vif.drv_cb.full == 1) begin
        @(vif.drv_cb); 
      end

      vif.drv_cb.w_en <= 1;
      vif.drv_cb.din <= t.data;

      @(vif.drv_cb);
      vif.drv_cb.w_en <= 0;
    end
  endtask 
endclass

// --- Monitor ---
class monitor #(parameter width = 8);
  mailbox #(bit [width-1:0]) act_mbx;
  mailbox #(bit [width-1:0]) exp_mbx;
  virtual uart_if #(width) vif; 

  int baud_time;
  int clk_f = 50_000_000;
  int baud = 115200;

  function new(mailbox #(bit [width-1:0]) a,
               mailbox #(bit [width-1:0]) e,
               virtual uart_if #(width) vif);
    this.vif = vif;
    exp_mbx = e;
    act_mbx = a;
    baud_time = clk_f / baud;
  endfunction

  task run();
    fork 
      // Thread 1: Capture expected data
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.w_en && !vif.mon_cb.full) begin
          exp_mbx.put(vif.mon_cb.din); 
        end
      end

     
   // Thread 2: Capture actual data from DUT Receiver
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.rx_valid) begin
          act_mbx.put(vif.mon_cb.dout); 
        end
      end
    join_none
  endtask
endclass

// --- Scoreboard ---
class scoreboard #(parameter width = 8);
  mailbox #(bit [width-1:0]) exp_mbx; 
  mailbox #(bit [width-1:0]) act_mbx;
  
  bit [width-1:0] ref_q[$];
  int pass = 0, fail = 0; 

  function new(mailbox #(bit [width-1:0]) e,
               mailbox #(bit [width-1:0]) a);
    exp_mbx = e;
    act_mbx = a;
  endfunction

  task run();
    bit [width-1:0] act_data, exp_data;
    fork 
      forever begin
        exp_mbx.get(exp_data);
        ref_q.push_back(exp_data);
      end

      forever begin
        act_mbx.get(act_data);
        if (ref_q.size() == 0) begin
          $error("[SCB] Empty queue! Unexpected act_data: %0h", act_data);
          fail++;
        end else begin
          exp_data = ref_q.pop_front();
          if (act_data !== exp_data) begin
            $error("[SCB] MISMATCH - Exp: %0h, Act: %0h", exp_data, act_data);
            fail++;
          end else begin
            pass++;
          end
        end
      end
    join_none
  endtask

  function void check_pipeline();
    if (ref_q.size() > 0) begin
      $error("[SCB] %0d bytes stuck in pipeline", ref_q.size());
      fail++;
    end
  endfunction
endclass

// --- Environment ---
class environment #(parameter width = 8);
  generator  #(width) gen;
  driver     #(width) drv;
  monitor    #(width) mon;
  scoreboard #(width) scb;

  mailbox #(uart_txn #(width)) gen2drv_mbx;
  mailbox #(bit [width-1:0])   exp_mbx;
  mailbox #(bit [width-1:0])   act_mbx;

  virtual uart_if #(width) vif;

  function new(virtual uart_if #(width) vif);
    this.vif = vif;
    gen2drv_mbx = new();
    exp_mbx = new();
    act_mbx = new();

    gen = new(gen2drv_mbx);
    drv = new(vif, gen2drv_mbx);
    mon = new(act_mbx, exp_mbx, vif);
    scb = new(exp_mbx, act_mbx);
  endfunction

  task run();
    fork
      gen.run();
      drv.run();
      mon.run();
      scb.run();
    join_none // Let all threads run in the background

    // Wait for the generator to finish creating items
    wait(gen.gen_done.triggered);

    // Wait for the driver to empty the mailbox into the DUT
    wait(drv.gen2drv.num() == 0);

    // Allow enough time for all bytes to physically transmit over UART.
    #200_000_000; 
    
    scb.check_pipeline();
    $display("-----------------------------------------");
    $display("[ENV] Simulation Complete. PASS: %0d, FAIL: %0d", scb.pass, scb.fail);
    $display("-----------------------------------------");
    $finish;
  endtask
  endclass