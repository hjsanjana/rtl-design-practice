`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Simple PCIe-like Transaction Layer Interface
// -----------------------------------------------------------------------------
// This is a simplified TLP interface for learning UVM verification.
// One valid handshake represents one complete TLP.
//
// tlp_type:
//   0 = Memory Read
//   1 = Memory Write
//
// resp_status:
//   0 = OK
//   1 = ERROR
// -----------------------------------------------------------------------------

interface pcie_tlp_if(input logic clk);

  logic rst_n;

  // Request channel
  logic        valid;
  logic        ready;
  logic [1:0]  tlp_type;
  logic [31:0] addr;
  logic [9:0]  length_dw;
  logic [7:0]  tag;
  logic [1023:0] payload;
  logic        malformed;

  // Response channel
  logic        resp_valid;
  logic [7:0]  resp_tag;
  logic [1:0]  resp_status;
  logic [1023:0] resp_payload;

  // Driver clocking block
  clocking drv_cb @(posedge clk);
    default input #1step output #1ns;

    output valid;
    output tlp_type;
    output addr;
    output length_dw;
    output tag;
    output payload;
    output malformed;

    input ready;
    input rst_n;
  endclocking

  // Monitor clocking block
  clocking mon_cb @(posedge clk);
    default input #1step output #1ns;

    input valid;
    input ready;
    input tlp_type;
    input addr;
    input length_dw;
    input tag;
    input payload;
    input malformed;

    input resp_valid;
    input resp_tag;
    input resp_status;
    input resp_payload;

    input rst_n;
  endclocking

endinterface



// -----------------------------------------------------------------------------
// Simple PCIe Transaction Layer DUT Model - Phase 2
// -----------------------------------------------------------------------------
// New in Phase 2:
//   1. Responses are delayed.
//   2. Multiple responses can be outstanding.
//   3. Responses may return out of order.
//   4. Response matching must be done using tag, not FIFO order.
// -----------------------------------------------------------------------------

module pcie_tlp_dut(pcie_tlp_if vif);

  localparam bit [1:0] TLP_MEM_RD = 2'd0;
  localparam bit [1:0] TLP_MEM_WR = 2'd1;

  localparam bit [1:0] RSP_OK  = 2'd0;
  localparam bit [1:0] RSP_ERR = 2'd1;

  typedef struct packed {
    logic        valid;
    logic [7:0]  tag;
    logic [1:0]  status;
    logic [1023:0] payload;
    logic [3:0]  delay;
  } pending_rsp_t;

  logic [31:0] mem [0:255];

  pending_rsp_t pending_rsp [0:15];

  integer i;
  integer free_slot;
  integer send_slot;

  logic [1023:0] read_payload;

  wire bad_packet;

  assign vif.ready = vif.rst_n;

  assign bad_packet =
      vif.malformed                  ||
      (vif.addr[1:0] != 2'b00)        ||
      (vif.length_dw == 0)            ||
      (vif.length_dw > 32)            ||
      ((vif.tlp_type != TLP_MEM_RD) &&
       (vif.tlp_type != TLP_MEM_WR));

  // Different tags create different response latencies.
  // This intentionally creates out-of-order completions.
  function automatic logic [3:0] calc_response_delay(
    input logic [7:0] tag,
    input logic [1:0] tlp_type
  );
    logic [3:0] delay_value;

    begin
      delay_value = 4'(1 + (tag[2:0] % 5));

      if (tlp_type == TLP_MEM_RD) begin
        delay_value = delay_value + 1;
      end

      return delay_value;
    end
  endfunction

  always_ff @(posedge vif.clk or negedge vif.rst_n) begin
    if (!vif.rst_n) begin
      vif.resp_valid   <= 1'b0;
      vif.resp_tag     <= '0;
      vif.resp_status  <= RSP_OK;
      vif.resp_payload <= '0;

      for (i = 0; i < 256; i++) begin
        mem[i] <= '0;
      end

      for (i = 0; i < 16; i++) begin
        pending_rsp[i].valid   <= 1'b0;
        pending_rsp[i].tag     <= '0;
        pending_rsp[i].status  <= RSP_OK;
        pending_rsp[i].payload <= '0;
        pending_rsp[i].delay   <= '0;
      end
    end
    else begin
      vif.resp_valid   <= 1'b0;
      vif.resp_tag     <= '0;
      vif.resp_status  <= RSP_OK;
      vif.resp_payload <= '0;

      // ------------------------------------------------------------
      // Decrement delay counters for pending completions
      // ------------------------------------------------------------
      for (i = 0; i < 16; i++) begin
        if (pending_rsp[i].valid && pending_rsp[i].delay > 0) begin
          pending_rsp[i].delay <= pending_rsp[i].delay - 1;
        end
      end

      // ------------------------------------------------------------
      // Choose one ready response to send.
      // Search from high index to low index to make response order
      // less FIFO-like.
      // ------------------------------------------------------------
      send_slot = -1;

      for (i = 15; i >= 0; i--) begin
        if (pending_rsp[i].valid &&
            pending_rsp[i].delay == 0 &&
            send_slot == -1) begin
          send_slot = i;
        end
      end

      if (send_slot != -1) begin
        vif.resp_valid   <= 1'b1;
        vif.resp_tag     <= pending_rsp[send_slot].tag;
        vif.resp_status  <= pending_rsp[send_slot].status;
        vif.resp_payload <= pending_rsp[send_slot].payload;

        pending_rsp[send_slot].valid <= 1'b0;
      end

      // ------------------------------------------------------------
      // Accept a new request and create a delayed response
      // ------------------------------------------------------------
      if (vif.valid && vif.ready) begin
        read_payload = '0;

        // Good Memory Write: update memory immediately
        if (!bad_packet && vif.tlp_type == TLP_MEM_WR) begin
          for (i = 0; i < 32; i++) begin
            if (i < vif.length_dw) begin
              mem[((vif.addr[9:2]) + i) & 8'hFF] <= vif.payload[i*32 +: 32];
            end
          end
        end

        // Good Memory Read: capture response payload at request time
        if (!bad_packet && vif.tlp_type == TLP_MEM_RD) begin
          for (i = 0; i < 32; i++) begin
            if (i < vif.length_dw) begin
              read_payload[i*32 +: 32] = mem[((vif.addr[9:2]) + i) & 8'hFF];
            end
          end
        end

        // Find free pending response slot
        free_slot = -1;

        for (i = 0; i < 16; i++) begin
          if (!pending_rsp[i].valid && free_slot == -1) begin
            free_slot = i;
          end
        end

        if (free_slot != -1) begin
          pending_rsp[free_slot].valid   <= 1'b1;
          pending_rsp[free_slot].tag     <= vif.tag;
          pending_rsp[free_slot].status  <= bad_packet ? RSP_ERR : RSP_OK;
          pending_rsp[free_slot].payload <= read_payload;
          pending_rsp[free_slot].delay   <= calc_response_delay(vif.tag, vif.tlp_type);
        end
        else begin
          $display("[%0t] ERROR: DUT pending response queue full", $time);
        end
      end
    end
  end

endmodule
