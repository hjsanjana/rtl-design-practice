`timescale 1ns/1ps

module tb_clk_enable_gen;

    parameter N = 4;

    logic clk;
    logic rst_n;
    logic clk_en;

    // DUT
    clk_enable_gen #(.N(N)) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .clk_en (clk_en)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;   // 10ns period

    initial begin
        // Dump waveform
        $dumpfile("clk_enable_gen.vcd");
        $dumpvars(0, tb_clk_enable_gen);

        // Init
        rst_n = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Run for several cycles
        #150;

        // Apply reset again
        rst_n = 0;
        #10;
        rst_n = 1;

        // Run again
        #100;

        $finish;
    end

endmodule