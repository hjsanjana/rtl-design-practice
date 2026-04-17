module tb_fifo;

    logic clk, rst_n;
    logic wr_en, rd_en;
    logic [7:0] wdata, rdata;
    logic full, empty;

    fifo dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;

        #10 rst_n = 1;

        // Write 3 values
        repeat (3) begin
            @(posedge clk);
            wr_en = 1;
            wdata = $random;
        end

        wr_en = 0;

        // Read values
        repeat (3) begin
            @(posedge clk);
            rd_en = 1;
        end

        rd_en = 0;

        #20 $finish;
    end

endmodule