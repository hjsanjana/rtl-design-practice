`timescale 1ns/1ps

module tb_ring_counter;

    parameter int N = 4;

    logic clk;
    logic rst_n;
    logic [N-1:0] count;

    // DUT
    ring_counter #(.N(N)) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .count (count)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Dump waveform
        $dumpfile("ring_counter.vcd");
        $dumpvars(0, tb_ring_counter);

        // Initialize
        rst_n = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Let it run for several cycles
        #200;

        // Apply reset again (mid-operation)
        rst_n = 0;
        #10;
        rst_n = 1;

        // Run again
        #100;

        $finish;
    end

endmodule