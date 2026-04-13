// ═══════════════════════════════════════════════════
// UART TX Top Level
// Connects FSM + Datapath + Baud Generator
// This is what you instantiate in your SoC
// ═══════════════════════════════════════════════════

module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 9_600
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] tx_data,    // byte to send
    input  logic       tx_start,   // pulse to start transmission
    output logic       tx_serial,  // UART output wire
    output logic       tx_busy,    // high while sending
    output logic       tx_done     // 1-cycle pulse when done
);

    // ── Internal wires ───────────────────────────────
    logic       baud_tick;
    logic       load, shift_en;
    logic       serial_data, parity_bit;
    logic [2:0] bit_cnt;

    // ── Baud rate generator ──────────────────────────
    baud_gen #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_baud (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick)
    );

    // ── FSM — Control path ───────────────────────────
    uart_tx_fsm u_fsm (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_start   (tx_start),
        .baud_tick  (baud_tick),
        .bit_cnt    (bit_cnt),
        .load       (load),
        .shift_en   (shift_en),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done)
    );

    // ── Datapath — shift register ────────────────────
    uart_tx_datapath u_data (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_data    (tx_data),
        .load       (load),
        .shift_en   (shift_en),
        .serial_out (serial_data),
        .parity_bit (parity_bit),
        .bit_cnt    (bit_cnt)
    );

    // ── TX line mux ──────────────────────────────────
    // Select what goes on the wire based on FSM state
    always_comb begin
        case (u_fsm.present_state)
            uart_tx_fsm::IDLE:   tx_serial = 1'b1;         // idle high
            uart_tx_fsm::START:  tx_serial = 1'b0;         // start bit
            uart_tx_fsm::DATA:   tx_serial = serial_data;  // data bits
            uart_tx_fsm::PARITY: tx_serial = parity_bit;   // parity
            uart_tx_fsm::STOP:   tx_serial = 1'b1;         // stop bit
            default:             tx_serial = 1'b1;         // safe default
        endcase
    end

endmodule