// ============================================================
// APB Master — initiates single read and write transfers
// ============================================================

module apb_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  PCLK,
    input  logic                  PRESETn,

    // User command interface
    input  logic                  cmd_valid,   // Pulse to start transfer
    input  logic                  cmd_write,   // 1=write, 0=read
    input  logic [ADDR_WIDTH-1:0] cmd_addr,
    input  logic [DATA_WIDTH-1:0] cmd_wdata,
    output logic [DATA_WIDTH-1:0] cmd_rdata,   // Read data result
    output logic                  cmd_done,    // Transfer complete
    output logic                  cmd_err,     // Slave error

    // APB bus outputs
    output logic                  PSEL,
    output logic                  PENABLE,
    output logic                  PWRITE,
    output logic [ADDR_WIDTH-1:0] PADDR,
    output logic [DATA_WIDTH-1:0] PWDATA,

    // APB bus inputs
    input  logic [DATA_WIDTH-1:0] PRDATA,
    input  logic                  PREADY,
    input  logic                  PSLVERR
);

// ============================================================
// State machine
// ============================================================
typedef enum logic [1:0] {
    S_IDLE   = 2'b00,
    S_SETUP  = 2'b01,
    S_ACCESS = 2'b10
} apb_state_t;

apb_state_t state;

// ============================================================
// Latched command registers
// ============================================================
logic                  lat_write;
logic [ADDR_WIDTH-1:0] lat_addr;
logic [DATA_WIDTH-1:0] lat_wdata;

always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        state    <= S_IDLE;
        PSEL     <= 1'b0;
        PENABLE  <= 1'b0;
        PWRITE   <= 1'b0;
        PADDR    <= '0;
        PWDATA   <= '0;
        cmd_done <= 1'b0;
        cmd_err  <= 1'b0;
        cmd_rdata <= '0;
        lat_write <= 1'b0;
        lat_addr  <= '0;
        lat_wdata <= '0;
    end else begin

        cmd_done <= 1'b0;  // Default: pulse signals
        cmd_err  <= 1'b0;

        case (state)

            // ------------------------------------------------
            S_IDLE: begin
                PSEL    <= 1'b0;
                PENABLE <= 1'b0;
                if (cmd_valid) begin
                    // Latch the command
                    lat_write <= cmd_write;
                    lat_addr  <= cmd_addr;
                    lat_wdata <= cmd_wdata;
                    // Drive SETUP phase signals
                    PSEL    <= 1'b1;
                    PENABLE <= 1'b0;
                    PWRITE  <= cmd_write;
                    PADDR   <= cmd_addr;
                    PWDATA  <= cmd_wdata;
                    state   <= S_SETUP;
                end
            end

            // ------------------------------------------------
            // SETUP phase: PSEL=1, PENABLE=0, signals stable
            // Always exactly 1 cycle
            S_SETUP: begin
                PENABLE <= 1'b1;   // Raise PENABLE — ACCESS phase begins
                state   <= S_ACCESS;
            end

            // ------------------------------------------------
            // ACCESS phase: wait for PREADY from slave
            S_ACCESS: begin
                if (PREADY) begin
                    // Transfer complete
                    PSEL    <= 1'b0;
                    PENABLE <= 1'b0;
                    cmd_done <= 1'b1;
                    cmd_err  <= PSLVERR;
                    if (!lat_write) begin
                        cmd_rdata <= PRDATA;   // Capture read data
                    end
                    state <= S_IDLE;
                end
                // If PREADY=0: hold everything, wait in ACCESS state
                // No action needed — signals stay stable naturally
            end

        endcase
    end
end

endmodule