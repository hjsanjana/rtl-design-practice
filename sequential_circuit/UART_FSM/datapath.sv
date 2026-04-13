// ═══════════════════════════════════════════════════
// UART TX Datapath
// Shift register + bit counter + parity calculator
// ═══════════════════════════════════════════════════

module uart_tx_datapath (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] tx_data,     // byte to transmit
    input  logic       load,        // load tx_data into shift reg
    input  logic       shift_en,    // shift right by 1
    output logic       serial_out,  // current bit to send
    output logic       parity_bit,  // even parity of tx_data
    output logic [2:0] bit_cnt      // which data bit we're on (0-7)
);

    logic [7:0] shift_reg;

    // ── Shift register ───────────────────────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= 8'h00;
        else if (load)
            shift_reg <= tx_data;       // parallel load
        else if (shift_en)
            shift_reg <= {1'b0, shift_reg[7:1]}; // shift right, MSB=0
            // LSB exits first → UART sends LSB first ✓
    end

    // ── Bit counter ──────────────────────────────────
    // Counts 0→7 while in DATA state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 3'd0;
        else if (load)
            bit_cnt <= 3'd0;    // reset on new frame
        else if (shift_en)
            bit_cnt <= bit_cnt + 3'd1; // increment each shift
    end

    // ── Outputs ──────────────────────────────────────
    // serial_out is always the LSB of shift register
    assign serial_out = shift_reg[0];

    // Even parity: XOR all bits of tx_data
    // If result is 0 → even number of 1s → parity=0
    // If result is 1 → odd number of 1s  → parity=1
    assign parity_bit = ^tx_data; // ^ is reduction XOR

endmodule