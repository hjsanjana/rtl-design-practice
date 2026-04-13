// ═══════════════════════════════════════════════════
// UART TX Testbench
// Sends 0x55 (01010101) — alternating bits, easy to
// verify on a waveform. Then sends 0xA5 (10100101).
// ═══════════════════════════════════════════════════

module tb_uart_tx;

    // Use fast baud rate for simulation speed
    localparam int CLK_FREQ  = 50_000_000;
    localparam int BAUD_RATE = 5_000_000; // fast for sim: 10 clocks/bit

    logic       clk, rst_n;
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_serial, tx_busy, tx_done;

    // DUT
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (.*);

    // 20ns clock (50 MHz)
    initial clk = 0;
    always  #10 clk = ~clk;

    // Task: send one byte and wait for completion
    task send_byte(input logic [7:0] data);
        @(posedge clk); #1;
        tx_data  = data;
        tx_start = 1'b1;
        @(posedge clk); #1;
        tx_start = 1'b0;

        // Wait for tx_done pulse
        @(posedge tx_done);
        $display("Sent: 0x%02h (%08b) | time=%0t", data, data, $time);
    endtask

    // Monitor the tx_serial line — capture each bit
    // This simulates what a receiver would see
    initial begin
        $display("\n=== UART TX Monitor ===");
        forever begin
            @(posedge dut.u_baud.baud_tick);
            $display("  baud_tick | state=%-6s | tx=%b | bit_cnt=%0d",
                      dut.u_fsm.present_state.name(),
                      tx_serial,
                      dut.u_data.bit_cnt);
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_tx);

        // Reset
        rst_n    = 0;
        tx_data  = 8'h00;
        tx_start = 0;
        repeat(4) @(posedge clk);
        #1 rst_n = 1;

        $display("\n--- Sending 0x55 (01010101) ---");
        send_byte(8'h55);

        // Small gap
        repeat(5) @(posedge clk);

        $display("\n--- Sending 0xA5 (10100101) ---");
        send_byte(8'hA5);

        // Test back-to-back transmission
        $display("\n--- Back-to-back: 0xAA then 0xBB ---");
        fork
            begin
                @(posedge clk); #1;
                tx_data  = 8'hAA;
                tx_start = 1'b1;
                @(posedge clk); #1;
                tx_start = 1'b0;
            end
        join
        @(posedge tx_done);
        $display("First byte done");

        // Immediately queue next byte
        @(posedge clk); #1;
        tx_data  = 8'hBB;
        tx_start = 1'b1;
        @(posedge clk); #1;
        tx_start = 1'b0;
        @(posedge tx_done);
        $display("Second byte done");

        repeat(20) @(posedge clk);
        $display("\n=== Test complete ===");
        $finish;
    end

endmodule
```

### Expected Output Pattern for 0x55

0x55 = `01010101` in binary. UART sends LSB first, so the wire sees:
```
Idle  Start  1  0  1  0  1  0  1  0  Parity  Stop
 1  |  0  |  1| 0| 1| 0| 1| 0| 1| 0|   0   |  1
```

Parity of 0x55: `^8'h55 = ^8'b01010101 = 0^1^0^1^0^1^0^1 = 0` (even number of 1s → parity=0)

---

## The Real-World Connection

Here's how this exact FSM structure appears in real chips:
```
Your UART TX FSM          Real chip equivalent
─────────────────────────────────────────────────────
IDLE → START              APB bus: IDLE → SETUP
DATA (shift 8 bits)       SPI: DATA (shift N bits)
PARITY                    I2C: ACK bit phase
STOP → IDLE               AXI: LAST beat + VALID/READY
baud_gen counter          Clock divider in any serial protocol
shift register            Serializer in PCIe/MIPI/HDMI
bit_cnt                   Burst length counter in AXI
tx_done pulse             Interrupt to CPU when transfer complete