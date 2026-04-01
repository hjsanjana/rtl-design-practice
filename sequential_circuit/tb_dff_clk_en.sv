`timescale 1ns/1ps

module tb_dff_en_async_rst;

    logic clk;
    logic rst_n;
    logic en;
    logic d;
    logic q;

    // DUT Instantiation
    dff_en_async_rst dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .d(d),
        .q(q)
    );

    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        $display("Time\tclk rst_n en d q");
        $monitor("%0t\t%b   %b    %b  %b %b", $time, clk, rst_n, en, d, q);

        // Initial values
        rst_n = 0;
        en = 0;
        d = 0;

        // Apply reset
        #12 rst_n = 1;   // release reset

        // Enable OFF → q should not change
        #10 d = 1;
        #10 d = 0;

        // Enable ON → q follows d at clock edge
        #10 en = 1; d = 1;
        #10 d = 0;
        #10 d = 1;

        // Disable enable → q holds previous value
        #10 en = 0; d = 0;
        #10 d = 1;

        // Asynchronous reset during operation
        #7 rst_n = 0;    // immediate reset
        #8 rst_n = 1;    // release reset

        // Enable again
        #10 en = 1; d = 1;
        #10 d = 0;

        #20 $finish;
    end

endmodule