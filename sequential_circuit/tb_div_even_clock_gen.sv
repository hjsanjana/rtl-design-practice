`timescale 1ns/1ps

module tb_div_even;

    parameter N = 4;

    logic clk;
    logic rst_n;
    logic clk_out;

    // DUT
    div_even #(.N(N)) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .clk_out (clk_out)
    );

    // Input clock (fast clock)
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz → period = 10ns

    initial begin
        // Dump waveform
        $dumpfile("div_even.vcd");
        $dumpvars(0, tb_div_even);

        // Init
        rst_n = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Run for a while
        #200;

        // Apply reset again
        rst_n = 0;
        #10;
        rst_n = 1;

        // Run again
        #150;

        $finish;
    end

endmodule