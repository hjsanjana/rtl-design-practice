module tb_rom;

    logic clk;
    logic [2:0] addr;
    logic [7:0] rdata;

    rom dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        addr = 0;

        repeat (8) begin
            @(posedge clk);
            $display("addr=%0d data=%h", addr, rdata);
            addr = addr + 1;
        end

        $finish;
    end

endmodule