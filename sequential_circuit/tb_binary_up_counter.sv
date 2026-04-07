module tb_binary;

    logic        clk, rst_n, en;
    logic [3:0]  count;
    logic        carry;

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT
    binary_up_counter #(.WIDTH(4)) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .en   (en),
        .count(count),
        .carry(carry)
    );

    initial begin
        $display("================================");
        $display("  Binary Up Counter Test");
        $display("================================");
        $display(" dec | binary | carry");
        $display("-----+--------+------");

        // Reset
        rst_n = 0; en = 1;
        #3; rst_n = 1; #2;

        // Count through all 18 values
        // (16 to see full cycle + 2 more to confirm wrap)
        repeat(18) begin
            $display("  %2d | %b  |   %b",
                      count, count, carry);
            @(posedge clk); #1;
        end

        // Test pause (en=0)
        $display("\n--- Pausing counter (en=0) ---");
        en = 0;
        repeat(3) begin
            $display("  %2d | %b  |   %b  (paused)",
                      count, count, carry);
            @(posedge clk); #1;
        end

        $display("\n--- Resuming (en=1) ---");
        en = 1;
        repeat(3) begin
            @(posedge clk); #1;
            $display("  %2d | %b  |   %b",
                      count, count, carry);
        end

        $finish;
    end

endmodule