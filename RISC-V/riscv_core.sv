module riscv_core (
  input  logic        clk,
  input  logic        rst_n,

  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,

  output logic        dmem_valid,
  output logic        dmem_we,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  input  logic [31:0] dmem_rdata,
  input  logic        dmem_ready,

  output logic        retire_valid,
  output logic [31:0] retire_pc,
  output logic [31:0] retire_instr,
  output logic [4:0]  retire_rd,
  output logic [31:0] retire_wdata,
  output logic        retire_reg_we,
  output logic        trap_valid,
  output logic [31:0] trap_pc,
  output logic        halted
);
  import riscv_pkg::*;

  typedef enum logic [4:0] {
    OP_NOP,
    OP_ADD,
    OP_SUB,
    OP_AND,
    OP_OR,
    OP_XOR,
    OP_ADDI,
    OP_LW,
    OP_SW,
    OP_BEQ,
    OP_BNE,
    OP_JAL,
    OP_ECALL,
    OP_ILLEGAL
  } op_t;

  logic [31:0] regs [0:31];
  logic [31:0] pc;

  logic        if_id_valid;
  logic [31:0] if_id_pc;
  logic [31:0] if_id_instr;

  logic        id_ex_valid;
  logic [31:0] id_ex_pc;
  logic [31:0] id_ex_instr;
  op_t         id_ex_op;
  logic [4:0]  id_ex_rs1;
  logic [4:0]  id_ex_rs2;
  logic [4:0]  id_ex_rd;
  logic [31:0] id_ex_rs1_val;
  logic [31:0] id_ex_rs2_val;
  logic [31:0] id_ex_imm;
  logic        id_ex_reg_we;
  logic        id_ex_mem_read;
  logic        id_ex_mem_write;
  logic        id_ex_exception;

  logic        ex_mem_valid;
  logic [31:0] ex_mem_pc;
  logic [31:0] ex_mem_instr;
  op_t         ex_mem_op;
  logic [4:0]  ex_mem_rd;
  logic [31:0] ex_mem_alu_result;
  logic [31:0] ex_mem_store_data;
  logic        ex_mem_reg_we;
  logic        ex_mem_mem_read;
  logic        ex_mem_mem_write;
  logic        ex_mem_exception;

  logic        mem_wb_valid;
  logic [31:0] mem_wb_pc;
  logic [31:0] mem_wb_instr;
  op_t         mem_wb_op;
  logic [4:0]  mem_wb_rd;
  logic [31:0] mem_wb_wb_data;
  logic        mem_wb_reg_we;
  logic        mem_wb_exception;

  logic [4:0]  dec_rs1;
  logic [4:0]  dec_rs2;
  logic [4:0]  dec_rd;
  op_t         dec_op;
  logic [31:0] dec_imm;
  logic        dec_reg_we;
  logic        dec_mem_read;
  logic        dec_mem_write;
  logic        dec_exception;
  logic [31:0] dec_rs1_val;
  logic [31:0] dec_rs2_val;

  logic        load_use_stall;
  logic [31:0] ex_rs1_val;
  logic [31:0] ex_rs2_val;
  logic [31:0] ex_alu_result;
  logic        ex_redirect;
  logic [31:0] ex_redirect_pc;
  logic        ex_exception_now;
  logic        will_halt;
integer x0_check_count;
integer redirect_check_count;
integer stall_check_count;
  assign imem_addr = pc;

  assign dmem_valid = ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write);
  assign dmem_we    = ex_mem_mem_write;
  assign dmem_addr  = ex_mem_alu_result;
  assign dmem_wdata = ex_mem_store_data;

  assign retire_valid  = mem_wb_valid && !halted;
  assign retire_pc     = mem_wb_pc;
  assign retire_instr  = mem_wb_instr;
  assign retire_rd     = mem_wb_rd;
  assign retire_wdata  = mem_wb_wb_data;
  assign retire_reg_we = mem_wb_reg_we;
  assign trap_valid    = mem_wb_valid && mem_wb_exception && !halted;
  assign trap_pc       = mem_wb_pc;
  assign will_halt     = mem_wb_valid && mem_wb_exception && !halted;

  function automatic op_t decode_op(input logic [31:0] instr);
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    opcode = instr[6:0];
    funct3 = instr[14:12];
    funct7 = instr[31:25];

    decode_op = OP_ILLEGAL;
    case (opcode)
      OPCODE_OP: begin
        case ({funct7, funct3})
          {7'b0000000, 3'b000}: decode_op = OP_ADD;
          {7'b0100000, 3'b000}: decode_op = OP_SUB;
          {7'b0000000, 3'b111}: decode_op = OP_AND;
          {7'b0000000, 3'b110}: decode_op = OP_OR;
          {7'b0000000, 3'b100}: decode_op = OP_XOR;
          default:              decode_op = OP_ILLEGAL;
        endcase
      end
      OPCODE_OP_IMM: begin
        if (funct3 == 3'b000) decode_op = OP_ADDI;
        else                  decode_op = OP_ILLEGAL;
      end
      OPCODE_LOAD: begin
        if (funct3 == 3'b010) decode_op = OP_LW;
        else                  decode_op = OP_ILLEGAL;
      end
      OPCODE_STORE: begin
        if (funct3 == 3'b010) decode_op = OP_SW;
        else                  decode_op = OP_ILLEGAL;
      end
      OPCODE_BRANCH: begin
        if (funct3 == 3'b000)      decode_op = OP_BEQ;
        else if (funct3 == 3'b001) decode_op = OP_BNE;
        else                       decode_op = OP_ILLEGAL;
      end
      OPCODE_JAL: decode_op = OP_JAL;
      OPCODE_SYSTEM: begin
        if (instr == 32'h0000_0073) decode_op = OP_ECALL;
        else                        decode_op = OP_ILLEGAL;
      end
      default: decode_op = OP_ILLEGAL;
    endcase
  endfunction

  function automatic logic [31:0] read_reg_with_wb(input logic [4:0] idx);
    if (idx == 5'd0) begin
      read_reg_with_wb = 32'h0;
    end else if (mem_wb_valid && mem_wb_reg_we && (mem_wb_rd == idx)) begin
      read_reg_with_wb = mem_wb_wb_data;
    end else begin
      read_reg_with_wb = regs[idx];
    end
  endfunction

  always_comb begin
    dec_rs1       = if_id_instr[19:15];
    dec_rs2       = if_id_instr[24:20];
    dec_rd        = if_id_instr[11:7];
    dec_op        = decode_op(if_id_instr);
    dec_reg_we    = 1'b0;
    dec_mem_read  = 1'b0;
    dec_mem_write = 1'b0;
    dec_exception = 1'b0;
    dec_imm       = 32'h0;

    case (dec_op)
      OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR: dec_reg_we = 1'b1;
      OP_ADDI: begin
        dec_reg_we = 1'b1;
        dec_imm    = imm_i(if_id_instr);
      end
      OP_LW: begin
        dec_reg_we   = 1'b1;
        dec_mem_read = 1'b1;
        dec_imm      = imm_i(if_id_instr);
      end
      OP_SW: begin
        dec_mem_write = 1'b1;
        dec_imm       = imm_s(if_id_instr);
      end
      OP_BEQ, OP_BNE: dec_imm = imm_b(if_id_instr);
      OP_JAL: begin
        dec_reg_we = 1'b1;
        dec_imm    = imm_j(if_id_instr);
      end
      OP_ECALL, OP_ILLEGAL: dec_exception = 1'b1;
      default: ;
    endcase

    dec_rs1_val = read_reg_with_wb(dec_rs1);
    dec_rs2_val = read_reg_with_wb(dec_rs2);
  end

  always_comb begin
    load_use_stall = 1'b0;
    if (if_id_valid && id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'd0)) begin
      if ((instr_uses_rs1(if_id_instr) && (if_id_instr[19:15] == id_ex_rd)) ||
          (instr_uses_rs2(if_id_instr) && (if_id_instr[24:20] == id_ex_rd))) begin
        load_use_stall = 1'b1;
      end
    end
  end

  always_comb begin
    ex_rs1_val = id_ex_rs1_val;
    ex_rs2_val = id_ex_rs2_val;

    if (ex_mem_valid && ex_mem_reg_we && !ex_mem_mem_read && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
      ex_rs1_val = ex_mem_alu_result;
    end else if (mem_wb_valid && mem_wb_reg_we && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
      ex_rs1_val = mem_wb_wb_data;
    end

    if (ex_mem_valid && ex_mem_reg_we && !ex_mem_mem_read && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
      ex_rs2_val = ex_mem_alu_result;
    end else if (mem_wb_valid && mem_wb_reg_we && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
      ex_rs2_val = mem_wb_wb_data;
    end
  end

  always_comb begin
    ex_alu_result  = 32'h0;
    ex_redirect    = 1'b0;
    ex_redirect_pc = 32'h0;

    case (id_ex_op)
      OP_ADD:  ex_alu_result = ex_rs1_val + ex_rs2_val;
      OP_SUB:  ex_alu_result = ex_rs1_val - ex_rs2_val;
      OP_AND:  ex_alu_result = ex_rs1_val & ex_rs2_val;
      OP_OR:   ex_alu_result = ex_rs1_val | ex_rs2_val;
      OP_XOR:  ex_alu_result = ex_rs1_val ^ ex_rs2_val;
      OP_ADDI: ex_alu_result = ex_rs1_val + id_ex_imm;
      OP_LW:   ex_alu_result = ex_rs1_val + id_ex_imm;
      OP_SW:   ex_alu_result = ex_rs1_val + id_ex_imm;
      OP_BEQ: begin
        if (ex_rs1_val == ex_rs2_val) begin
          ex_redirect    = id_ex_valid;
          ex_redirect_pc = id_ex_pc + id_ex_imm;
        end
      end
      OP_BNE: begin
        if (ex_rs1_val != ex_rs2_val) begin
          ex_redirect    = id_ex_valid;
          ex_redirect_pc = id_ex_pc + id_ex_imm;
        end
      end
      OP_JAL: begin
        ex_alu_result  = id_ex_pc + 32'd4;
        ex_redirect    = id_ex_valid;
        ex_redirect_pc = id_ex_pc + id_ex_imm;
      end
      default: ex_alu_result = 32'h0;
    endcase
  end

  assign ex_exception_now = id_ex_valid && id_ex_exception;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc               <= 32'h0;
      if_id_valid      <= 1'b0;
      if_id_pc         <= 32'h0;
      if_id_instr      <= 32'h0000_0013;
      id_ex_valid      <= 1'b0;
      id_ex_pc         <= 32'h0;
      id_ex_instr      <= 32'h0000_0013;
      id_ex_op         <= OP_NOP;
      id_ex_rs1        <= 5'h0;
      id_ex_rs2        <= 5'h0;
      id_ex_rd         <= 5'h0;
      id_ex_rs1_val    <= 32'h0;
      id_ex_rs2_val    <= 32'h0;
      id_ex_imm        <= 32'h0;
      id_ex_reg_we     <= 1'b0;
      id_ex_mem_read   <= 1'b0;
      id_ex_mem_write  <= 1'b0;
      id_ex_exception  <= 1'b0;
      ex_mem_valid     <= 1'b0;
      ex_mem_pc        <= 32'h0;
      ex_mem_instr     <= 32'h0000_0013;
      ex_mem_op        <= OP_NOP;
      ex_mem_rd        <= 5'h0;
      ex_mem_alu_result<= 32'h0;
      ex_mem_store_data<= 32'h0;
      ex_mem_reg_we    <= 1'b0;
      ex_mem_mem_read  <= 1'b0;
      ex_mem_mem_write <= 1'b0;
      ex_mem_exception <= 1'b0;
      mem_wb_valid     <= 1'b0;
      mem_wb_pc        <= 32'h0;
      mem_wb_instr     <= 32'h0000_0013;
      mem_wb_op        <= OP_NOP;
      mem_wb_rd        <= 5'h0;
      mem_wb_wb_data   <= 32'h0;
      mem_wb_reg_we    <= 1'b0;
      mem_wb_exception <= 1'b0;
      halted           <= 1'b0;

x0_check_count       <= 0;
redirect_check_count <= 0;
stall_check_count    <= 0;

for (int i = 0; i < 32; i++) begin
  regs[i] <= 32'h0;
end
    end else begin
      

  x0_check_count <= x0_check_count + 1;

  if (ex_redirect) begin
    redirect_check_count <= redirect_check_count + 1;
  end

  if (load_use_stall) begin
    stall_check_count <= stall_check_count + 1;
  end

  regs[0] <= 32'h0;

      if (mem_wb_valid && mem_wb_reg_we && (mem_wb_rd != 5'd0) && !mem_wb_exception) begin
        regs[mem_wb_rd] <= mem_wb_wb_data;
      end

      if (will_halt) begin
        halted <= 1'b1;
      end

      if (!halted && !will_halt) begin
        mem_wb_valid     <= ex_mem_valid;
        mem_wb_pc        <= ex_mem_pc;
        mem_wb_instr     <= ex_mem_instr;
        mem_wb_op        <= ex_mem_op;
        mem_wb_rd        <= ex_mem_rd;
        mem_wb_reg_we    <= ex_mem_reg_we && !ex_mem_exception;
        mem_wb_exception <= ex_mem_exception;

        if (ex_mem_mem_read) mem_wb_wb_data <= dmem_rdata;
        else                 mem_wb_wb_data <= ex_mem_alu_result;

        ex_mem_valid      <= id_ex_valid;
        ex_mem_pc         <= id_ex_pc;
        ex_mem_instr      <= id_ex_instr;
        ex_mem_op         <= id_ex_op;
        ex_mem_rd         <= id_ex_rd;
        ex_mem_alu_result <= ex_alu_result;
        ex_mem_store_data <= ex_rs2_val;
        ex_mem_reg_we     <= id_ex_reg_we;
        ex_mem_mem_read   <= id_ex_mem_read;
        ex_mem_mem_write  <= id_ex_mem_write;
        ex_mem_exception  <= id_ex_exception;

        if (load_use_stall || ex_redirect || ex_exception_now) begin
          id_ex_valid      <= 1'b0;
          id_ex_pc         <= 32'h0;
          id_ex_instr      <= 32'h0000_0013;
          id_ex_op         <= OP_NOP;
          id_ex_rs1        <= 5'h0;
          id_ex_rs2        <= 5'h0;
          id_ex_rd         <= 5'h0;
          id_ex_rs1_val    <= 32'h0;
          id_ex_rs2_val    <= 32'h0;
          id_ex_imm        <= 32'h0;
          id_ex_reg_we     <= 1'b0;
          id_ex_mem_read   <= 1'b0;
          id_ex_mem_write  <= 1'b0;
          id_ex_exception  <= 1'b0;
        end else begin
          id_ex_valid      <= if_id_valid;
          id_ex_pc         <= if_id_pc;
          id_ex_instr      <= if_id_instr;
          id_ex_op         <= dec_op;
          id_ex_rs1        <= dec_rs1;
          id_ex_rs2        <= dec_rs2;
          id_ex_rd         <= dec_rd;
          id_ex_rs1_val    <= dec_rs1_val;
          id_ex_rs2_val    <= dec_rs2_val;
          id_ex_imm        <= dec_imm;
          id_ex_reg_we     <= dec_reg_we;
          id_ex_mem_read   <= dec_mem_read;
          id_ex_mem_write  <= dec_mem_write;
          id_ex_exception  <= dec_exception;
        end

        if (ex_redirect) begin
          pc          <= ex_redirect_pc;
          if_id_valid <= 1'b0;
          if_id_pc    <= 32'h0;
          if_id_instr <= 32'h0000_0013;
        end else if (ex_exception_now) begin
          pc          <= pc;
          if_id_valid <= 1'b0;
          if_id_pc    <= 32'h0;
          if_id_instr <= 32'h0000_0013;
        end else if (load_use_stall) begin
          pc          <= pc;
          if_id_valid <= if_id_valid;
          if_id_pc    <= if_id_pc;
          if_id_instr <= if_id_instr;
        end else begin
          pc          <= pc + 32'd4;
          if_id_valid <= 1'b1;
          if_id_pc    <= pc;
          if_id_instr <= imem_rdata;
        end
      end else begin
        mem_wb_valid <= 1'b0;
        ex_mem_valid <= 1'b0;
        id_ex_valid  <= 1'b0;
        if_id_valid  <= 1'b0;
      end
    end
  end
 

  // ============================================================
  // Step 5: Pipeline / architectural assertions
  // These are simulation-only checks.
  // Place them right before endmodule.
  // ============================================================

`ifndef SYNTHESIS

  // Assertion 1:
  // RISC-V register x0 must always stay zero.
  always @(posedge clk) begin
    if (rst_n) begin
      assert (regs[0] == 32'h0000_0000)
      else $error("ASSERTION FAILED: x0 register changed from zero");
    end
  end

  // Assertion 2:
  // When a branch or JAL redirects the PC, the next-cycle PC
  // must become the redirect target.
  property p_redirect_updates_pc;
    @(posedge clk)
    disable iff (!rst_n)
    ex_redirect |=> (pc == $past(ex_redirect_pc));
  endproperty

  assert property (p_redirect_updates_pc)
  else $error("ASSERTION FAILED: Branch/JAL redirect PC update is wrong");

  // Assertion 3:
  // During a load-use stall, the PC must be frozen for one cycle.
  property p_load_use_stall_freezes_pc;
    @(posedge clk)
    disable iff (!rst_n)
    load_use_stall |=> (pc == $past(pc));
  endproperty

  assert property (p_load_use_stall_freezes_pc)
  else $error("ASSERTION FAILED: load-use stall did not freeze PC");

  // Assertion 4:
  // During a load-use stall, IF/ID instruction must also be frozen.
  property p_load_use_stall_freezes_ifid;
    @(posedge clk)
    disable iff (!rst_n)
    load_use_stall |=> (if_id_instr == $past(if_id_instr));
  endproperty

  assert property (p_load_use_stall_freezes_ifid)
  else $error("ASSERTION FAILED: load-use stall did not freeze IF/ID instruction");

`endif

  final begin
    $display("========================================");
    $display("ASSERTION COVERAGE REPORT");
    $display("x0 checks      = %0d", x0_check_count);
    $display("redirects seen = %0d", redirect_check_count);
    $display("stalls seen    = %0d", stall_check_count);
    $display("========================================");
  end

endmodule