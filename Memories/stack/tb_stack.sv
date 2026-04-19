module tb_stack;

    logic clk, rst_n;
    logic push, pop;
    logic [7:0] wdata, rdata;
    logic full, empty;

    stack dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        push = 0;
        pop  = 0;

        #10 rst_n = 1;

        // Push values
        repeat (3) begin
            @(posedge clk);
            push = 1;
            wdata = $random;
        end

        push = 0;

        // Pop values
        repeat (3) begin
            @(posedge clk);
            pop = 1;
        end

        pop = 0;

        #20 $finish;
    end

endmodule