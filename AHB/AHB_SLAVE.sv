// ============================================================
// AHB-Lite Slave — 4 internal 32-bit registers
// Addresses: 0x00, 0x04, 0x08, 0x0C
// Supports wait states via HREADYOUT
// ============================================================

module ahb_lite_slave #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter WAIT_STATES = 1    // Insert this many wait states per access
)(
    input  logic                    HCLK,
    input  logic                    HRESETn,

    // AHB-Lite slave interface
    input  logic                    HSEL,       // This slave is selected
    input  logic                    HREADY,     // Previous transfer done
    input  logic [ADDR_WIDTH-1:0]   HADDR,
    input  logic                    HWRITE,
    input  logic [1:0]              HTRANS,
    input  logic [2:0]              HSIZE,
    input  logic [2:0]              HBURST,
    input  logic [DATA_WIDTH-1:0]   HWDATA,

    output logic                    HREADYOUT,  // This slave's ready signal
    output logic [DATA_WIDTH-1:0]   HRDATA,
    output logic                    HRESP
);

// ============================================================
// HTRANS encoding
// ============================================================
localparam IDLE   = 2'b00;
localparam BUSY   = 2'b01;
localparam NONSEQ = 2'b10;
localparam SEQ    = 2'b11;

// ============================================================
// Register file
// ============================================================
logic [DATA_WIDTH-1:0] regfile [0:3];

// ============================================================
// Address phase registration
// Must capture on rising edge when HREADY=1
// ============================================================
logic [ADDR_WIDTH-1:0] addr_lat;
logic                  write_lat;
logic                  sel_lat;     // Was this slave selected?
logic                  trans_valid; // Was it NONSEQ or SEQ?

always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        addr_lat   <= '0;
        write_lat  <= 1'b0;
        sel_lat    <= 1'b0;
        trans_valid <= 1'b0;
    end else if (HREADY) begin
        // Capture address phase signals when bus is free
        addr_lat    <= HADDR;
        write_lat   <= HWRITE;
        sel_lat     <= HSEL;
        // Valid transfer means this slave was selected with real HTRANS
        trans_valid <= HSEL && (HTRANS == NONSEQ || HTRANS == SEQ);
    end
end

// ============================================================
// Wait state counter
// Controls HREADYOUT during data phase
// ============================================================
logic [3:0] wait_cnt;
logic       data_phase_active;

assign data_phase_active = sel_lat && trans_valid;

always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        wait_cnt   <= '0;
        HREADYOUT  <= 1'b1;
    end else begin
        if (data_phase_active && !HREADYOUT) begin
            // Counting wait states
            if (wait_cnt == WAIT_STATES - 1) begin
                HREADYOUT <= 1'b1;
                wait_cnt  <= '0;
            end else begin
                wait_cnt  <= wait_cnt + 1;
            end
        end else if (data_phase_active && HREADYOUT) begin
            // First cycle of data phase — if wait states needed, lower ready
            if (WAIT_STATES > 0) begin
                HREADYOUT <= 1'b0;
                wait_cnt  <= '0;
            end
        end else begin
            HREADYOUT <= 1'b1;
            wait_cnt  <= '0;
        end
    end
end

// ============================================================
// Write logic — fires when data phase completes (HREADYOUT=1)
// Uses LATCHED address from address phase
// ============================================================
always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        regfile[0] <= '0; regfile[1] <= '0;
        regfile[2] <= '0; regfile[3] <= '0;
    end else begin
        // Write when: transfer was valid, was a write, and data phase is done
        if (data_phase_active && write_lat && HREADYOUT) begin
            case (addr_lat[3:2])
                2'b00: regfile[0] <= HWDATA;
                2'b01: regfile[1] <= HWDATA;
                2'b10: regfile[2] <= HWDATA;
                2'b11: regfile[3] <= HWDATA;
            endcase
        end
    end
end

// ============================================================
// Read logic — combinational, driven from latched address
// ============================================================
always_comb begin
    HRDATA = '0;
    if (data_phase_active && !write_lat) begin
        case (addr_lat[3:2])
            2'b00: HRDATA = regfile[0];
            2'b01: HRDATA = regfile[1];
            2'b10: HRDATA = regfile[2];
            2'b11: HRDATA = regfile[3];
        endcase
    end
end

// No errors in this simple slave
assign HRESP = 1'b0;  // OKAY always

endmodule