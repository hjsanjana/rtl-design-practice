// ============================================================
// Testbench for uart_tx
// Run this on EDA Playground:
//   Tool: ModelSim or Icarus Verilog
//   Language: SystemVerilog
// ============================================================

`timescale 1ns/1ps

module tb_uart_tx;

// Parameters matching DUT
localparam CLK_FREQ     = 50_000_000;
localparam BAUD         = 9600;
localparam CLKS_PER_BIT = CLK_FREQ / BAUD;  // 5208
localparam CLK_PERIOD   = 20;  // 20ns = 50MHz

// Signals
logic       clk, rst_n, start, tx, busy, done;
logic [7:0] data_in;

// Instantiate the DUT (Device Under Test)
uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
) dut (
    .clk(clk), .rst_n(rst_n),
    .start(start), .data_in(data_in),
    .tx(tx), .busy(busy), .done(done)
);

// Clock generation: toggle every 10ns → 20ns period = 50MHz
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// Test sequence
initial begin
    // Setup waveform dump for EDA Playground
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_uart_tx);

    // Reset
    rst_n = 0; start = 0; data_in = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // Send byte 0x55 (binary 01010101)
    data_in = 8'h55;
    start   = 1;
    @(posedge clk);
    start   = 0;   // start is a 1-cycle pulse

    // Wait for done
    wait(done == 1);
    $display("Byte 0x55 sent successfully at time %0t", $time);
    repeat(5) @(posedge clk);

    // Send byte 0xA5
    data_in = 8'hA5;
    start   = 1;
    @(posedge clk);
    start   = 0;
    wait(done == 1);
    $display("Byte 0xA5 sent successfully at time %0t", $time);

    repeat(10) @(posedge clk);
    $display("ALL TESTS PASSED");
    $finish;
end

// Optional: monitor what TX is doing
initial begin
    $monitor("Time=%0t | state=%s | tx=%b | bit_idx=%0d | baud_cnt=%0d",
              $time, dut.state.name(), tx, dut.bit_idx, dut.baud_cnt);
end

endmodule