`timescale 1ns/1ps

module tb_updown_counter;

    parameter int WIDTH = 4;

    logic             clk;
    logic             rst_n;
    logic             en;
    logic             up_dn;
    logic [WIDTH-1:0] count;

    // DUT
    updown_counter #(.WIDTH(WIDTH)) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .up_dn (up_dn),
        .count (count)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Dump waves (for GTKWave / simulator)
        $dumpfile("updown_counter.vcd");
        $dumpvars(0, tb_updown_counter);

        // Initialize
        rst_n = 0;
        en    = 0;
        up_dn = 1;

        // Apply reset
        #12;
        rst_n = 1;

        // Hold (en = 0)
        #20;

        // Count UP
        en    = 1;
        up_dn = 1;
        #50;

        // Count DOWN
        up_dn = 0;
        #50;

        // Disable counting
        en = 0;
        #20;

        // Enable and count UP again
        en    = 1;
        up_dn = 1;
        #40;

        // Finish
        #20;
        $finish;
    end

endmodule