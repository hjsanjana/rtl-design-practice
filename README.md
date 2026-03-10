# RTL Design Practice — SystemVerilog

A progressive collection of RTL designs implemented in SystemVerilog, built from first principles up to full AMBA bus protocol implementations. Every module has a dedicated testbench.

## Contents

| Category | What's Covered |
|---|---|
| **Basic Gates** | AND, OR, NOT, NAND, NOR, XOR, XNOR |
| **Combinational Circuits** | Half/Full Adder, Ripple Carry Adder, Carry Lookahead Adder, N-bit Adder, 2:1 / 4:1 / 8:1 MUX, N-bit MUX, DEMUX, 3:8 Decoder, Encoder, Priority Encoder |
| **Sequential Circuits** | D-Latch, D/T/JK Flip-Flops (basic, async reset, sync reset, clock enable), Binary/BCD/Ring/Johnson/Gray/Up-Down Counters, Mod-N Counter, Clock Dividers, N-bit Register, Moore FSM, Vending Machine FSM, Traffic Light Controller |
| **Memory Designs** | Single-Port SRAM, Dual-Port RAM, ROM, Synchronous FIFO, Stack, 4-bit Array Multiplier, 4-bit Booth Multiplier |
| **UART** | TX module, RX module, Top-level integration, FSM-based implementation with baud rate generator, datapath, and control path |
| **SPI** | Master, Slave, Loopback testbench |
| **I2C** | Master controller with testbench |
| **AXI4-Lite** | Master, Slave, Testbench |
| **AXI4-Full** | Master, Slave, Testbench |
| **AXI Stream** | Master, Stream module, FIFO buffer, Testbench |
| **AHB** | Master, Slave, Testbench |
| **APB** | Master, Slave, Testbench |

## Repository Structure

```
.
├── basic gates/               # Fundamental logic gate implementations
├── combinational_circuit/     # Combinational logic designs + testbenches
├── sequential_circuit/        # Sequential logic, FSMs + testbenches
│   └── UART_FSM/              # UART modeled as FSM with datapath
├── Memories/                  # Memory elements and arithmetic units
│   ├── single_port_SRAM/
│   ├── dual_port_RAM/
│   ├── ROM/
│   ├── simple_FIFO/
│   ├── stack/
│   └── 4bit_multiplier/
├── UART/                      # UART protocol (TX + RX + top)
├── SPI/                       # SPI protocol (master + slave)
├── I2C/                       # I2C protocol (master)
├── AXI4_LITE.sv/              # AXI4-Lite bus interface
├── AXI4-_FULL/                # AXI4-Full burst bus interface
├── AXI_STREAM/                # AXI Stream interface with FIFO
├── AHB/                       # AMBA AHB high-performance bus
└── APB/                       # AMBA APB peripheral bus
```

## Tools

- **Language:** SystemVerilog (IEEE 1800-2017)
- **Simulation:** ModelSim / QuestaSim / Vivado Simulator
- **Naming convention:** `tb_<module>.sv` for every testbench

## Highlights

- Protocol implementations span the full AMBA family: APB → AHB → AXI4-Lite → AXI4-Full → AXI Stream
- UART implemented twice: once as a direct RTL design and once as a structured FSM with separate datapath and control path
- Memory hierarchy covers combinational ROM, synchronous single/dual-port RAM, FIFO, and stack
- Arithmetic units include both array multiplier and Booth's algorithm for comparison
