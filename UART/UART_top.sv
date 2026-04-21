// ============================================================
// UART Top-Level with Loopback
// Contains: uart_tx, uart_rx, controller FSM
// The tx output is wired directly to rx input (loopback)
// ============================================================

module uart_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 9600
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       send,          // Pulse HIGH to send a byte
    input  logic [7:0] data_in,       // Byte to send
    output logic       pass,          // HIGH when loopback matched correctly
    output logic       fail,          // HIGH when data mismatch or frame error
    output logic       busy           // HIGH while a transaction is in progress
);

// ============================================================
// Internal wires connecting the submodules
// ============================================================
logic        tx_serial;      // The serial wire: TX output → RX input
logic        tx_done;        // TX signals it finished sending
logic        rx_done;        // RX signals a byte has been received
logic        frame_err;      // RX detected a framing error
logic        tx_start;       // Controller tells TX to begin
logic [7:0]  tx_data;        // Byte being sent (latched from data_in)
logic [7:0]  rx_data;        // Byte received by RX
logic        tx_busy;        // TX is currently busy

// ============================================================
// The loopback connection — this single line is the whole point
// ============================================================
// In a real system this would be an off-chip wire.
// In loopback mode we connect tx directly back to rx.
wire rx_serial = tx_serial;

// ============================================================
// Submodule instantiation: uart_tx
// ============================================================
uart_tx #(
    .CLK_FREQ (CLK_FREQ),
    .BAUD     (BAUD)
) u_tx (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (tx_start),
    .data_in  (tx_data),
    .tx       (tx_serial),
    .busy     (tx_busy),
    .done     (tx_done)
);

// ============================================================
// Submodule instantiation: uart_rx
// ============================================================
uart_rx #(
    .CLK_FREQ (CLK_FREQ),
    .BAUD     (BAUD)
) u_rx (
    .clk      (clk),
    .rst_n    (rst_n),
    .rx       (rx_serial),
    .rx_data  (rx_data),
    .rx_done  (rx_done),
    .frame_err(frame_err)
);

// ============================================================
// Controller FSM
// ============================================================
typedef enum logic [2:0] {
    S_IDLE     = 3'b000,
    S_SENDING  = 3'b001,
    S_WAITING  = 3'b010,
    S_CHECKING = 3'b011,
    S_PASS     = 3'b100,
    S_FAIL     = 3'b101
} ctrl_state_t;

ctrl_state_t ctrl_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ctrl_state <= S_IDLE;
        tx_start   <= 1'b0;
        tx_data    <= 8'h00;
        pass       <= 1'b0;
        fail       <= 1'b0;
        busy       <= 1'b0;
    end else begin

        // Default: clear pulse signals each cycle
        tx_start <= 1'b0;
        pass     <= 1'b0;
        fail     <= 1'b0;

        case (ctrl_state)

            // --------------------------------------------------
            S_IDLE: begin
                busy <= 1'b0;
                if (send) begin
                    tx_data    <= data_in;   // Latch byte to send
                    tx_start   <= 1'b1;      // Tell TX to start (1-cycle pulse)
                    busy       <= 1'b1;
                    ctrl_state <= S_SENDING;
                end
            end

            // --------------------------------------------------
            // Wait for TX to finish transmitting
            S_SENDING: begin
                busy <= 1'b1;
                if (tx_done)
                    ctrl_state <= S_WAITING;
            end

            // --------------------------------------------------
            // Wait for RX to finish receiving
            // (TX is done, but RX is still receiving the last bits)
            S_WAITING: begin
                busy <= 1'b1;
                if (rx_done || frame_err)
                    ctrl_state <= S_CHECKING;
            end

            // --------------------------------------------------
            // Compare what was sent vs what was received
            S_CHECKING: begin
                busy <= 1'b1;
                if (frame_err) begin
                    ctrl_state <= S_FAIL;
                end else if (rx_data == tx_data) begin
                    ctrl_state <= S_PASS;
                end else begin
                    ctrl_state <= S_FAIL;
                end
            end

            // --------------------------------------------------
            S_PASS: begin
                pass       <= 1'b1;
                busy       <= 1'b0;
                ctrl_state <= S_IDLE;
            end

            // --------------------------------------------------
            S_FAIL: begin
                fail       <= 1'b1;
                busy       <= 1'b0;
                ctrl_state <= S_IDLE;
            end

        endcase
    end
end

endmodule