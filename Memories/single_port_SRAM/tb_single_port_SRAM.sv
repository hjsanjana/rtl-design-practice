module tb_single_port_sram;

    parameter int DATA_WIDTH = 8;
    parameter int DEPTH      = 16;
    parameter int ADDR_WIDTH = 4;

    logic                  clk;
    logic                  we;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;

    single_port_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk   (clk),
        .we    (we),
        .addr  (addr),
        .wdata (wdata),
        .rdata (rdata)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        we    = 0;
        addr  = 0;
        wdata = 0;

        // Write 8'hA5 to address 3
        @(posedge clk);
        we    <= 1;
        addr  <= 4'd3;
        wdata <= 8'hA5;

        // Write 8'h3C to address 5
        @(posedge clk);
        we    <= 1;
        addr  <= 4'd5;
        wdata <= 8'h3C;

        // Read address 3
        @(posedge clk);
        we    <= 0;
        addr  <= 4'd3;

        @(posedge clk);
        $display("Read addr 3 = %h, expected = A5", rdata);

        // Read address 5
        addr <= 4'd5;

        @(posedge clk);
        $display("Read addr 5 = %h, expected = 3C", rdata);

        @(posedge clk);
        $finish;
    end

endmodule