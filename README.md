# Parameterized UART IP Core with Elastic FWFT FIFO

A fully parameterizable, Silicon-ready SystemVerilog UART Communication Bridge. This IP core is designed to safely transfer data across varying clock domains from a high-speed CPU host to a physical serial line. It features an integrated First-Word Fall-Through (FWFT) FIFO buffer to prevent CPU bottlenecking, and a 16x oversampling receiver FSM for high-fidelity physical layer noise rejection.

### System Architecture
*(The dataflow travels from the upstream CPU host, through the elastic buffer, and out to the physical serial line).*

![Architecture Blueprint](docs/Architecture_block_diagram.png)

## Key Hardware Features

* **Parameterized Configuration:** Clock frequency and Baud rate are passed as parameters, allowing dynamic synthesis for various FPGA/ASIC targets without altering the RTL logic.
* **Elastic FWFT Buffer (First-Word Fall-Through):** The transmitter pipeline utilizes an asynchronous read architecture, eliminating read-latency. The oldest byte sits directly on the output pins, ready to be immediately latched by the UART TX state machine.
* **16x Oversampling Receiver:** The RX module operates on a clock pulse 16 times faster than the baud rate. This allows the state machine to bypass transient line noise and sample the exact 50% dead-center phase of the incoming bits, compensating for crystal oscillator drift between communicating hardware.
* **Fail-Safe Line Detection:** Strictly adheres to UART protocol standards, including `Logic 1` IDLE states for physical wire-break detection.

### Receiver Finite State Machine (FSM) Mechanics

![FSM Mechanics](docs/FSM_Receiver_Mechanics.png)

## Verification Architecture

The IP was verified using a layered, Object-Oriented SystemVerilog (OOP) testbench environment modeled after industry-standard methodologies. 

**Verification Highlights:**
* **Digital Loopback E2E Testing:** The Transmitter's serial `tx` output was physically tied back into the Receiver's `rx` input at the top level. The testbench verified End-to-End (E2E) throughput rather than isolated unit tests.
* **Randomized Traffic Generation:** The generator randomized data payloads and injected random clock cycle delays between transactions to mimic realistic, staggered CPU write bursts.
* **Automated Scoreboard:** The scoreboard utilized a reference queue to ensure zero bytes were dropped, duplicated, or corrupted across 2,000 randomized transactions.

**Simulation Results:**
`[ENV] Simulation Execution Complete. PASS: 2000, FAIL: 0`

## Repository Structure
* `/rtl` - Synthesizable SystemVerilog design sources (`baud_gen.sv`, `fifo.sv`, `uart_tx.sv`, `uart_rx.sv`, `uart_fifo_top.sv`).
* `/dv` - Object-Oriented Verification environment (`uart_tb_class.sv`, `uart_if.sv`, `tb_top.sv`).
* `/docs` - Visual block diagrams and FSM mechanics.
