`timescale 1ns/1ps

module tb_t_ff;

    logic clk = 0;
    logic rst_n;
    logic t;
    logic q;
    logic exp_q;

    t_ff dut(.*);

    // clock generation
    always #5 clk = ~clk;

    // reference model
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            exp_q <= 1'b0;
        else
            exp_q <= t ^ exp_q;
    end

    // checker
    always @(posedge clk) begin
        #1;
        assert (q === exp_q)
        else $error("Mismatch at time %0t: q=%0b exp=%0b t_in=%0b",
                    $time, q, exp_q, t);
    end

    // stimulus
    initial begin
        rst_n = 0;
        t     = 0;

        repeat (2) @(posedge clk);
        rst_n = 1;

        repeat (50) begin
            @(negedge clk);
            t = $urandom_range(0,1);
        end

        // async reset during operation
        #7 rst_n = 0;
        #6 rst_n = 1;

        repeat (10) begin
            @(negedge clk);
            t = $urandom_range(0,1);
        end

        #20 $finish;
    end

endmodule