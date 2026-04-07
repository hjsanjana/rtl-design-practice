
module tb_bcd_counter;

    logic clk;
    logic rst_n;
    logic en;
    logic [3:0] ones;
    logic [3:0] tens;
    logic carry;

    // DUT
    bcd_counter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .ones  (ones),
        .tens  (tens),
        .carry (carry)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Dump waveform
        $dumpfile("bcd_counter.vcd");
        $dumpvars(0, tb_bcd_counter);

        // Init
        rst_n = 0;
        en    = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Enable counting
        en = 1;

        // Run long enough to see multiple rollovers (00 → 99 → 00)
        #1000;

        // Disable counting (hold state)
        en = 0;
        #50;

        // Enable again
        en = 1;
        #200;

        $finish;
    end

endmodule