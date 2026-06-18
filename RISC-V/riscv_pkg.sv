package riscv_pkg;
  parameter logic [6:0] OPCODE_OP     = 7'b0110011;
  parameter logic [6:0] OPCODE_OP_IMM = 7'b0010011;
  parameter logic [6:0] OPCODE_LOAD   = 7'b0000011;
  parameter logic [6:0] OPCODE_STORE  = 7'b0100011;
  parameter logic [6:0] OPCODE_BRANCH = 7'b1100011;
  parameter logic [6:0] OPCODE_JAL    = 7'b1101111;
  parameter logic [6:0] OPCODE_SYSTEM = 7'b1110011;

  function automatic logic [31:0] enc_r(
    input logic [6:0] funct7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] enc_i(
    input int signed imm,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    logic [11:0] imm12;
    imm12 = imm[11:0];
    enc_i = {imm12, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] enc_s(
    input int signed imm,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [6:0] opcode
  );
    logic [11:0] imm12;
    imm12 = imm[11:0];
    enc_s = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
  endfunction

  function automatic logic [31:0] enc_b(
    input int signed imm,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [6:0] opcode
  );
    logic [12:0] imm13;
    imm13 = imm[12:0];
    enc_b = {imm13[12], imm13[10:5], rs2, rs1, funct3, imm13[4:1], imm13[11], opcode};
  endfunction

  function automatic logic [31:0] enc_jal(
    input int signed imm,
    input logic [4:0] rd
  );
    logic [20:0] imm21;
    imm21 = imm[20:0];
    enc_jal = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, OPCODE_JAL};
  endfunction

  function automatic logic [31:0] enc_ecall();
    enc_ecall = 32'h0000_0073;
  endfunction

  function automatic logic [31:0] enc_add(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    enc_add = enc_r(7'b0000000, rs2, rs1, 3'b000, rd, OPCODE_OP);
  endfunction

  function automatic logic [31:0] enc_sub(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    enc_sub = enc_r(7'b0100000, rs2, rs1, 3'b000, rd, OPCODE_OP);
  endfunction

  function automatic logic [31:0] enc_and(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    enc_and = enc_r(7'b0000000, rs2, rs1, 3'b111, rd, OPCODE_OP);
  endfunction

  function automatic logic [31:0] enc_or(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    enc_or = enc_r(7'b0000000, rs2, rs1, 3'b110, rd, OPCODE_OP);
  endfunction

  function automatic logic [31:0] enc_xor(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    enc_xor = enc_r(7'b0000000, rs2, rs1, 3'b100, rd, OPCODE_OP);
  endfunction

  function automatic logic [31:0] enc_addi(input logic [4:0] rd, input logic [4:0] rs1, input int signed imm);
    enc_addi = enc_i(imm, rs1, 3'b000, rd, OPCODE_OP_IMM);
  endfunction

  function automatic logic [31:0] enc_lw(input logic [4:0] rd, input logic [4:0] rs1, input int signed imm);
    enc_lw = enc_i(imm, rs1, 3'b010, rd, OPCODE_LOAD);
  endfunction

  function automatic logic [31:0] enc_sw(input logic [4:0] rs2, input logic [4:0] rs1, input int signed imm);
    enc_sw = enc_s(imm, rs2, rs1, 3'b010, OPCODE_STORE);
  endfunction

  function automatic logic [31:0] enc_beq(input logic [4:0] rs1, input logic [4:0] rs2, input int signed imm);
    enc_beq = enc_b(imm, rs2, rs1, 3'b000, OPCODE_BRANCH);
  endfunction

  function automatic logic [31:0] enc_bne(input logic [4:0] rs1, input logic [4:0] rs2, input int signed imm);
    enc_bne = enc_b(imm, rs2, rs1, 3'b001, OPCODE_BRANCH);
  endfunction

  function automatic logic [31:0] imm_i(input logic [31:0] instr);
    imm_i = {{20{instr[31]}}, instr[31:20]};
  endfunction

  function automatic logic [31:0] imm_s(input logic [31:0] instr);
    imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  endfunction

  function automatic logic [31:0] imm_b(input logic [31:0] instr);
    imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  endfunction

  function automatic logic [31:0] imm_j(input logic [31:0] instr);
    imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
  endfunction

  function automatic bit instr_uses_rs1(input logic [31:0] instr);
    logic [6:0] opcode;
    opcode = instr[6:0];
    instr_uses_rs1 = (opcode == OPCODE_OP)     ||
                     (opcode == OPCODE_OP_IMM) ||
                     (opcode == OPCODE_LOAD)   ||
                     (opcode == OPCODE_STORE)  ||
                     (opcode == OPCODE_BRANCH);
  endfunction

  function automatic bit instr_uses_rs2(input logic [31:0] instr);
    logic [6:0] opcode;
    opcode = instr[6:0];
    instr_uses_rs2 = (opcode == OPCODE_OP) ||
                     (opcode == OPCODE_STORE) ||
                     (opcode == OPCODE_BRANCH);
  endfunction
endpackage