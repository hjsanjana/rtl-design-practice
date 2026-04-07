`timescale 1ns/1ps

module tb_gray_counter;

    parameter WIDTH = 4;

    logic clk;
    logic rst_n;
    logic en;
    logic [WIDTH-1:0] gray_out;
    logic [WIDTH-1:0] binary_out;

    // DUT
    gray_counter #(.WIDTH(WIDTH)) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .en         (en),
        .gray_out   (gray_out),
        .binary_out (binary_out)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Dump waveform
        $dumpfile("gray_counter.vcd");
        $dumpvars(0, tb_gray_counter);

        // Init
        rst_n = 0;
        en    = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Enable counting
        en = 1;
        #150;

        // Disable (hold state)
        en = 0;
        #40;

        // Enable again
        en = 1;
        #100;

        $finish;
    end

endmodule