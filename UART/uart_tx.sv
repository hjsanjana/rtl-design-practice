// ============================================================
// UART Transmitter (TX)
// Parameters: CLK_FREQ = 50MHz, BAUD = 9600
// Format: 8 data bits, No parity, 1 stop bit (8N1)
// ============================================================

module uart_tx #(
    parameter CLK_FREQ = 50_000_000,  // Your FPGA clock in Hz
    parameter BAUD     = 9600          // Desired baud rate
)(
    input  logic       clk,        // System clock
    input  logic       rst_n,      // Active-low reset
    input  logic       start,      // Pulse HIGH for 1 cycle to send
    input  logic [7:0] data_in,    // Byte to transmit
    output logic       tx,         // Serial output line
    output logic       busy,       // HIGH while transmitting
    output logic       done        // Pulses HIGH for 1 cycle when done
);

// ============================================================
// Step 1: Calculate how many clocks = 1 bit period
// ============================================================
localparam CLKS_PER_BIT = CLK_FREQ / BAUD;  // = 5208 for 50MHz/9600

// ============================================================
// Step 2: Define our states
// ============================================================
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    START = 2'b01,
    DATA  = 2'b10,
    STOP  = 2'b11
} state_t;

state_t state;

// ============================================================
// Step 3: Internal registers
// ============================================================
logic [12:0] baud_cnt;    // Counts clock cycles per bit (needs 13 bits for 5208)
logic [2:0]  bit_idx;     // Which data bit we're sending (0 to 7)
logic [7:0]  tx_shift;    // Holds the byte being shifted out

// ============================================================
// Step 4: Main FSM
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state    <= IDLE;
        tx       <= 1'b1;    // Idle line is HIGH
        busy     <= 1'b0;
        done     <= 1'b0;
        baud_cnt <= 0;
        bit_idx  <= 0;
        tx_shift <= 0;
    end else begin
        done <= 1'b0;        // Default: done is LOW (only pulses for 1 cycle)

        case (state)

            // --------------------------------------------------
            IDLE: begin
                tx   <= 1'b1;   // Keep line HIGH while idle
                busy <= 1'b0;
                if (start) begin
                    tx_shift <= data_in;   // Latch the data to send
                    baud_cnt <= 0;
                    state    <= START;
                    busy     <= 1'b1;
                end
            end

            // --------------------------------------------------
            START: begin
                tx <= 1'b0;    // Pull line LOW = start bit
                if (baud_cnt == CLKS_PER_BIT - 1) begin
                    baud_cnt <= 0;
                    bit_idx  <= 0;
                    state    <= DATA;
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end

            // --------------------------------------------------
            DATA: begin
                tx <= tx_shift[bit_idx];  // Send LSB first
                if (baud_cnt == CLKS_PER_BIT - 1) begin
                    baud_cnt <= 0;
                    if (bit_idx == 7) begin
                        state <= STOP;    // All 8 bits sent
                    end else begin
                        bit_idx <= bit_idx + 1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end

            // --------------------------------------------------
            STOP: begin
                tx <= 1'b1;    // Stop bit = HIGH
                if (baud_cnt == CLKS_PER_BIT - 1) begin
                    baud_cnt <= 0;
                    done     <= 1'b1;   // Signal: byte sent!
                    state    <= IDLE;
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end

        endcase
    end
end

endmodule