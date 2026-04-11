module tb_simple_fsm;
    logic clk, rst_n, start, done, busy;

    // Instantiate your FSM
    simple_fsm dut (.*);

    // Clock: toggles every 5ns → 10ns period = 100MHz
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_simple_fsm);

        // Apply reset
        rst_n = 0; start = 0; done = 0;
        @(posedge clk); #1;
        rst_n = 1;

        // Test: go IDLE → ACTIVE
        @(posedge clk); #1;
        start = 1;
        @(posedge clk); #1;
        start = 0;

        // Stay in ACTIVE for 2 cycles
        @(posedge clk); #1;
        @(posedge clk); #1;

        // Return to IDLE
        done = 1;
        @(posedge clk); #1;
        done = 0;

        @(posedge clk); #1;
        $finish;
    end

    // Print what's happening each clock
    initial begin
        $monitor("Time=%0t | rst_n=%b start=%b done=%b | busy=%b",
                  $time, rst_n, start, done, busy);
    end
endmodule