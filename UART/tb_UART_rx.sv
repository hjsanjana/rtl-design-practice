// ============================================================
// Testbench for uart_rx
// We manually drive a UART frame on the rx input line
// ============================================================

`timescale 1ns/1ps

module tb_uart_rx;

localparam CLK_FREQ     = 50_000_000;
localparam BAUD         = 9600;
localparam CLKS_PER_BIT = CLK_FREQ / BAUD;   // 5208
localparam CLK_PERIOD   = 20;                 // 50 MHz

logic       clk, rst_n, rx;
logic [7:0] rx_data;
logic       rx_done, frame_err;

// Instantiate DUT
uart_rx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
) dut (
    .clk(clk), .rst_n(rst_n),
    .rx(rx),
    .rx_data(rx_data),
    .rx_done(rx_done),
    .frame_err(frame_err)
);

// Clock
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// Task: send one UART byte on the rx line
// This mimics exactly what a real transmitter does
task send_uart_byte(input [7:0] data);
    integer i;
    begin
        // Start bit
        rx = 0;
        repeat(CLKS_PER_BIT) @(posedge clk);

        // Data bits — LSB first
        for (i = 0; i < 8; i++) begin
            rx = data[i];
            repeat(CLKS_PER_BIT) @(posedge clk);
        end

        // Stop bit
        rx = 1;
        repeat(CLKS_PER_BIT) @(posedge clk);
    end
endtask

// Test sequence
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_uart_rx);

    // Initialize
    rx    = 1;    // Idle line HIGH
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);

    // Test 1: Send 0x37 and check we receive 0x37
    $display("Sending 0x37...");
    send_uart_byte(8'h37);
    wait(rx_done);
    if (rx_data == 8'h37)
        $display("PASS: received 0x%0h", rx_data);
    else
        $display("FAIL: expected 0x37, got 0x%0h", rx_data);

    repeat(20) @(posedge clk);

    // Test 2: Send 0xAB
    $display("Sending 0xAB...");
    send_uart_byte(8'hAB);
    wait(rx_done);
    if (rx_data == 8'hAB)
        $display("PASS: received 0x%0h", rx_data);
    else
        $display("FAIL: expected 0xAB, got 0x%0h", rx_data);

    repeat(20) @(posedge clk);

    // Test 3: Framing error — send wrong stop bit
    $display("Testing framing error...");
    rx = 0; repeat(CLKS_PER_BIT) @(posedge clk);  // start
    repeat(8) begin
        rx = 1; repeat(CLKS_PER_BIT) @(posedge clk);
    end
    rx = 0; repeat(CLKS_PER_BIT) @(posedge clk);  // wrong stop bit!
    rx = 1;
    wait(frame_err);
    $display("PASS: framing error detected correctly");

    repeat(20) @(posedge clk);
    $display("ALL TESTS DONE");
    $finish;
end

endmodule