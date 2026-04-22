// ============================================================
// SPI Slave — Mode 0 (CPOL=0, CPHA=0)
// Samples MOSI on rising SCLK, shifts MISO out on falling SCLK
// ============================================================

module spi_slave (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       sclk,         // SPI clock from master
    input  logic       mosi,         // Data from master
    output logic       miso,         // Data to master
    input  logic       cs_n,         // Chip select, active LOW
    input  logic [7:0] tx_data,      // Byte slave wants to send back
    output logic [7:0] rx_data,      // Byte received from master
    output logic       rx_done       // Pulses when full byte received
);

// ============================================================
// Synchronize sclk and cs_n into our clock domain
// (same 2-flop principle as UART RX)
// ============================================================
logic sclk_s1, sclk_s2, sclk_s3;   // Three flops for edge detect
logic cs_s1,   cs_s2;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sclk_s1 <= 0; sclk_s2 <= 0; sclk_s3 <= 0;
        cs_s1   <= 1; cs_s2   <= 1;
    end else begin
        sclk_s1 <= sclk;
        sclk_s2 <= sclk_s1;
        sclk_s3 <= sclk_s2;
        cs_s1   <= cs_n;
        cs_s2   <= cs_s1;
    end
end

// Edge detection from the synchronized SCLK
// Rising edge: sclk_s2=1 and sclk_s3=0
// Falling edge: sclk_s2=0 and sclk_s3=1
wire sclk_rising  = (sclk_s2 == 1'b1) && (sclk_s3 == 1'b0);
wire sclk_falling = (sclk_s2 == 1'b0) && (sclk_s3 == 1'b1);
wire cs_active    = (cs_s2 == 1'b0);   // CS LOW = selected

// ============================================================
// Shift registers
// ============================================================
logic [7:0] rx_shift;
logic [7:0] tx_shift;
logic [2:0] bit_cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_shift <= 0;
        tx_shift <= 0;
        bit_cnt  <= 0;
        miso     <= 1'b0;
        rx_data  <= 0;
        rx_done  <= 0;
    end else begin
        rx_done <= 1'b0;

        if (!cs_active) begin
            // CS deasserted: reset and preload TX
            bit_cnt  <= 0;
            tx_shift <= tx_data;     // Load byte to send
            miso     <= tx_data[7];  // MSB ready first
        end else begin

            // On rising SCLK: sample MOSI
            if (sclk_rising) begin
                rx_shift <= {rx_shift[6:0], mosi};  // Shift in LSB position
                bit_cnt  <= bit_cnt + 1;
                if (bit_cnt == 7) begin
                    rx_data <= {rx_shift[6:0], mosi};  // Latch full byte
                    rx_done <= 1'b1;
                end
            end

            // On falling SCLK: shift out next MISO bit
            if (sclk_falling) begin
                tx_shift <= {tx_shift[6:0], 1'b0};  // Shift left
                miso     <= tx_shift[6];              // Next bit ready
            end

        end
    end
end

endmodule