// ============================================================
// APB Slave — 4 internal 32-bit registers
// Addresses: 0x00=REG0, 0x04=REG1, 0x08=REG2, 0x0C=REG3
// Supports wait states — PREADY controlled by internal logic
// ============================================================

module apb_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter WAIT_STATES = 0   // 0 = no wait states, tie PREADY HIGH
)(
    // APB interface
    input  logic                  PCLK,
    input  logic                  PRESETn,    // Active-low reset
    input  logic                  PSEL,
    input  logic                  PENABLE,
    input  logic                  PWRITE,
    input  logic [ADDR_WIDTH-1:0] PADDR,
    input  logic [DATA_WIDTH-1:0] PWDATA,
    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic                  PREADY,
    output logic                  PSLVERR
);

// ============================================================
// Internal registers — the actual peripheral storage
// ============================================================
logic [DATA_WIDTH-1:0] reg_file [0:3];  // 4 x 32-bit registers

// ============================================================
// Wait state counter
// ============================================================
logic [3:0] wait_cnt;
logic       transfer_active;

assign transfer_active = PSEL & PENABLE;

// ============================================================
// PREADY generation
// ============================================================
// If WAIT_STATES=0: PREADY is always HIGH — simplest slave
// If WAIT_STATES>0: PREADY goes HIGH only after wait_cnt expires
// ============================================================
generate
    if (WAIT_STATES == 0) begin : gen_no_wait
        assign PREADY = 1'b1;   // No wait states — always ready
    end else begin : gen_wait
        always_ff @(posedge PCLK or negedge PRESETn) begin
            if (!PRESETn) begin
                wait_cnt <= 0;
                PREADY   <= 1'b0;
            end else begin
                if (transfer_active) begin
                    if (wait_cnt == WAIT_STATES - 1) begin
                        PREADY   <= 1'b1;
                        wait_cnt <= 0;
                    end else begin
                        PREADY   <= 1'b0;
                        wait_cnt <= wait_cnt + 1;
                    end
                end else begin
                    wait_cnt <= 0;
                    PREADY   <= 1'b1;  // Default: ready when idle
                end
            end
        end
    end
endgenerate

// ============================================================
// Write logic
// Capture PWDATA into the addressed register
// Condition: PSEL & PENABLE & PWRITE & PREADY — all four must be true
// ============================================================
always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        reg_file[0] <= 32'h0000_0000;
        reg_file[1] <= 32'h0000_0000;
        reg_file[2] <= 32'h0000_0000;
        reg_file[3] <= 32'h0000_0000;
    end else begin
        if (PSEL & PENABLE & PWRITE & PREADY) begin
            // Decode address — bits [3:2] select register 0-3
            // Byte offset: 0x00→reg0, 0x04→reg1, 0x08→reg2, 0x0C→reg3
            case (PADDR[3:2])
                2'b00: reg_file[0] <= PWDATA;
                2'b01: reg_file[1] <= PWDATA;
                2'b10: reg_file[2] <= PWDATA;
                2'b11: reg_file[3] <= PWDATA;
            endcase
        end
    end
end

// ============================================================
// Read logic — purely combinational, no register needed
// PRDATA must be valid BEFORE the rising edge that ends ACCESS phase
// The master samples PRDATA at the rising edge when PREADY=1
// ============================================================
always_comb begin
    PRDATA  = 32'h0000_0000;  // Default: return zero for unmapped addresses
    PSLVERR = 1'b0;

    if (PSEL & PENABLE & ~PWRITE) begin
        case (PADDR[3:2])
            2'b00: PRDATA = reg_file[0];
            2'b01: PRDATA = reg_file[1];
            2'b10: PRDATA = reg_file[2];
            2'b11: PRDATA = reg_file[3];
        endcase
    end
end

endmodule