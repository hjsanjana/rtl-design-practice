// ============================================================
// Testbench for uart_top (loopback)
// Sends multiple bytes, checks pass/fail each time
// ============================================================

`timescale 1ns/1ps

module tb_uart_top;

localparam CLK_FREQ = 50_000_000;
localparam BAUD     = 9600;
localparam CLK_PER  = 20;  // 50 MHz

logic       clk, rst_n, send;
logic [7:0] data_in;
logic       pass, fail, busy;

// Instantiate top-level
uart_top #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .send    (send),
    .data_in (data_in),
    .pass    (pass),
    .fail    (fail),
    .busy    (busy)
);

// Clock
initial clk = 0;
always #(CLK_PER/2) clk = ~clk;

// ============================================================
// Task: send a byte and wait for result
// ============================================================
task automatic send_and_check(input [7:0] byte_val);
    begin
        // Wait until not busy
        @(posedge clk);
        while (busy) @(posedge clk);

        // Drive send pulse
        data_in = byte_val;
        send    = 1'b1;
        @(posedge clk);
        send = 1'b0;

        // Wait for pass or fail
        fork
            begin
                wait(pass);
                $display("PASS: sent 0x%0h, received 0x%0h — match at time %0t",
                          byte_val, dut.rx_data, $time);
            end
            begin
                wait(fail);
                $display("FAIL: sent 0x%0h, received 0x%0h at time %0t",
                          byte_val, dut.rx_data, $time);
            end
        join_any
        disable fork;

        // Small gap between tests
        repeat(20) @(posedge clk);
    end
endtask

// ============================================================
// Test sequence
// ============================================================
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_uart_top);

    // Reset
    rst_n   = 0;
    send    = 0;
    data_in = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);

    // Test a range of bytes
    send_and_check(8'h00);   // All zeros
    send_and_check(8'hFF);   // All ones
    send_and_check(8'h55);   // Alternating 01010101
    send_and_check(8'hAA);   // Alternating 10101010
    send_and_check(8'hA5);   // Random pattern
    send_and_check(8'h37);   // Another pattern

    $display("==============================");
    $display("All loopback tests complete");
    $display("==============================");
    $finish;
end

endmodule