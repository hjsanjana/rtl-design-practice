`timescale 1ns/1ps

package pcie_tlp_uvm_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---------------------------------------------------------------------------
  // TLP Type and Response Status
  // ---------------------------------------------------------------------------

  typedef enum bit [1:0] {
    TLP_MEM_RD = 2'd0,
    TLP_MEM_WR = 2'd1
  } pcie_tlp_type_e;

  typedef enum bit [1:0] {
    RSP_OK  = 2'd0,
    RSP_ERR = 2'd1
  } pcie_rsp_status_e;


  // ---------------------------------------------------------------------------
  // PCIe TLP Sequence Item
  // ---------------------------------------------------------------------------

  class pcie_tlp extends uvm_sequence_item;

    rand pcie_tlp_type_e tlp_type;
    rand bit [31:0]      addr;
    rand bit [9:0]       length_dw;
    rand bit [7:0]       tag;
    rand bit             malformed;
    rand bit [31:0]      payload[];

    `uvm_object_utils(pcie_tlp)

    function new(string name = "pcie_tlp");
      super.new(name);
    endfunction

    // Valid packets are aligned and length is 1 to 8 DW.
    // Malformed packets intentionally violate at least one rule.
    constraint c_packet_shape {
      malformed dist {0 := 85, 1 := 15};

      if (!malformed) {
        addr[1:0] == 2'b00;
        length_dw inside {[1:8]};
        tlp_type inside {TLP_MEM_RD, TLP_MEM_WR};
      }
      else {
        length_dw inside {0, [1:8], [33:40]};
        ((addr[1:0] != 2'b00) || (length_dw == 0) || (length_dw > 32));
      }

      if ((tlp_type == TLP_MEM_WR) && (length_dw inside {[1:32]})) {
        payload.size() == length_dw;
      }
      else {
        payload.size() == 0;
      }
    }

    function string type_to_string();
      case (tlp_type)
        TLP_MEM_RD: return "MEM_RD";
        TLP_MEM_WR: return "MEM_WR";
        default:    return $sformatf("UNKNOWN_%0d", tlp_type);
      endcase
    endfunction

    function string convert2string();
      return $sformatf(
        "type=%s addr=0x%08h len_dw=%0d tag=0x%02h malformed=%0b payload_words=%0d",
        type_to_string(),
        addr,
        length_dw,
        tag,
        malformed,
        payload.size()
      );
    endfunction

  endclass


  // ---------------------------------------------------------------------------
  // PCIe Response Item
  // ---------------------------------------------------------------------------

  class pcie_tlp_rsp extends uvm_sequence_item;

    bit [7:0]    tag;
    bit [1:0]    status;
    bit [1023:0] payload;

    `uvm_object_utils(pcie_tlp_rsp)

    function new(string name = "pcie_tlp_rsp");
      super.new(name);
    endfunction

    function string status_to_string();
      case (status)
        RSP_OK:  return "OK";
        RSP_ERR: return "ERROR";
        default: return $sformatf("UNKNOWN_%0d", status);
      endcase
    endfunction

    function string convert2string();
      return $sformatf(
        "rsp_tag=0x%02h status=%s",
        tag,
        status_to_string()
      );
    endfunction

  endclass


  // ---------------------------------------------------------------------------
  // Sequencer
  // ---------------------------------------------------------------------------

  class pcie_tlp_sequencer extends uvm_sequencer #(pcie_tlp);

    `uvm_component_utils(pcie_tlp_sequencer)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

  endclass


  // ---------------------------------------------------------------------------
  // Driver
  // ---------------------------------------------------------------------------

  class pcie_tlp_driver extends uvm_driver #(pcie_tlp);

    `uvm_component_utils(pcie_tlp_driver)

    virtual pcie_tlp_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(virtual pcie_tlp_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("DRV_NO_VIF", "Virtual interface not found in driver")
      end
    endfunction

    task run_phase(uvm_phase phase);
      pcie_tlp tx;

      vif.valid     <= 1'b0;
      vif.tlp_type  <= '0;
      vif.addr      <= '0;
      vif.length_dw <= '0;
      vif.tag       <= '0;
      vif.payload   <= '0;
      vif.malformed <= 1'b0;

      wait (vif.rst_n == 1'b1);

      forever begin
        seq_item_port.get_next_item(tx);
        drive_one_tlp(tx);
        seq_item_port.item_done();
      end
    endtask

 function bit [1023:0] pack_payload(pcie_tlp tx);
  bit [1023:0] packed_payload;

  packed_payload = '0;

  foreach (tx.payload[i]) begin
    if (i < 32) begin
      packed_payload[i*32 +: 32] = tx.payload[i];
    end
  end

  return packed_payload;
endfunction

    task drive_one_tlp(pcie_tlp tx);
      `uvm_info("DRIVER", $sformatf("Driving: %s", tx.convert2string()), UVM_MEDIUM)

      @(vif.drv_cb);

      vif.drv_cb.valid     <= 1'b1;
      vif.drv_cb.tlp_type  <= tx.tlp_type;
      vif.drv_cb.addr      <= tx.addr;
      vif.drv_cb.length_dw <= tx.length_dw;
      vif.drv_cb.tag       <= tx.tag;
      vif.drv_cb.payload   <= pack_payload(tx);
      vif.drv_cb.malformed <= tx.malformed;

      do begin
        @(vif.drv_cb);
      end while (vif.drv_cb.ready !== 1'b1);

      vif.drv_cb.valid     <= 1'b0;
      vif.drv_cb.tlp_type  <= '0;
      vif.drv_cb.addr      <= '0;
      vif.drv_cb.length_dw <= '0;
      vif.drv_cb.tag       <= '0;
      vif.drv_cb.payload   <= '0;
      vif.drv_cb.malformed <= 1'b0;
    endtask

  endclass


  // ---------------------------------------------------------------------------
  // Monitor
  // ---------------------------------------------------------------------------

  class pcie_tlp_monitor extends uvm_monitor;

    `uvm_component_utils(pcie_tlp_monitor)

    virtual pcie_tlp_if vif;

    uvm_analysis_port #(pcie_tlp)     req_ap;
    uvm_analysis_port #(pcie_tlp_rsp) rsp_ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      req_ap = new("req_ap", this);
      rsp_ap = new("rsp_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(virtual pcie_tlp_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("MON_NO_VIF", "Virtual interface not found in monitor")
      end
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(vif.mon_cb);

        if (vif.mon_cb.rst_n) begin

          if (vif.mon_cb.valid && vif.mon_cb.ready) begin
            capture_request();
          end

          if (vif.mon_cb.resp_valid) begin
            capture_response();
          end

        end
      end
    endtask

    task capture_request();
      pcie_tlp tx;
      int payload_words;

      tx = pcie_tlp::type_id::create("tx", this);

      tx.tlp_type  = pcie_tlp_type_e'(vif.mon_cb.tlp_type);
      tx.addr      = vif.mon_cb.addr;
      tx.length_dw = vif.mon_cb.length_dw;
      tx.tag       = vif.mon_cb.tag;
      tx.malformed = vif.mon_cb.malformed;

      payload_words = 0;

      if ((vif.mon_cb.tlp_type == TLP_MEM_WR) &&
          (vif.mon_cb.length_dw > 0) &&
          (vif.mon_cb.length_dw <= 32)) begin
        payload_words = vif.mon_cb.length_dw;
      end

      tx.payload = new[payload_words];

      for (int i = 0; i < payload_words; i++) begin
        tx.payload[i] = vif.mon_cb.payload[i*32 +: 32];
      end

      `uvm_info("MON_REQ", $sformatf("Observed request: %s", tx.convert2string()), UVM_MEDIUM)

      req_ap.write(tx);
    endtask

    task capture_response();
      pcie_tlp_rsp rsp;

      rsp = pcie_tlp_rsp::type_id::create("rsp", this);

      rsp.tag     = vif.mon_cb.resp_tag;
      rsp.status  = vif.mon_cb.resp_status;
      rsp.payload = vif.mon_cb.resp_payload;

      `uvm_info("MON_RSP", $sformatf("Observed response: %s", rsp.convert2string()), UVM_MEDIUM)

      rsp_ap.write(rsp);
    endtask

  endclass


  // ---------------------------------------------------------------------------
  // Functional Coverage
  // ---------------------------------------------------------------------------

  class pcie_tlp_coverage extends uvm_subscriber #(pcie_tlp);

    `uvm_component_utils(pcie_tlp_coverage)

    pcie_tlp_type_e cov_type;
    bit [9:0]       cov_length_dw;
    bit             cov_malformed;
    bit [1:0]       cov_addr_lsb;

    covergroup tlp_cg;

      option.per_instance = 1;

      cp_type: coverpoint cov_type {
        bins mem_read  = {TLP_MEM_RD};
        bins mem_write = {TLP_MEM_WR};
      }

      cp_length: coverpoint cov_length_dw {
        bins zero_len    = {0};
        bins small_len   = {[1:2]};
        bins medium_len  = {[3:8]};
        bins large_len   = {[9:32]};
        bins invalid_len = {[33:1023]};
      }

      cp_malformed: coverpoint cov_malformed {
        bins good_packet = {0};
        bins bad_packet  = {1};
      }

      cp_addr_align: coverpoint cov_addr_lsb {
        bins aligned    = {2'b00};
        bins unaligned1 = {2'b01};
        bins unaligned2 = {2'b10};
        bins unaligned3 = {2'b11};
      }

      cross_type_length: cross cp_type, cp_length;
      cross_malformed_align: cross cp_malformed, cp_addr_align;

    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      tlp_cg = new();
    endfunction

    function void write(pcie_tlp t);
      cov_type      = t.tlp_type;
      cov_length_dw = t.length_dw;
      cov_malformed = t.malformed;
      cov_addr_lsb  = t.addr[1:0];

      tlp_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("COVERAGE",
        $sformatf("PCIe TLP functional coverage = %0.2f%%", tlp_cg.get_coverage()),
        UVM_NONE)
    endfunction

  endclass
  // ---------------------------------------------------------------------------
  // Expected Entry for Tag-Based Scoreboard
  // ---------------------------------------------------------------------------

  class pcie_expected_entry extends uvm_object;

    `uvm_object_utils(pcie_expected_entry)

    pcie_tlp     req;
    bit [1:0]    exp_status;
    bit [1023:0] exp_read_payload;

    function new(string name = "pcie_expected_entry");
      super.new(name);
    endfunction

  endclass

    // ---------------------------------------------------------------------------
  // Scoreboard - Phase 2 Tag-Based Matching
  // ---------------------------------------------------------------------------

  class pcie_tlp_scoreboard extends uvm_component;

    `uvm_component_utils(pcie_tlp_scoreboard)

    uvm_tlm_analysis_fifo #(pcie_tlp)     req_fifo;
    uvm_tlm_analysis_fifo #(pcie_tlp_rsp) rsp_fifo;

    // Expected memory model
    bit [31:0] exp_mem [int unsigned];

    // Outstanding request table indexed by PCIe tag
    pcie_expected_entry outstanding [bit [7:0]];

    int req_count;
    int rsp_count;
    int checked_count;
    int error_count;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      req_fifo = new("req_fifo", this);
      rsp_fifo = new("rsp_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
      fork
        collect_requests();
        collect_responses();
      join
    endtask

    task collect_requests();
      pcie_tlp req;

      forever begin
        req_fifo.get(req);
        req_count++;

        store_expected_request(req);
      end
    endtask

    task collect_responses();
      pcie_tlp_rsp rsp;

      forever begin
        rsp_fifo.get(rsp);
        rsp_count++;

        check_response_by_tag(rsp);
      end
    endtask

    function bit expected_error(pcie_tlp req);
      return (
        req.malformed ||
        (req.addr[1:0] != 2'b00) ||
        (req.length_dw == 0) ||
        (req.length_dw > 32) ||
        ((req.tlp_type != TLP_MEM_RD) && (req.tlp_type != TLP_MEM_WR))
      );
    endfunction

    function bit [31:0] get_payload_dw(bit [1023:0] packed_payload, int index);
      return packed_payload[index*32 +: 32];
    endfunction

    function bit [1023:0] build_expected_read_payload(pcie_tlp req);
      bit [1023:0] exp_payload;
      int unsigned base_idx;
      int unsigned mem_idx;
      bit [31:0] exp_data;

      exp_payload = '0;
      base_idx = req.addr[9:2];

      for (int i = 0; (i < req.length_dw) && (i < 32); i++) begin
        mem_idx = (base_idx + i) & 32'hFF;

        if (exp_mem.exists(mem_idx)) begin
          exp_data = exp_mem[mem_idx];
        end
        else begin
          exp_data = 32'h0000_0000;
        end

        exp_payload[i*32 +: 32] = exp_data;
      end

      return exp_payload;
    endfunction

    function void update_write_model(pcie_tlp req);
      int unsigned base_idx;
      int unsigned mem_idx;

      base_idx = req.addr[9:2];

      foreach (req.payload[i]) begin
        mem_idx = (base_idx + i) & 32'hFF;
        exp_mem[mem_idx] = req.payload[i];
      end
    endfunction

    function void store_expected_request(pcie_tlp req);
      pcie_expected_entry entry;
      bit exp_err;

      exp_err = expected_error(req);

      if (outstanding.exists(req.tag)) begin
        error_count++;

        `uvm_error("SCOREBOARD",
          $sformatf("DUPLICATE OUTSTANDING TAG: tag=0x%02h req=%s",
                    req.tag, req.convert2string()))
      end

      entry = pcie_expected_entry::type_id::create("entry");

      entry.req = req;

      if (exp_err) begin
        entry.exp_status = RSP_ERR;
        entry.exp_read_payload = '0;
      end
      else begin
        entry.exp_status = RSP_OK;

        if (req.tlp_type == TLP_MEM_RD) begin
          entry.exp_read_payload = build_expected_read_payload(req);
        end
        else begin
          entry.exp_read_payload = '0;
        end
      end

      outstanding[req.tag] = entry;

      // For this simplified DUT, memory write takes effect when request is accepted.
      if (!exp_err && req.tlp_type == TLP_MEM_WR) begin
        update_write_model(req);
      end

      `uvm_info("SCOREBOARD",
        $sformatf("Stored expected request by tag=0x%02h outstanding=%0d req=%s",
                  req.tag, outstanding.num(), req.convert2string()),
        UVM_LOW)
    endfunction

    task check_response_by_tag(pcie_tlp_rsp rsp);
      pcie_expected_entry entry;
      bit [31:0] exp_data;
      bit [31:0] got_data;

      rsp_count++;

      if (!outstanding.exists(rsp.tag)) begin
        error_count++;

        `uvm_error("SCOREBOARD",
          $sformatf("UNEXPECTED RESPONSE TAG: rsp_tag=0x%02h status=%0d",
                    rsp.tag, rsp.status))
        return;
      end

      entry = outstanding[rsp.tag];
      checked_count++;

      `uvm_info("SCOREBOARD",
        $sformatf("Checking response by tag=0x%02h req=%s rsp=%s",
                  rsp.tag, entry.req.convert2string(), rsp.convert2string()),
        UVM_LOW)

      // Check status
      if (rsp.status !== entry.exp_status) begin
        error_count++;

        `uvm_error("SCOREBOARD",
          $sformatf("STATUS MISMATCH tag=0x%02h expected=%0d got=%0d req=%s",
                    rsp.tag, entry.exp_status, rsp.status,
                    entry.req.convert2string()))
      end

      // If the request was expected to fail, no payload check is needed.
      if (entry.exp_status == RSP_ERR) begin
        outstanding.delete(rsp.tag);

        `uvm_info("SCOREBOARD",
          $sformatf("Correctly handled malformed/error packet by tag=0x%02h",
                    rsp.tag),
          UVM_LOW)

        return;
      end

      // For Memory Read, check response payload
      if (entry.req.tlp_type == TLP_MEM_RD) begin
        for (int i = 0; i < entry.req.length_dw; i++) begin
          exp_data = get_payload_dw(entry.exp_read_payload, i);
          got_data = get_payload_dw(rsp.payload, i);

          if (got_data !== exp_data) begin
            error_count++;

            `uvm_error("SCOREBOARD",
              $sformatf("READ DATA MISMATCH tag=0x%02h index=%0d expected=0x%08h got=0x%08h req=%s",
                        rsp.tag, i, exp_data, got_data,
                        entry.req.convert2string()))
          end
        end
      end

      outstanding.delete(rsp.tag);

      `uvm_info("SCOREBOARD",
        $sformatf("Response matched successfully by tag=0x%02h remaining_outstanding=%0d",
                  rsp.tag, outstanding.num()),
        UVM_LOW)
    endtask

    function void report_phase(uvm_phase phase);

      if (outstanding.num() != 0) begin
        error_count++;

        `uvm_error("SCOREBOARD",
          $sformatf("There are still %0d outstanding requests at end of test",
                    outstanding.num()))
      end

      if (error_count == 0) begin
        `uvm_info("SCOREBOARD",
          $sformatf("PASS: req=%0d checked_rsp=%0d outstanding=%0d errors=%0d",
                    req_count, checked_count, outstanding.num(), error_count),
          UVM_NONE)
      end
      else begin
        `uvm_error("SCOREBOARD",
          $sformatf("FAIL: req=%0d checked_rsp=%0d outstanding=%0d errors=%0d",
                    req_count, checked_count, outstanding.num(), error_count))
      end
    endfunction

  endclass
  // ---------------------------------------------------------------------------
  // Agent
  // ---------------------------------------------------------------------------

  class pcie_tlp_agent extends uvm_agent;

    `uvm_component_utils(pcie_tlp_agent)

    pcie_tlp_sequencer seqr;
    pcie_tlp_driver    drv;
    pcie_tlp_monitor   mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      seqr = pcie_tlp_sequencer::type_id::create("seqr", this);
      drv  = pcie_tlp_driver::type_id::create("drv", this);
      mon  = pcie_tlp_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction

  endclass


  // ---------------------------------------------------------------------------
  // Environment
  // ---------------------------------------------------------------------------

  class pcie_tlp_env extends uvm_env;

    `uvm_component_utils(pcie_tlp_env)

    pcie_tlp_agent      agent;
    pcie_tlp_scoreboard sb;
    pcie_tlp_coverage   cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      agent = pcie_tlp_agent::type_id::create("agent", this);
      sb    = pcie_tlp_scoreboard::type_id::create("sb", this);
      cov   = pcie_tlp_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      agent.mon.req_ap.connect(sb.req_fifo.analysis_export);
      agent.mon.rsp_ap.connect(sb.rsp_fifo.analysis_export);

      agent.mon.req_ap.connect(cov.analysis_export);
    endfunction

  endclass


  // ---------------------------------------------------------------------------
  // Main Test Sequence
  // ---------------------------------------------------------------------------

    // ---------------------------------------------------------------------------
  // Main Test Sequence - Phase 2
  // ---------------------------------------------------------------------------

  class pcie_tlp_main_seq extends uvm_sequence #(pcie_tlp);

    `uvm_object_utils(pcie_tlp_main_seq)

    function new(string name = "pcie_tlp_main_seq");
      super.new(name);
    endfunction

    task body();
      pcie_tlp tx;
      int unsigned next_tag;

      next_tag = 8'h40;

      `uvm_info("SEQ", "Starting PCIe TLP Phase 2 tag-based sequence", UVM_NONE)

      // -----------------------------------------------------------------------
      // Directed write: write 4 DW to address 0x40
      // -----------------------------------------------------------------------
      tx = pcie_tlp::type_id::create("directed_write");

      start_item(tx);
      tx.tlp_type  = TLP_MEM_WR;
      tx.addr      = 32'h0000_0040;
      tx.length_dw = 4;
      tx.tag       = 8'h01;
      tx.malformed = 1'b0;
      tx.payload   = new[4];

      tx.payload[0] = 32'hDEAD_BEEF;
      tx.payload[1] = 32'hCAFE_F00D;
      tx.payload[2] = 32'h1234_5678;
      tx.payload[3] = 32'hABCD_EF01;
      finish_item(tx);

      // -----------------------------------------------------------------------
      // Directed read: read same 4 DW back
      // -----------------------------------------------------------------------
      tx = pcie_tlp::type_id::create("directed_read");

      start_item(tx);
      tx.tlp_type  = TLP_MEM_RD;
      tx.addr      = 32'h0000_0040;
      tx.length_dw = 4;
      tx.tag       = 8'h02;
      tx.malformed = 1'b0;
      tx.payload   = new[0];
      finish_item(tx);

      // -----------------------------------------------------------------------
      // Directed out-of-order read burst
      // These tags produce different DUT response delays.
      // The scoreboard must match responses by tag, not by order.
      // -----------------------------------------------------------------------

      tx = pcie_tlp::type_id::create("ooo_read_long_delay");

      start_item(tx);
      tx.tlp_type  = TLP_MEM_RD;
      tx.addr      = 32'h0000_0040;
      tx.length_dw = 4;
      tx.tag       = 8'h13;
      tx.malformed = 1'b0;
      tx.payload   = new[0];
      finish_item(tx);

      tx = pcie_tlp::type_id::create("ooo_read_short_delay");

      start_item(tx);
      tx.tlp_type  = TLP_MEM_RD;
      tx.addr      = 32'h0000_0040;
      tx.length_dw = 4;
      tx.tag       = 8'h10;
      tx.malformed = 1'b0;
      tx.payload   = new[0];
      finish_item(tx);

      tx = pcie_tlp::type_id::create("ooo_read_medium_delay");

      start_item(tx);
      tx.tlp_type  = TLP_MEM_RD;
      tx.addr      = 32'h0000_0040;
      tx.length_dw = 4;
      tx.tag       = 8'h11;
      tx.malformed = 1'b0;
      tx.payload   = new[0];
      finish_item(tx);

      // -----------------------------------------------------------------------
      // Directed malformed packet: unaligned address
      // -----------------------------------------------------------------------
      tx = pcie_tlp::type_id::create("bad_unaligned_write");

      start_item(tx);
      tx.tlp_type  = TLP_MEM_WR;
      tx.addr      = 32'h0000_0043;
      tx.length_dw = 1;
      tx.tag       = 8'hE1;
      tx.malformed = 1'b1;
      tx.payload   = new[1];
      tx.payload[0] = 32'hBAD0_BAD0;
      finish_item(tx);

      // -----------------------------------------------------------------------
      // Directed malformed packet: invalid length
      // -----------------------------------------------------------------------
      tx = pcie_tlp::type_id::create("bad_length_read");

      start_item(tx);
      tx.tlp_type  = TLP_MEM_RD;
      tx.addr      = 32'h0000_0080;
      tx.length_dw = 0;
      tx.tag       = 8'hE2;
      tx.malformed = 1'b1;
      tx.payload   = new[0];
      finish_item(tx);

      // -----------------------------------------------------------------------
      // Constrained-random traffic with unique tags
      // -----------------------------------------------------------------------
      repeat (80) begin
        tx = pcie_tlp::type_id::create("random_tlp");

        start_item(tx);

        if (!tx.randomize()) begin
          `uvm_fatal("SEQ_RANDOMIZE_FAILED", "Failed to randomize PCIe TLP")
        end

        // Important for PCIe: do not reuse a tag while it is outstanding.
        tx.tag = next_tag[7:0];
        next_tag++;

        finish_item(tx);
      end

      `uvm_info("SEQ", "Completed PCIe TLP Phase 2 tag-based sequence", UVM_NONE)
    endtask

  endclass

      

  // ---------------------------------------------------------------------------
  // Test
  // ---------------------------------------------------------------------------

  class pcie_tlp_test extends uvm_test;

    `uvm_component_utils(pcie_tlp_test)

    pcie_tlp_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      env = pcie_tlp_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      pcie_tlp_main_seq seq;

      phase.raise_objection(this);

      seq = pcie_tlp_main_seq::type_id::create("seq");
      seq.start(env.agent.seqr);

      #100ns;

      phase.drop_objection(this);
    endtask

  endclass

endpackage


// -----------------------------------------------------------------------------
// Top-Level Testbench
// -----------------------------------------------------------------------------

module tb_top;

  import uvm_pkg::*;
  import pcie_tlp_uvm_pkg::*;

  bit clk;

  always #5 clk = ~clk;

  pcie_tlp_if  pcie_if(clk);
  pcie_tlp_dut dut(pcie_if);

  initial begin
    clk = 1'b0;
  end

  initial begin
    pcie_if.rst_n     = 1'b0;
    pcie_if.valid     = 1'b0;
    pcie_if.tlp_type  = '0;
    pcie_if.addr      = '0;
    pcie_if.length_dw = '0;
    pcie_if.tag       = '0;
    pcie_if.payload   = '0;
    pcie_if.malformed = 1'b0;

    repeat (5) @(posedge clk);

    pcie_if.rst_n = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual pcie_tlp_if)::set(
      null,
      "*",
      "vif",
      pcie_if
    );

    run_test("pcie_tlp_test");
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end

endmodule