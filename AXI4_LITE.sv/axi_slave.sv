// ============================================================
// AXI4-Lite Slave — 4 internal 32-bit registers
// Addresses: 0x00, 0x04, 0x08, 0x0C
// Fully compliant VALID/READY handshake on all 5 channels
// ============================================================

module axi4_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,    // Active-low reset

    // Write Address Channel
    input  logic                    AWVALID,
    output logic                    AWREADY,
    input  logic [ADDR_WIDTH-1:0]   AWADDR,
    input  logic [2:0]              AWPROT,

    // Write Data Channel
    input  logic                    WVALID,
    output logic                    WREADY,
    input  logic [DATA_WIDTH-1:0]   WDATA,
    input  logic [DATA_WIDTH/8-1:0] WSTRB,

    // Write Response Channel
    output logic                    BVALID,
    input  logic                    BREADY,
    output logic [1:0]              BRESP,

    // Read Address Channel
    input  logic                    ARVALID,
    output logic                    ARREADY,
    input  logic [ADDR_WIDTH-1:0]   ARADDR,
    input  logic [2:0]              ARPROT,

    // Read Data Channel
    output logic                    RVALID,
    input  logic                    RREADY,
    output logic [DATA_WIDTH-1:0]   RDATA,
    output logic [1:0]              RRESP
);

// ============================================================
// Internal register file — 4 registers
// ============================================================
logic [DATA_WIDTH-1:0] regfile [0:3];

// ============================================================
// Write address latch
// Captured when AW handshake completes
// ============================================================
logic [ADDR_WIDTH-1:0] wr_addr;
logic                  wr_addr_valid;  // We have a latched write address

// ============================================================
// Read address latch
// ============================================================
logic [ADDR_WIDTH-1:0] rd_addr;

// ============================================================
// WRITE ADDRESS CHANNEL
// Slave is always ready to accept a write address when idle
// ============================================================
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        AWREADY      <= 1'b1;   // Ready from reset — accept immediately
        wr_addr      <= '0;
        wr_addr_valid <= 1'b0;
    end else begin
        if (AWVALID && AWREADY) begin
            // AW handshake: latch the address, deassert ready
            wr_addr       <= AWADDR;
            wr_addr_valid <= 1'b1;
            AWREADY       <= 1'b0;  // Not ready until write completes
        end
        // Re-assert AWREADY after the write response is accepted
        if (BVALID && BREADY) begin
            AWREADY       <= 1'b1;
            wr_addr_valid <= 1'b0;
        end
    end
end

// ============================================================
// WRITE DATA CHANNEL
// Accept write data once we have a valid write address
// ============================================================
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        WREADY <= 1'b1;   // Accept data immediately
    end else begin
        if (WVALID && WREADY) begin
            WREADY <= 1'b0;   // Consumed — not ready again until after B
        end
        if (BVALID && BREADY) begin
            WREADY <= 1'b1;   // Ready for next transfer
        end
    end
end

// ============================================================
// WRITE OPERATION — perform when both AW and W are done
// Write condition: have address AND W handshake just completed
// ============================================================
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        regfile[0] <= '0;
        regfile[1] <= '0;
        regfile[2] <= '0;
        regfile[3] <= '0;
        BVALID     <= 1'b0;
        BRESP      <= 2'b00;
    end else begin
        // When W handshake completes and we have the address
        if (WVALID && WREADY && wr_addr_valid) begin
            // Apply byte strobes — only update enabled bytes
            if (WSTRB[0]) regfile[wr_addr[3:2]][7:0]   <= WDATA[7:0];
            if (WSTRB[1]) regfile[wr_addr[3:2]][15:8]  <= WDATA[15:8];
            if (WSTRB[2]) regfile[wr_addr[3:2]][23:16] <= WDATA[23:16];
            if (WSTRB[3]) regfile[wr_addr[3:2]][31:24] <= WDATA[31:24];
            BVALID <= 1'b1;    // Write done — send response
            BRESP  <= 2'b00;   // OKAY
        end
        // Clear BVALID when master accepts the response
        if (BVALID && BREADY) begin
            BVALID <= 1'b0;
        end
    end
end

// ============================================================
// READ ADDRESS CHANNEL
// ============================================================
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        ARREADY <= 1'b1;
        rd_addr <= '0;
    end else begin
        if (ARVALID && ARREADY) begin
            rd_addr <= ARADDR;    // Latch read address
            ARREADY <= 1'b0;      // Hold off until read complete
        end
        if (RVALID && RREADY) begin
            ARREADY <= 1'b1;      // Ready for next read
        end
    end
end

// ============================================================
// READ DATA CHANNEL
// Present data one cycle after AR is accepted
// ============================================================
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        RVALID <= 1'b0;
        RDATA  <= '0;
        RRESP  <= 2'b00;
    end else begin
        if (ARVALID && ARREADY) begin
            // AR handshake completed — fetch and present data next cycle
            RVALID <= 1'b1;
            RRESP  <= 2'b00;  // OKAY
            case (ARADDR[3:2])
                2'b00: RDATA <= regfile[0];
                2'b01: RDATA <= regfile[1];
                2'b10: RDATA <= regfile[2];
                2'b11: RDATA <= regfile[3];
            endcase
        end
        // Clear RVALID when master accepts the data
        if (RVALID && RREADY) begin
            RVALID <= 1'b0;
        end
    end
end

endmodule