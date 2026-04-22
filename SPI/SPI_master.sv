// ============================================================
// SPI Master — Mode 0 (CPOL=0, CPHA=0)
// Sends and receives 8 bits simultaneously (full duplex)
// SCLK frequency = clk / (2 * CLK_DIV)
// ============================================================

module spi_master #(
    parameter CLK_DIV = 4    // SCLK = system_clk / (2 * CLK_DIV)
                              // e.g. 50MHz / 8 = 6.25 MHz SCLK
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,        // Pulse to begin transfer
    input  logic [7:0] mosi_data,    // Byte to send to slave
    output logic [7:0] miso_data,    // Byte received from slave
    output logic       sclk,         // SPI clock to slave
    output logic       mosi,         // Master out slave in
    input  logic       miso,         // Master in slave out
    output logic       cs_n,         // Chip select, active LOW
    output logic       done          // Pulses HIGH when transfer complete
);

// ============================================================
// State definition
// ============================================================
typedef enum logic [2:0] {
    IDLE     = 3'd0,
    CS_LOW   = 3'd1,
    CLK_LO   = 3'd2,
    CLK_HI   = 3'd3,
    CS_HIGH  = 3'd4
} state_t;

state_t state;

// ============================================================
// Internal registers
// ============================================================
logic [7:0]  tx_shift;    // Byte being shifted out on MOSI
logic [7:0]  rx_shift;    // Byte being shifted in from MISO
logic [2:0]  bit_cnt;     // Which bit we are on (0–7)
logic [3:0]  clk_cnt;     // Counts CLK_DIV cycles for half-period

// ============================================================
// Main FSM
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state    <= IDLE;
        sclk     <= 1'b0;    // CPOL=0: idle LOW
        cs_n     <= 1'b1;    // CS idle HIGH (deselected)
        mosi     <= 1'b0;
        done     <= 1'b0;
        bit_cnt  <= 0;
        clk_cnt  <= 0;
        tx_shift <= 0;
        rx_shift <= 0;
        miso_data <= 0;
    end else begin

        done <= 1'b0;   // Default: pulse signal

        case (state)

            // ------------------------------------------------
            IDLE: begin
                sclk    <= 1'b0;
                cs_n    <= 1'b1;
                bit_cnt <= 0;
                clk_cnt <= 0;
                if (start) begin
                    tx_shift <= mosi_data;   // Latch data to send
                    state    <= CS_LOW;
                end
            end

            // ------------------------------------------------
            // Assert CS, wait one CLK_DIV period before SCLK
            CS_LOW: begin
                cs_n <= 1'b0;
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    // Put MSB on MOSI before first rising edge
                    mosi  <= tx_shift[7];
                    state <= CLK_LO;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end

            // ------------------------------------------------
            // SCLK LOW half: hold MOSI data, count half period
            CLK_LO: begin
                sclk <= 1'b0;
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    sclk    <= 1'b1;   // Rising edge — will be seen next cycle
                    state   <= CLK_HI;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end

            // ------------------------------------------------
            // SCLK HIGH half: sample MISO, shift TX, count half period
            CLK_HI: begin
                sclk <= 1'b1;
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    // Sample MISO into shift register (MSB first)
                    rx_shift <= {rx_shift[6:0], miso};

                    if (bit_cnt == 7) begin
                        // All 8 bits done
                        state <= CS_HIGH;
                    end else begin
                        // Prepare next MOSI bit, go back to CLK_LO
                        bit_cnt  <= bit_cnt + 1;
                        tx_shift <= {tx_shift[6:0], 1'b0};  // Shift left
                        mosi     <= tx_shift[6];  // Next MSB
                        sclk     <= 1'b0;
                        state    <= CLK_LO;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end

            // ------------------------------------------------
            // Deassert CS, signal done
            CS_HIGH: begin
                sclk      <= 1'b0;
                cs_n      <= 1'b1;
                miso_data <= rx_shift;   // Latch received byte
                done      <= 1'b1;
                state     <= IDLE;
            end

        endcase
    end
end

endmodule