// ============================================================
// AXI4 Full Slave — supports burst write and burst read
// INCR burst type, configurable depth memory
// ============================================================

module axi4_full_slave #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter MEM_DEPTH   = 256     // Words in internal memory
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // Write Address Channel
    input  logic                    AWVALID,
    output logic                    AWREADY,
    input  logic [ADDR_WIDTH-1:0]   AWADDR,
    input  logic [7:0]              AWLEN,
    input  logic [2:0]              AWSIZE,
    input  logic [1:0]              AWBURST,
    input  logic [2:0]              AWPROT,

    // Write Data Channel
    input  logic                    WVALID,
    output logic                    WREADY,
    input  logic [DATA_WIDTH-1:0]   WDATA,
    input  logic [DATA_WIDTH/8-1:0] WSTRB,
    input  logic                    WLAST,

    // Write Response Channel
    output logic                    BVALID,
    input  logic                    BREADY,
    output logic [1:0]              BRESP,

    // Read Address Channel
    input  logic                    ARVALID,
    output logic                    ARREADY,
    input  logic [ADDR_WIDTH-1:0]   ARADDR,
    input  logic [7:0]              ARLEN,
    input  logic [2:0]              ARSIZE,
    input  logic [1:0]              ARBURST,
    input  logic [2:0]              ARPROT,

    // Read Data Channel
    output logic                    RVALID,
    input  logic                    RREADY,
    output logic [DATA_WIDTH-1:0]   RDATA,
    output logic                    RLAST,
    output logic [1:0]              RRESP
);

// ============================================================
// Internal memory
// ============================================================
logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

// ============================================================
// Write address tracking
// ============================================================
logic [ADDR_WIDTH-1:0] wr_addr;
logic [7:0]            wr_len;
logic [7:0]            wr_beat_cnt;
logic                  wr_addr_valid;

// Accept write address
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        AWREADY      <= 1'b1;
        wr_addr      <= '0;
        wr_len       <= '0;
        wr_addr_valid <= 1'b0;
    end else begin
        if (AWVALID && AWREADY) begin
            wr_addr       <= AWADDR;
            wr_len        <= AWLEN;
            wr_addr_valid <= 1'b1;
            AWREADY       <= 1'b0;
        end
        if (BVALID && BREADY) begin
            AWREADY       <= 1'b1;
            wr_addr_valid <= 1'b0;
        end
    end
end

// ============================================================
// Write data — accept and write to memory
// ============================================================
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        WREADY      <= 1'b1;
        wr_beat_cnt <= '0;
        BVALID      <= 1'b0;
        BRESP       <= 2'b00;
    end else begin
        if (WVALID && WREADY) begin
            // Write to memory — word-addressed using bits [ADDR_WIDTH-1:2]
            if (WSTRB[0]) mem[wr_addr[ADDR_WIDTH-1:2]][7:0]   <= WDATA[7:0];
            if (WSTRB[1]) mem[wr_addr[ADDR_WIDTH-1:2]][15:8]  <= WDATA[15:8];
            if (WSTRB[2]) mem[wr_addr[ADDR_WIDTH-1:2]][23:16] <= WDATA[23:16];
            if (WSTRB[3]) mem[wr_addr[ADDR_WIDTH-1:2]][31:24] <= WDATA[31:24];

            // Advance address for INCR burst
            wr_addr     <= wr_addr + (1 << 2);  // +4 bytes for 32-bit
            wr_beat_cnt <= wr_beat_cnt + 1;

            if (WLAST) begin
                // Last beat — generate write response
                WREADY      <= 1'b0;
                BVALID      <= 1'b1;
                BRESP       <= 2'b00;   // OKAY
                wr_beat_cnt <= '0;
            end
        end
        if (BVALID && BREADY) begin
            BVALID <= 1'b0;
            WREADY <= 1'b1;
        end
    end
end

// ============================================================
// Read address tracking
// ============================================================
logic [ADDR_WIDTH-1:0] rd_addr;
logic [7:0]            rd_len;
logic [7:0]            rd_beat_cnt;

always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        ARREADY     <= 1'b1;
        rd_addr     <= '0;
        rd_len      <= '0;
        rd_beat_cnt <= '0;
        RVALID      <= 1'b0;
        RDATA       <= '0;
        RLAST       <= 1'b0;
        RRESP       <= 2'b00;
    end else begin
        if (ARVALID && ARREADY) begin
            rd_addr     <= ARADDR;
            rd_len      <= ARLEN;
            rd_beat_cnt <= '0;
            ARREADY     <= 1'b0;
            RVALID      <= 1'b1;
            RDATA       <= mem[ARADDR[ADDR_WIDTH-1:2]];
            RLAST       <= (ARLEN == 0);
            RRESP       <= 2'b00;
        end

        if (RVALID && RREADY) begin
            if (RLAST) begin
                // Final beat done
                RVALID  <= 1'b0;
                RLAST   <= 1'b0;
                ARREADY <= 1'b1;
                rd_beat_cnt <= '0;
            end else begin
                // Advance to next read beat
                rd_addr     <= rd_addr + (1 << 2);
                rd_beat_cnt <= rd_beat_cnt + 1;
                RDATA       <= mem[(rd_addr + 4) >> 2];
                RLAST       <= (rd_beat_cnt + 1 == rd_len);
            end
        end
    end
end

endmodule