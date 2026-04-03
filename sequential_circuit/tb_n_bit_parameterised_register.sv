`timescale 1ns/1ps

module tb_register;

    parameter WIDTH = 8;

    logic clk;
    logic rst_n;
    logic en;
    logic [WIDTH-1:0] d;
    logic [WIDTH-1:0] q;

    logic [WIDTH-1:0] expected_q;

    register #(.WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .d(d),
        .q(q)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            expected_q <= '0;
        else if (en)
            expected_q <= d;
    end

    always @(posedge clk) begin
        #1;
        if (q !== expected_q)
            $error("Mismatch at time %0t: q=%0h expected=%0h", $time, q, expected_q);
    end

    initial begin
        rst_n = 0;
        en    = 0;
        d     = 0;

        #12 rst_n = 1;

        repeat (20) begin
            @(negedge clk);
            en = $urandom_range(0,1);
            d  = $urandom;
        end

        #7 rst_n = 0;
        #10 rst_n = 1;

        repeat (20) begin
            @(negedge clk);
            en = $urandom_range(0,1);
            d  = $urandom;
        end

        #20 $finish;
    end

endmodule