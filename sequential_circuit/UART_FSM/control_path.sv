// ═══════════════════════════════════════════════════
// UART TX FSM — Control Path
// 3-block Moore FSM
// Sequences: IDLE → START → DATA → PARITY → STOP
// ═══════════════════════════════════════════════════

module uart_tx_fsm (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tx_start,    // pulse: start sending tx_data
    input  logic       baud_tick,   // from baud generator
    input  logic [2:0] bit_cnt,     // from shift register: which bit
    output logic       load,        // to shift reg: load tx_data now
    output logic       shift_en,    // to shift reg: shift right now
    output logic       tx_busy,     // HIGH while transmitting
    output logic       tx_done      // 1-cycle pulse when frame complete
);

    // ── State declaration ────────────────────────────
    typedef enum logic [2:0] {
        IDLE   = 3'b000,
        START  = 3'b001,
        DATA   = 3'b010,
        PARITY = 3'b011,
        STOP   = 3'b100
    } state_t;

    state_t present_state, next_state;

    // ── BLOCK 1: State register ──────────────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) present_state <= IDLE;
        else        present_state <= next_state;
    end

    // ── BLOCK 2: Next state logic ────────────────────
    always_comb begin
        next_state = present_state; // default: stay

        case (present_state)
            IDLE: begin
                if (tx_start)
                    next_state = START;
            end

            START: begin
                if (baud_tick)
                    next_state = DATA;
            end

            DATA: begin
                // Stay in DATA until all 8 bits sent
                // bit_cnt goes 0→7, leave after bit 7
                if (baud_tick && bit_cnt == 3'd7)
                    next_state = PARITY;
            end

            PARITY: begin
                if (baud_tick)
                    next_state = STOP;
            end

            STOP: begin
                if (baud_tick) begin
                    // Back-to-back: if new data ready, start immediately
                    if (tx_start) next_state = START;
                    else          next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // ── BLOCK 3: Output logic (Moore) ────────────────
    always_comb begin
        // Defaults — all signals inactive
        load     = 1'b0;
        shift_en = 1'b0;
        tx_busy  = 1'b0;
        tx_done  = 1'b0;

        case (present_state)
            IDLE: begin
                tx_busy  = 1'b0;
                // Load shift register the moment we leave IDLE
                // (Mealy: we need tx_start here to load on time)
                load     = tx_start; // ← Mealy for load signal
            end

            START: begin
                tx_busy  = 1'b1;
                // No shifting yet — sending start bit (0)
            end

            DATA: begin
                tx_busy  = 1'b1;
                // Shift one bit right on every baud tick
                shift_en = baud_tick;
            end

            PARITY: begin
                tx_busy  = 1'b1;
            end

            STOP: begin
                tx_busy  = 1'b1;
                // Signal completion as we leave STOP
                tx_done  = baud_tick; // ← Mealy for done pulse
            end

            default: begin
                tx_busy  = 1'b0;
            end
        endcase
    end

endmodule