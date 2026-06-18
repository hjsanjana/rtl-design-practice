# RISC-V 5-Stage Pipelined CPU (SystemVerilog + UVM)

A small RISC-V CPU core, written from scratch in SystemVerilog, with a UVM testbench that checks every single instruction it executes against a software reference model.

## What this project actually is, in plain words

Think of a CPU as a tiny assembly line. An instruction comes in one end (as 32 bits of binary), and a result comes out the other end (a register gets updated, or memory gets written). This project builds that assembly line — a **classic 5-stage pipeline** — and then builds a separate "checker" that watches everything the CPU does and screams if it ever gets the wrong answer.

It only supports a small, hand-picked subset of the RISC-V instruction set (the RV32I base), enough to do real work: arithmetic, loads/stores, branches, and jumps. That's intentional — it's a learning-sized core, not a production one.

## Files

| File | What it is |
|---|---|
| [riscv_pkg.sv](riscv_pkg.sv) | Helper functions: instruction encoders (build a 32-bit instruction from its fields) and decoders (pull immediate values back out of an instruction). Shared by both the CPU and the testbench. |
| [riscv_core.sv](riscv_core.sv) | The CPU itself — the pipeline, the register file, the ALU, hazard detection, and a handful of runtime assertions. |
| [cpu_mem_if.sv](cpu_mem_if.sv) | A SystemVerilog `interface` that bundles together instruction memory, data memory, and all the wires connecting the CPU to the outside world. Acts as the "motherboard" the CPU plugs into. |
| [riscv_uvm_pkg.sv](riscv_uvm_pkg.sv) | The UVM (Universal Verification Methodology) testbench: generates instruction streams, drives them into the CPU, watches what comes out, and compares it against a golden reference model. |
| [tb_top.sv](tb_top.sv) | The top-level module that wires the CPU and the interface together and kicks off the UVM test. |

## Core concepts, briefly explained

**Pipelining.** Instead of finishing one instruction completely before starting the next, the CPU breaks instruction processing into 5 stages — Fetch, Decode, Execute, Memory, Writeback — and runs up to 5 instructions at once, each at a different stage, like a factory line. This is *much* faster than doing one instruction start-to-finish before starting the next, but it introduces tricky problems called **hazards**.

**Hazards, and how this CPU handles them:**
- *Data hazard (RAW — read after write)*: instruction B needs a value that instruction A hasn't finished computing yet. Fixed here with **forwarding** — the result is fed directly from a later pipeline stage straight back into the stage that needs it, instead of waiting for it to be written to the register file.
- *Load-use hazard*: a special, unavoidable case of the above — when B needs a value that A just loaded from memory, forwarding alone isn't fast enough, so the pipeline **stalls** B for one cycle until the loaded value is ready.
- *Control hazard*: a branch or jump changes the program counter (PC), but the pipeline has already started fetching the instructions right after it, assuming no jump would happen. When a branch *is* taken, those wrongly-fetched instructions are **flushed** (discarded) and the PC is **redirected** to the correct target.

**Exceptions/traps.** An illegal instruction or an `ecall` (a deliberate "stop/trap" instruction) causes the CPU to halt cleanly rather than execute garbage.

**UVM (Universal Verification Methodology).** A standardized way to build testbenches out of reusable, swappable building blocks: a *sequencer* (decides what instructions to send), a *driver* (loads them into memory and resets the CPU), a *monitor* (watches the CPU's outputs), a *scoreboard* (the judge), and a *coverage collector* (tracks which instruction types/cases have actually been exercised).

**Self-checking testbench / scoreboard.** Rather than eyeballing waveforms, the testbench keeps its own simple Python-like model of the CPU's register file and memory in plain SystemVerilog, written independently of the actual CPU logic. Every time the real CPU "retires" (finishes) an instruction, the scoreboard re-computes by hand what *should* have happened and compares it bit-for-bit against what the CPU actually did. Any mismatch is flagged immediately with the exact PC and instruction that caused it.

## How the project flows, end to end

1. **`tb_top.sv`** boots the simulation: it instantiates the `cpu_mem_if` interface, wires it to `riscv_core` (the DUT — device under test), registers the interface in UVM's config database, and calls `run_test()`.

2. **UVM builds the test environment** (`riscv_env`): a sequencer, driver, monitor, scoreboard, and coverage collector are created and wired together.

3. **A sequence generates instructions.** Two sequences exist:
   - `riscv_directed_seq` — a small, hand-written, predictable program (some ADDs/SUBs, a store+load round trip, a branch, ending in `ecall`).
   - `riscv_random_seq` — randomly picks from 8 categories of instruction patterns (forwarding hazards, load-use hazards, taken/not-taken branches, JAL jumps, etc.) and chains 25 of them together, ending in `ecall`. This is what actually stresses the pipeline's hazard logic.

4. **The driver loads the program.** It clears memory, writes the generated instructions into instruction memory, pre-loads some known values into data memory, then pulses reset to start the CPU running. It waits until the CPU halts (hits the `ecall`) or times out.

5. **The CPU executes, cycle by cycle**, fetching from `imem`, decoding, forwarding/stalling as needed, executing in the ALU, accessing `dmem` for loads/stores, and writing results back to its register file — exactly like a real pipelined processor.

6. **The monitor watches the `retire_*` signals** — these fire every time an instruction completes — and packages each retirement (PC, instruction, destination register, result, trap flag) into an item.

7. **The scoreboard re-derives the expected result independently**, using its own copy of the register file and memory plus the instruction's opcode/funct3/funct7 fields, and compares it field-by-field against what the real CPU produced (PC, register-write-enable, write data, trap flag). Any mismatch is logged as a UVM error with full context.

8. **The coverage collector tallies** which opcodes, funct3 codes, and register-write/trap combinations were actually seen, so you know whether the random testing was thorough enough (target: 90%+ functional coverage).

9. **At the end of the run**, the scoreboard reports pass/fail counts and the coverage collector reports the final percentage — that's your pass/fail verdict for the whole core.

10. Inside `riscv_core.sv` itself there are also **runtime SystemVerilog assertions** (x0 always stays zero, PC redirects land on the right target, load-use stalls actually freeze the pipeline) that fire independently of the UVM scoreboard, as a second safety net.

```
tb_top.sv
   └── instantiates cpu_mem_if + riscv_core, starts UVM
        └── riscv_env
             ├── sequence (directed or random) → generates instruction list
             ├── driver   → loads instructions into imem, resets CPU, runs until halt
             ├── riscv_core (DUT) → actually executes the pipeline
             ├── monitor  → watches retire_* signals, packages into items
             ├── scoreboard → re-computes expected result, compares, reports PASS/FAIL
             └── coverage → tracks which instruction types were exercised
```
