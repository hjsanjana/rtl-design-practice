// ============================================================
// AHB-Lite Master — single transfer (NONSEQ) read and write
// ============================================================

module ahb_lite_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                    HCLK,
    input  logic                    HRESETn,

    // User interface
    input  logic                    cmd_valid,
    input  logic                    cmd_write,
    input  logic [ADDR_WIDTH-1:0]   cmd_addr,
    input  logic [DATA_WIDTH-1:0]   cmd_wdata,
    output logic [DATA_WIDTH-1:0]   cmd_rdata,
    output logic                    cmd_done,
    output logic                    cmd_err,

    // AHB-Lite master interface
    output logic [ADDR_WIDTH-1:0]   HADDR,
    output logic                    HWRITE,
    output logic [1:0]              HTRANS,
    output logic [2:0]              HSIZE,
    output logic [2:0]              HBURST,
    output logic [DATA_WIDTH-1:0]   HWDATA,
    input  logic [DATA_WIDTH-1:0]   HRDATA,
    input  logic                    HREADY,
    input  logic                    HRESP
);

typedef enum logic [1:0] {
    S_IDLE = 2'b00,
    S_ADDR = 2'b01,   // Address phase
    S_DATA = 2'b10    // Data phase
} state_t;

state_t state;

// Latch command during address phase
logic                  lat_write;
logic [ADDR_WIDTH-1:0] lat_addr;
logic [DATA_WIDTH-1:0] lat_wdata;

always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        state     <= S_IDLE;
        HTRANS    <= 2'b00;  // IDLE
        HADDR     <= '0;
        HWRITE    <= 1'b0;
        HSIZE     <= 3'b010; // Default: word
        HBURST    <= 3'b000; // SINGLE
        HWDATA    <= '0;
        cmd_done  <= 1'b0;
        cmd_err   <= 1'b0;
        cmd_rdata <= '0;
        lat_write <= 1'b0;
        lat_addr  <= '0;
        lat_wdata <= '0;
    end else begin
        cmd_done <= 1'b0;
        cmd_err  <= 1'b0;

        case (state)

            S_IDLE: begin
                HTRANS <= 2'b00;   // IDLE
                if (cmd_valid) begin
                    // Drive address phase immediately
                    HADDR     <= cmd_addr;
                    HWRITE    <= cmd_write;
                    HTRANS    <= 2'b10;    // NONSEQ
                    HSIZE     <= 3'b010;   // Word
                    HBURST    <= 3'b000;   // Single
                    // Latch for data phase
                    lat_write <= cmd_write;
                    lat_addr  <= cmd_addr;
                    lat_wdata <= cmd_wdata;
                    state     <= S_ADDR;
                end
            end

            S_ADDR: begin
                // Wait for HREADY to confirm address phase accepted
                if (HREADY) begin
                    // Address phase complete
                    // Drive IDLE on the bus (single transfer — no more)
                    HTRANS <= 2'b00;  // IDLE
                    // Drive write data if this is a write
                    if (lat_write)
                        HWDATA <= lat_wdata;
                    state <= S_DATA;
                end
                // If HREADY=0: hold address phase signals stable
            end

            S_DATA: begin
                // Wait for data phase to complete
                if (HREADY) begin
                    cmd_done  <= 1'b1;
                    cmd_err   <= HRESP;
                    if (!lat_write)
                        cmd_rdata <= HRDATA;
                    state <= S_IDLE;
                end
                // If HREADY=0: slave is inserting wait states
                // HWDATA must remain stable (already registered)
            end

        endcase
    end
end

endmodule