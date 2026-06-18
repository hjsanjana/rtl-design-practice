interface cpu_mem_if #(parameter int MEM_WORDS = 256) (input logic clk);
  logic rst_n;

  logic [31:0] imem_addr;
  logic [31:0] imem_rdata;

  logic        dmem_valid;
  logic        dmem_we;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [31:0] dmem_rdata;
  logic        dmem_ready;

  logic        retire_valid;
  logic [31:0] retire_pc;
  logic [31:0] retire_instr;
  logic [4:0]  retire_rd;
  logic [31:0] retire_wdata;
  logic        retire_reg_we;
  logic        trap_valid;
  logic [31:0] trap_pc;
  logic        halted;

  logic [31:0] imem [0:MEM_WORDS-1];
  logic [31:0] dmem [0:MEM_WORDS-1];

  assign imem_rdata = imem[imem_addr[9:2]];
  assign dmem_rdata = dmem[dmem_addr[9:2]];
  assign dmem_ready = 1'b1;

  always @(posedge clk) begin
  if (rst_n && dmem_valid && dmem_ready && dmem_we) begin
    dmem[dmem_addr[9:2]] <= dmem_wdata;
  end
end

  task automatic clear_mem();
    for (int i = 0; i < MEM_WORDS; i++) begin
      imem[i] = 32'h0000_0073;
      dmem[i] = 32'h0000_0000;
    end
  endtask

  task automatic write_imem(input int unsigned idx, input logic [31:0] instr);
    if (idx < MEM_WORDS) imem[idx] = instr;
    else $fatal(1, "Instruction index %0d is outside IMEM", idx);
  endtask

  task automatic write_dmem(input int unsigned idx, input logic [31:0] data);
    if (idx < MEM_WORDS) dmem[idx] = data;
    else $fatal(1, "Data index %0d is outside DMEM", idx);
  endtask

  task automatic apply_reset(input int unsigned cycles = 5);
    rst_n = 1'b0;
    repeat (cycles) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask

  modport dut_mp (
    input  clk, rst_n, imem_rdata, dmem_rdata, dmem_ready,
    output imem_addr, dmem_valid, dmem_we, dmem_addr, dmem_wdata,
           retire_valid, retire_pc, retire_instr, retire_rd,
           retire_wdata, retire_reg_we, trap_valid, trap_pc, halted
  );
endinterface