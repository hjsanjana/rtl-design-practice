
module tb_dff_async_rst;

    logic clk;
    logic rst_n;
    logic d;
    logic q;

    // Instantiate DUT
    dff_async_rst dut (
        .clk(clk),
        .rst_n(rst_n),
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
        $display("Time\tclk rst_n d q");
        $monitor("%0t\t%b   %b    %b %b", $time, clk, rst_n, d, q);

        // Initial values
        rst_n = 0;  
        d = 0;

        // Hold reset for some time
        #12;
        rst_n = 1;   // release reset

        // Apply inputs
        #10 d = 1;
        #10 d = 0;
        #10 d = 1;

        // Assert async reset in middle of operation
        #7 rst_n = 0;   // reset immediately
        #5 rst_n = 1;   // release reset

        #20 d = 0;
        #10 d = 1;

        #20 $finish;
    end

endmodule