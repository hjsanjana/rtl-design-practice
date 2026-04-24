// ============================================================
// AXI4-Lite Master — single write and read transactions
// ============================================================

module axi4_lite_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // User interface
    input  logic                    wr_en,
    input  logic                    rd_en,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    input  logic [DATA_WIDTH/8-1:0] wr_strb,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    wr_done,
    output logic                    rd_done,
    output logic                    err,

    // AXI4-Lite Write Address Channel
    output logic                    AWVALID,
    input  logic                    AWREADY,
    output logic [ADDR_WIDTH-1:0]   AWADDR,
    output logic [2:0]              AWPROT,

    // AXI4-Lite Write Data Channel
    output logic                    WVALID,
    input  logic                    WREADY,
    output logic [DATA_WIDTH-1:0]   WDATA,
    output logic [DATA_WIDTH/8-1:0] WSTRB,

    // AXI4-Lite Write Response Channel
    input  logic                    BVALID,
    output logic                    BREADY,
    input  logic [1:0]              BRESP,

    // AXI4-Lite Read Address Channel
    output logic                    ARVALID,
    input  logic                    ARREADY,
    output logic [ADDR_WIDTH-1:0]   ARADDR,
    output logic [2:0]              ARPROT,

    // AXI4-Lite Read Data Channel
    input  logic                    RVALID,
    output logic                    RREADY,
    input  logic [DATA_WIDTH-1:0]   RDATA,
    input  logic [1:0]              RRESP
);

// ============================================================
// Write FSM
// ============================================================
typedef enum logic [1:0] {
    WR_IDLE = 2'b00,
    WR_ADDR = 2'b01,   // Sending AW (and W simultaneously)
    WR_RESP = 2'b10    // Waiting for B
} wr_state_t;
wr_state_t wr_state;

always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        wr_state <= WR_IDLE;
        AWVALID  <= 1'b0;
        AWADDR   <= '0;
        AWPROT   <= 3'b000;
        WVALID   <= 1'b0;
        WDATA    <= '0;
        WSTRB    <= '0;
        BREADY   <= 1'b0;
        wr_done  <= 1'b0;
        err      <= 1'b0;
    end else begin
        wr_done <= 1'b0;
        err     <= 1'b0;

        case (wr_state)

            WR_IDLE: begin
                AWVALID <= 1'b0;
                WVALID  <= 1'b0;
                BREADY  <= 1'b0;
                if (wr_en) begin
                    // Assert AW and W simultaneously — most efficient
                    AWVALID  <= 1'b1;
                    AWADDR   <= addr;
                    AWPROT   <= 3'b000;
                    WVALID   <= 1'b1;
                    WDATA    <= wr_data;
                    WSTRB    <= wr_strb;
                    wr_state <= WR_ADDR;
                end
            end

            WR_ADDR: begin
                // Clear AWVALID once AW handshake completes
                if (AWVALID && AWREADY) begin
                    AWVALID <= 1'b0;
                end
                // Clear WVALID once W handshake completes
                if (WVALID && WREADY) begin
                    WVALID <= 1'b0;
                end
                // Move to response phase once BOTH channels are done
                if ((!AWVALID || AWREADY) && (!WVALID || WREADY)) begin
                    BREADY   <= 1'b1;    // Ready to accept response
                    wr_state <= WR_RESP;
                end
            end

            WR_RESP: begin
                if (BVALID && BREADY) begin
                    BREADY   <= 1'b0;
                    wr_done  <= 1'b1;
                    err      <= (BRESP != 2'b00);
                    wr_state <= WR_IDLE;
                end
            end

        endcase
    end
end

// ============================================================
// Read FSM — independent of write FSM
// ============================================================
typedef enum logic [1:0] {
    RD_IDLE = 2'b00,
    RD_ADDR = 2'b01,   // Sending AR
    RD_DATA = 2'b10    // Waiting for R
} rd_state_t;
rd_state_t rd_state;

always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        rd_state <= RD_IDLE;
        ARVALID  <= 1'b0;
        ARADDR   <= '0;
        ARPROT   <= 3'b000;
        RREADY   <= 1'b0;
        rd_data  <= '0;
        rd_done  <= 1'b0;
    end else begin
        rd_done <= 1'b0;

        case (rd_state)

            RD_IDLE: begin
                ARVALID <= 1'b0;
                RREADY  <= 1'b0;
                if (rd_en) begin
                    ARVALID  <= 1'b1;
                    ARADDR   <= addr;
                    ARPROT   <= 3'b000;
                    rd_state <= RD_ADDR;
                end
            end

            RD_ADDR: begin
                if (ARVALID && ARREADY) begin
                    ARVALID  <= 1'b0;
                    RREADY   <= 1'b1;  // Ready to receive data
                    rd_state <= RD_DATA;
                end
            end

            RD_DATA: begin
                if (RVALID && RREADY) begin
                    rd_data  <= RDATA;
                    rd_done  <= 1'b1;
                    RREADY   <= 1'b0;
                    rd_state <= RD_IDLE;
                end
            end

        endcase
    end
end

endmodule\