module tb_modn;

    logic       clk, rst_n, en;
    logic [2:0] count;    // 3 bits for mod-6
    logic       tc;

    initial clk = 0;
    always #5 clk = ~clk;

    // Mod-6 counter
    mod_n_counter #(.N(6)) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .en   (en),
        .count(count),
        .tc   (tc)
    );

    initial begin
        $display("================================");
        $display("  Mod-6 Counter Test");
        $display("================================");
        $display(" count | tc | note");
        $display("-------+----+-------");

        rst_n=0; en=1;
        #3; rst_n=1; #2;

        // Show 14 cycles to see 2 full loops
        repeat(14) begin
            $display("   %0d   |  %b | %s",
                count, tc,
                tc ? "← WRAPS NEXT!" : "");
            @(posedge clk); #1;
        end

        $finish;
    end

endmodule