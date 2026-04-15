module tb_dual_port_ram;

    parameter int DATA_WIDTH = 8;
    parameter int DEPTH      = 16;
    parameter int ADDR_WIDTH = 4;

    logic clk;

    logic we_a, we_b;
    logic [ADDR_WIDTH-1:0] addr_a, addr_b;
    logic [DATA_WIDTH-1:0] wdata_a, wdata_b;
    logic [DATA_WIDTH-1:0] rdata_a, rdata_b;

    dual_port_ram #(DATA_WIDTH, DEPTH, ADDR_WIDTH) dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0;

        we_a = 0; we_b = 0;
        addr_a = 0; addr_b = 0;
        wdata_a = 0; wdata_b = 0;

        // Write from Port A
        @(posedge clk);
        we_a   <= 1;
        addr_a <= 4'd3;
        wdata_a<= 8'hAA;

        // Read same location from Port B
        @(posedge clk);
        we_a   <= 0;
        we_b   <= 0;
        addr_b <= 4'd3;

        @(posedge clk);
        $display("Port B read = %h", rdata_b);

        // Simultaneous operations
        @(posedge clk);
        we_a   <= 1;
        addr_a <= 4'd5;
        wdata_a<= 8'h55;

        we_b   <= 0;
        addr_b <= 4'd5;

        @(posedge clk);
        $display("Port B read = %h", rdata_b);

        #20 $finish;
    end

endmodule