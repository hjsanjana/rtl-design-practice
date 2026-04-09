`timescale 1ns/1ps

module tb_div_odd;

    parameter N = 3;

    logic clk;
    logic rst_n;
    logic clk_out;

    // DUT
    div_odd #(.N(N)) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .clk_out (clk_out)
    );

    // Input clock
    initial clk = 0;
    always #5 clk = ~clk;   // 10ns period

    initial begin
        // Dump waveform
        $dumpfile("div_odd.vcd");
        $dumpvars(0, tb_div_odd);

        // Init
        rst_n = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Run for some time
        #200;

        // Mid reset
        rst_n = 0;
        #10;
        rst_n = 1;

        // Run again
        #150;

        $finish;
    end

endmodule