// ============================================================
// UART Receiver (RX)
// Parameters: CLK_FREQ = 50MHz, BAUD = 9600
// Format: 8N1 — 8 data bits, No parity, 1 stop bit
// ============================================================

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 9600
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,          // Raw serial input — unsynchronized
    output logic [7:0] rx_data,     // Received byte — valid when rx_done=1
    output logic       rx_done,     // Pulses HIGH for 1 cycle when byte ready
    output logic       frame_err    // Pulses HIGH if stop bit is wrong
);

// =====================ac=======================================
// Baud rate constant
// ============================================================
localparam CLKS_PER_BIT  = CLK_FREQ / BAUD;        // 5208
localparam HALF_BIT      = CLKS_PER_BIT / 2;        // 2604

// ============================================================
// State definition
// ============================================================
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    START = 2'b01,
    DATA  = 2'b10,
    STOP  = 2'b11
} state_t;

state_t state;

// ============================================================
// Internal signals
// ============================================================
logic       rx_s1, rx_sync;     // Two-flop synchronizer outputs
logic [12:0] baud_cnt;          // Clock cycle counter within each bit
logic [2:0]  bit_cnt;           // Which bit we are receiving (0-7)
logic [7:0]  rx_shift;          // Shift register — builds the byte

// ============================================================
// Two-flop synchronizer — ALWAYS do this first on any async input
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_s1   <= 1'b1;   // Default HIGH = idle line
        rx_sync <= 1'b1;
    end else begin
        rx_s1   <= rx;
        rx_sync <= rx_s1;
    end
end

// ============================================================
// Main RX FSM
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state     <= IDLE;
        baud_cnt  <= 0;
        bit_cnt   <= 0;
        rx_shift  <= 0;
        rx_data   <= 0;
        rx_done   <= 0;
        frame_err <= 0;
    end else begin

        // Default pulse signals to 0 each cycle
        rx_done   <= 1'b0;
        frame_err <= 1'b0;

        case (state)

            // ------------------------------------------------
            IDLE: begin
                baud_cnt <= 0;
                bit_cnt  <= 0;
                // Wait for falling edge — start bit begins
                if (rx_sync == 1'b0)
                    state <= START;
            end

            // ------------------------------------------------
            START: begin
                // Wait half a bit period to reach bit center
                if (baud_cnt == HALF_BIT - 1) begin
                    baud_cnt <= 0;
                    // Confirm this is a real start bit, not a glitch
                    if (rx_sync == 1'b0)
                        state <= DATA;
                    else
                        state <= IDLE;  // Was noise — go back
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end

            // ------------------------------------------------
            DATA: begin
                // Wait one full bit period, then sample in the middle
                if (baud_cnt == CLKS_PER_BIT - 1) begin
                    baud_cnt <= 0;
                    // Shift the bit into the register — LSB first
                    // rx_sync goes into bit 7, shift right
                    // After 8 bits, bit 0 will hold D0 (first bit received)
                    rx_shift <= {rx_sync, rx_shift[7:1]};

                    if (bit_cnt == 7) begin
                        bit_cnt <= 0;
                        state   <= STOP;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end

            // ------------------------------------------------
            STOP: begin
                // Wait one full bit period for the stop bit
                if (baud_cnt == CLKS_PER_BIT - 1) begin
                    baud_cnt <= 0;
                    state    <= IDLE;

                    if (rx_sync == 1'b1) begin
                        // Stop bit confirmed HIGH — valid frame
                        rx_data <= rx_shift;   // Latch the received byte
                        rx_done <= 1'b1;        // Signal data is ready
                    end else begin
                        // Stop bit is LOW — something went wrong
                        frame_err <= 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end

        endcase
    end
end

endmodule