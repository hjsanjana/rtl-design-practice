// ═══════════════════════════════════════════════════
// Baud Rate Generator
// Produces one baud_tick pulse per bit period
// clk_freq / baud_rate = clocks per bit
// ═══════════════════════════════════════════════════

module baud_gen #(
    parameter int CLK_FREQ  = 50_000_000,  // 50 MHz system clock
    parameter int BAUD_RATE = 9_600        // 9600 baud
)(
    input  logic clk,
    input  logic rst_n,
    output logic baud_tick   // 1-cycle pulse every bit period
);

    // How many system clocks fit in one bit period
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // = 5208

    // Counter width: need to count up to CLKS_PER_BIT
    localparam int CNT_WIDTH = $clog2(CLKS_PER_BIT);    // = 13 bits

    logic [CNT_WIDTH-1:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count      <= '0;
            baud_tick  <= 1'b0;
        end
        else if (count == CNT_WIDTH'(CLKS_PER_BIT - 1)) begin
            count      <= '0;
            baud_tick  <= 1'b1;   // pulse for exactly 1 system clock
        end
        else begin
            count      <= count + 1'b1;
            baud_tick  <= 1'b0;
        end
    end

endmodule