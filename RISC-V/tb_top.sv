`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import riscv_uvm_pkg::*;

  logic clk;
 initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end
  initial begin
    clk = 1'b0;
  end

  always #5 clk = ~clk;

  cpu_mem_if mem_if(clk);

  riscv_core dut (
    .clk            (clk),
    .rst_n          (mem_if.rst_n),

    .imem_addr      (mem_if.imem_addr),
    .imem_rdata     (mem_if.imem_rdata),

    .dmem_valid     (mem_if.dmem_valid),
    .dmem_we        (mem_if.dmem_we),
    .dmem_addr      (mem_if.dmem_addr),
    .dmem_wdata     (mem_if.dmem_wdata),
    .dmem_rdata     (mem_if.dmem_rdata),
    .dmem_ready     (mem_if.dmem_ready),

    .retire_valid   (mem_if.retire_valid),
    .retire_pc      (mem_if.retire_pc),
    .retire_instr   (mem_if.retire_instr),
    .retire_rd      (mem_if.retire_rd),
    .retire_wdata   (mem_if.retire_wdata),
    .retire_reg_we  (mem_if.retire_reg_we),
    .trap_valid     (mem_if.trap_valid),
    .trap_pc        (mem_if.trap_pc),
    .halted         (mem_if.halted)
  );

  initial begin
    mem_if.rst_n = 1'b0;
    mem_if.clear_mem();

    uvm_config_db#(virtual cpu_mem_if)::set(null, "*", "vif", mem_if);

    run_test();
  end
endmodule