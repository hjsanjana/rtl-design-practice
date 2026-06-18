package riscv_uvm_pkg;
  import uvm_pkg::*;
  import riscv_pkg::*;
  `include "uvm_macros.svh"

  class riscv_instr_mem_item extends uvm_sequence_item;
    rand int unsigned max_cycles;
    bit [31:0] instr_mem[$];

    `uvm_object_utils(riscv_instr_mem_item)

    function new(string name = "riscv_instr_mem_item");
      super.new(name);
      max_cycles = 2000;
    endfunction
  endclass

  class riscv_retire_item extends uvm_sequence_item;
    bit        valid;
    bit [31:0] pc;
    bit [31:0] instr;
    bit [4:0]  rd;
    bit [31:0] wdata;
    bit        reg_we;
    bit        trap;

    `uvm_object_utils(riscv_retire_item)

    function new(string name = "riscv_retire_item");
      super.new(name);
    endfunction
  endclass

  class riscv_sequencer extends uvm_sequencer #(riscv_instr_mem_item);
    `uvm_component_utils(riscv_sequencer)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class riscv_driver extends uvm_driver #(riscv_instr_mem_item);
    `uvm_component_utils(riscv_driver)

    virtual cpu_mem_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual cpu_mem_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "virtual cpu_mem_if was not set")
      end
    endfunction

    task run_phase(uvm_phase phase);
      riscv_instr_mem_item tr;

      forever begin
        seq_item_port.get_next_item(tr);

        vif.clear_mem();

        foreach (tr.instr_mem[i]) begin
          vif.write_imem(i, tr.instr_mem[i]);
        end

        for (int i = 0; i < 64; i++) begin
          vif.write_dmem(i, 32'h1000_0000 + i);
        end

        `uvm_info("DRV", $sformatf("Loaded %0d instructions", tr.instr_mem.size()), UVM_LOW)

        vif.apply_reset(5);

        fork
          begin
            wait (vif.halted === 1'b1);
            repeat (5) @(posedge vif.clk);
          end

          begin
            repeat (tr.max_cycles) @(posedge vif.clk);
            `uvm_error("TIMEOUT", "CPU did not halt")
          end
        join_any

        disable fork;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class riscv_monitor extends uvm_component;
    `uvm_component_utils(riscv_monitor)

    virtual cpu_mem_if vif;
    uvm_analysis_port #(riscv_retire_item) retire_ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      retire_ap = new("retire_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual cpu_mem_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "virtual cpu_mem_if was not set")
      end
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);

        if (vif.rst_n && vif.retire_valid) begin
          riscv_retire_item item;
          item = riscv_retire_item::type_id::create("item", this);

          item.valid  = vif.retire_valid;
          item.pc     = vif.retire_pc;
          item.instr  = vif.retire_instr;
          item.rd     = vif.retire_rd;
          item.wdata  = vif.retire_wdata;
          item.reg_we = vif.retire_reg_we;
          item.trap   = vif.trap_valid;

          retire_ap.write(item);
        end
      end
    endtask
  endclass

   class riscv_scoreboard extends uvm_component;
    `uvm_component_utils(riscv_scoreboard)

    uvm_analysis_imp #(riscv_retire_item, riscv_scoreboard) retire_export;

    bit [31:0] ref_regs [0:31];
    bit [31:0] ref_mem  [0:255];
    bit [31:0] ref_pc;

    int unsigned retire_count;
    int unsigned pass_count;
    int unsigned fail_count;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      retire_export = new("retire_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      reset_model();
    endfunction

    function void reset_model();
      ref_pc       = 32'h0000_0000;
      retire_count = 0;
      pass_count   = 0;
      fail_count   = 0;

      for (int i = 0; i < 32; i++) begin
        ref_regs[i] = 32'h0000_0000;
      end

      for (int i = 0; i < 256; i++) begin
        ref_mem[i] = 32'h0000_0000;
      end

      for (int i = 0; i < 64; i++) begin
        ref_mem[i] = 32'h1000_0000 + i;
      end
    endfunction

    function automatic bit [31:0] read_ref_reg(input bit [4:0] idx);
      if (idx == 5'd0) begin
        read_ref_reg = 32'h0000_0000;
      end else begin
        read_ref_reg = ref_regs[idx];
      end
    endfunction

    function automatic void write_ref_reg(input bit [4:0] idx, input bit [31:0] data);
      if (idx != 5'd0) begin
        ref_regs[idx] = data;
      end

      ref_regs[0] = 32'h0000_0000;
    endfunction

    function void write(riscv_retire_item t);
      bit [6:0]  opcode;
      bit [2:0]  funct3;
      bit [6:0]  funct7;
      bit [4:0]  rs1;
      bit [4:0]  rs2;
      bit [4:0]  rd;

      bit [31:0] src1_val;
      bit [31:0] src2_val;

      bit [31:0] expected_wdata;
      bit        expected_reg_we;
      bit        expected_trap;
      bit [31:0] expected_next_pc;
      bit [31:0] mem_addr;

      bit        local_fail;

      retire_count++;
      local_fail = 1'b0;

      opcode = t.instr[6:0];
      rd     = t.instr[11:7];
      funct3 = t.instr[14:12];
      rs1    = t.instr[19:15];
      rs2    = t.instr[24:20];
      funct7 = t.instr[31:25];

      src1_val = read_ref_reg(rs1);
      src2_val = read_ref_reg(rs2);

      expected_wdata  = 32'h0000_0000;
      expected_reg_we = 1'b0;
      expected_trap   = 1'b0;
      expected_next_pc = ref_pc + 32'd4;

      case (opcode)

        OPCODE_OP: begin
          expected_reg_we = 1'b1;

          case ({funct7, funct3})
            {7'b0000000, 3'b000}: expected_wdata = src1_val + src2_val; // ADD
            {7'b0100000, 3'b000}: expected_wdata = src1_val - src2_val; // SUB
            {7'b0000000, 3'b111}: expected_wdata = src1_val & src2_val; // AND
            {7'b0000000, 3'b110}: expected_wdata = src1_val | src2_val; // OR
            {7'b0000000, 3'b100}: expected_wdata = src1_val ^ src2_val; // XOR

            default: begin
              expected_reg_we = 1'b0;
              expected_trap   = 1'b1;
            end
          endcase
        end

        OPCODE_OP_IMM: begin
          if (funct3 == 3'b000) begin
            expected_reg_we = 1'b1;
            expected_wdata  = src1_val + imm_i(t.instr); // ADDI
          end else begin
            expected_trap = 1'b1;
          end
        end

        OPCODE_LOAD: begin
          if (funct3 == 3'b010) begin
            mem_addr        = src1_val + imm_i(t.instr);
            expected_reg_we = 1'b1;
            expected_wdata  = ref_mem[mem_addr[9:2]]; // LW
          end else begin
            expected_trap = 1'b1;
          end
        end

        OPCODE_STORE: begin
          if (funct3 == 3'b010) begin
            mem_addr = src1_val + imm_s(t.instr);
            ref_mem[mem_addr[9:2]] = src2_val; // SW updates shadow memory
          end else begin
            expected_trap = 1'b1;
          end
        end

        OPCODE_BRANCH: begin
          if (funct3 == 3'b000) begin
            if (src1_val == src2_val) begin
              expected_next_pc = ref_pc + imm_b(t.instr); // BEQ taken
            end
          end else if (funct3 == 3'b001) begin
            if (src1_val != src2_val) begin
              expected_next_pc = ref_pc + imm_b(t.instr); // BNE taken
            end
          end else begin
            expected_trap = 1'b1;
          end
        end

        OPCODE_JAL: begin
          expected_reg_we  = 1'b1;
          expected_wdata   = ref_pc + 32'd4;
          expected_next_pc = ref_pc + imm_j(t.instr);
        end

        OPCODE_SYSTEM: begin
          expected_trap = 1'b1;
        end

        default: begin
          expected_trap = 1'b1;
        end

      endcase

      if (t.pc !== ref_pc) begin
        local_fail = 1'b1;
        `uvm_error("PC_MISMATCH",
          $sformatf("retire=%0d instr=0x%08h DUT_PC=0x%08h EXPECTED_PC=0x%08h",
                    retire_count, t.instr, t.pc, ref_pc))
      end

      if (t.reg_we !== expected_reg_we) begin
        local_fail = 1'b1;
        `uvm_error("REGWE_MISMATCH",
          $sformatf("pc=0x%08h instr=0x%08h DUT_reg_we=%0b EXPECTED_reg_we=%0b",
                    t.pc, t.instr, t.reg_we, expected_reg_we))
      end

      if (expected_reg_we && (rd != 5'd0)) begin
        if (t.wdata !== expected_wdata) begin
          local_fail = 1'b1;
          `uvm_error("WDATA_MISMATCH",
            $sformatf("pc=0x%08h instr=0x%08h rd=x%0d DUT_wdata=0x%08h EXPECTED_wdata=0x%08h",
                      t.pc, t.instr, rd, t.wdata, expected_wdata))
        end
      end

      if (t.trap !== expected_trap) begin
        local_fail = 1'b1;
        `uvm_error("TRAP_MISMATCH",
          $sformatf("pc=0x%08h instr=0x%08h DUT_trap=%0b EXPECTED_trap=%0b",
                    t.pc, t.instr, t.trap, expected_trap))
      end

      if (!local_fail) begin
        pass_count++;
        `uvm_info("SCOREBOARD_PASS",
          $sformatf("PASS #%0d pc=0x%08h instr=0x%08h rd=x%0d reg_we=%0b wdata=0x%08h trap=%0b",
                    retire_count, t.pc, t.instr, rd, t.reg_we, t.wdata, t.trap),
          UVM_MEDIUM)
      end else begin
        fail_count++;
      end

      if (expected_reg_we) begin
        write_ref_reg(rd, expected_wdata);
      end

      ref_pc = expected_next_pc;
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SCOREBOARD",
        $sformatf("Checked %0d retired instructions: PASS=%0d FAIL=%0d",
                  retire_count, pass_count, fail_count),
        UVM_LOW)

      if (fail_count == 0) begin
        `uvm_info("FINAL_RESULT", "TEST PASSED: No scoreboard mismatches", UVM_LOW)
      end else begin
        `uvm_error("FINAL_RESULT", "TEST FAILED: Scoreboard mismatches found")
      end
    endfunction

  endclass
  class riscv_coverage extends uvm_subscriber #(riscv_retire_item);
    `uvm_component_utils(riscv_coverage)

    bit [6:0] opcode;
    bit [2:0] funct3;
    bit       reg_we;
    bit       trap;

    covergroup cg;
      option.per_instance = 1;

      cp_opcode: coverpoint opcode {
        bins alu_reg = {OPCODE_OP};
        bins alu_imm = {OPCODE_OP_IMM};
        bins load    = {OPCODE_LOAD};
        bins store   = {OPCODE_STORE};
        bins branch  = {OPCODE_BRANCH};
        bins jal     = {OPCODE_JAL};
        bins system  = {OPCODE_SYSTEM};
      }
	
      cp_funct3: coverpoint funct3 {
        bins f0 = {3'b000};
        bins f1 = {3'b001};
        bins f2 = {3'b010};
        bins f4 = {3'b100};
        bins f6 = {3'b110};
        bins f7 = {3'b111};
      }

      cp_reg_we: coverpoint reg_we {
        bins no_write = {0};
        bins write    = {1};
      }

      cp_trap: coverpoint trap {
        bins no_trap = {0};
        bins trap_seen = {1};
      }

      cross cp_opcode, cp_reg_we;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg = new();
    endfunction

    function void write(riscv_retire_item t);
      opcode = t.instr[6:0];
      funct3 = t.instr[14:12];
      reg_we = t.reg_we;
      trap   = t.trap;

      cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);

  real cov;

  cov = cg.get_inst_coverage();

  `uvm_info("COVERAGE",
    $sformatf("Functional coverage = %0.2f%%", cov),
    UVM_LOW)

  if (cov < 90.0)
    `uvm_warning("COVERAGE",
      "Coverage below target")
  else
    `uvm_info("COVERAGE",
      "Coverage target achieved",
      UVM_LOW)

endfunction

  endclass
  class riscv_env extends uvm_env;
    `uvm_component_utils(riscv_env)

    riscv_sequencer  sqr;
    riscv_driver     drv;
    riscv_monitor    mon;
    riscv_scoreboard scb;
    riscv_coverage cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = riscv_sequencer::type_id::create("sqr", this);
      drv = riscv_driver::type_id::create("drv", this);
      mon = riscv_monitor::type_id::create("mon", this);
      scb = riscv_scoreboard::type_id::create("scb", this);
      cov = riscv_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
      mon.retire_ap.connect(scb.retire_export);
      mon.retire_ap.connect(cov.analysis_export);
    endfunction
  endclass

  class riscv_directed_seq extends uvm_sequence #(riscv_instr_mem_item);
    `uvm_object_utils(riscv_directed_seq)

    function new(string name = "riscv_directed_seq");
      super.new(name);
    endfunction

    task body();
      riscv_instr_mem_item req;
      req = riscv_instr_mem_item::type_id::create("req");

      start_item(req);

      req.instr_mem.delete();

      req.instr_mem.push_back(enc_addi(5'd1, 5'd0, 10));
      req.instr_mem.push_back(enc_addi(5'd2, 5'd0, 7));
      req.instr_mem.push_back(enc_add(5'd3, 5'd1, 5'd2));
      req.instr_mem.push_back(enc_sub(5'd4, 5'd3, 5'd2));

      req.instr_mem.push_back(enc_sw(5'd3, 5'd0, 0));
      req.instr_mem.push_back(enc_lw(5'd5, 5'd0, 0));
      req.instr_mem.push_back(enc_add(5'd6, 5'd5, 5'd1));

      req.instr_mem.push_back(enc_beq(5'd6, 5'd6, 8));
      req.instr_mem.push_back(enc_addi(5'd7, 5'd0, 99));
      req.instr_mem.push_back(enc_addi(5'd8, 5'd0, 123));

      req.instr_mem.push_back(enc_ecall());

      req.max_cycles = 500;

      finish_item(req);
    endtask
  endclass

    class riscv_random_seq extends uvm_sequence #(riscv_instr_mem_item);
    `uvm_object_utils(riscv_random_seq)

    function new(string name = "riscv_random_seq");
      super.new(name);
    endfunction

    function automatic bit [4:0] rnz();
      rnz = $urandom_range(1, 15);
    endfunction

    function automatic int signed rand_small_imm();
      rand_small_imm = int'($urandom_range(0, 31)) - 16;
    endfunction

    function automatic int signed rand_mem_imm();
      rand_mem_imm = 4 * int'($urandom_range(0, 15));
    endfunction

    task body();
      riscv_instr_mem_item req;

      int kind;
      int signed imm;

      bit [4:0] rd;
      bit [4:0] rs1;
      bit [4:0] rs2;
      bit [4:0] use_rd;

      req = riscv_instr_mem_item::type_id::create("req");

      start_item(req);

      req.instr_mem.delete();

      // Initialize registers x1-x8 with known values.
      req.instr_mem.push_back(enc_addi(5'd1, 5'd0, 5));
      req.instr_mem.push_back(enc_addi(5'd2, 5'd0, 10));
      req.instr_mem.push_back(enc_addi(5'd3, 5'd0, 15));
      req.instr_mem.push_back(enc_addi(5'd4, 5'd0, 20));
      req.instr_mem.push_back(enc_addi(5'd5, 5'd0, 25));
      req.instr_mem.push_back(enc_addi(5'd6, 5'd0, 30));
      req.instr_mem.push_back(enc_addi(5'd7, 5'd0, 35));
      req.instr_mem.push_back(enc_addi(5'd8, 5'd0, 40));

      repeat (25) begin
        kind = $urandom_range(0, 7);

        rd     = rnz();
        rs1    = rnz();
        rs2    = rnz();
        use_rd = rnz();

        case (kind)

          // RAW forwarding hazard:
          // result of ADD is immediately consumed by XOR.
          0: begin
            req.instr_mem.push_back(enc_add(rd, rs1, rs2));
            req.instr_mem.push_back(enc_xor(use_rd, rd, rs1));
          end

          // Load-use hazard:
          // LW result is immediately consumed by ADD.
          1: begin
            imm = rand_mem_imm();

            req.instr_mem.push_back(enc_sw(rs2, 5'd0, imm));
            req.instr_mem.push_back(enc_lw(rd, 5'd0, imm));
            req.instr_mem.push_back(enc_add(use_rd, rd, rs2));
          end

          // Store after ALU result:
          // ADDI updates rs2, then SW immediately stores it.
          2: begin
            imm = rand_mem_imm();

            req.instr_mem.push_back(enc_addi(rs2, rs2, 1));
            req.instr_mem.push_back(enc_sw(rs2, 5'd0, imm));
            req.instr_mem.push_back(enc_lw(rd, 5'd0, imm));
          end

          // Branch taken:
          // BEQ rs1,rs1 always taken, so next ADDI is flushed/skipped.
          3: begin
            req.instr_mem.push_back(enc_beq(rs1, rs1, 8));
            req.instr_mem.push_back(enc_addi(rnz(), 5'd0, 99)); // should be skipped
            req.instr_mem.push_back(enc_addi(rnz(), 5'd0, 1));  // branch target
          end

          // Branch not taken:
          // BNE rs1,rs1 is false, so next instruction executes.
          4: begin
            req.instr_mem.push_back(enc_bne(rs1, rs1, 8));
            req.instr_mem.push_back(enc_addi(rd, rs1, 2));
          end

          // JAL redirect:
          // JAL skips one instruction and writes PC+4 to rd.
          5: begin
            req.instr_mem.push_back(enc_jal(8, rd));
            req.instr_mem.push_back(enc_addi(rnz(), 5'd0, 77)); // should be skipped
            req.instr_mem.push_back(enc_addi(rnz(), 5'd0, 3));  // jump target
          end

          // ADDI followed by dependent OR.
          6: begin
            imm = rand_small_imm();

            req.instr_mem.push_back(enc_addi(rd, rs1, imm));
            req.instr_mem.push_back(enc_or(use_rd, rd, rs2));
          end

          // Mixed ALU operations.
          7: begin
            req.instr_mem.push_back(enc_and(rd, rs1, rs2));
            req.instr_mem.push_back(enc_or(use_rd, rd, rs1));
            req.instr_mem.push_back(enc_xor(rnz(), use_rd, rs2));
          end

          default: begin
            req.instr_mem.push_back(enc_addi(rd, 5'd0, 0));
          end

        endcase
      end

      req.instr_mem.push_back(enc_ecall());

      req.max_cycles = 3000;

      finish_item(req);
    endtask

  endclass

  class riscv_base_test extends uvm_test;
    `uvm_component_utils(riscv_base_test)

    riscv_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = riscv_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      riscv_directed_seq seq;
      phase.raise_objection(this);
      seq = riscv_directed_seq::type_id::create("seq");
      seq.start(env.sqr);
      phase.drop_objection(this);
    endtask
  endclass

  class riscv_directed_test extends riscv_base_test;
    `uvm_component_utils(riscv_directed_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class riscv_random_test extends riscv_base_test;
    `uvm_component_utils(riscv_random_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      riscv_random_seq seq;
      phase.raise_objection(this);
      seq = riscv_random_seq::type_id::create("seq");
      seq.start(env.sqr);
      phase.drop_objection(this);
    endtask
  endclass
endpackage
