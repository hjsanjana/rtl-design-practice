`timescale 1ns/1ps

module tb_jk_ff;

    logic clk = 0;
    logic rst_n;
    logic j, k;
    logic q;
    logic exp_q;

    jk_ff dut(.*);   // connects clk,rst_n,j,k,q automatically

    // clock
    always #5 clk = ~clk;

    // reference model
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) exp_q <= 0;
        else exp_q <= (j & ~exp_q) | (~k & exp_q);

    // checker
    always @(posedge clk)
        assert(q === exp_q)
        else $error("Mismatch t=%0t q=%0b exp=%0b j=%0b k=%0b",
                     $time,q,exp_q,j,k);

    // stimulus
    initial begin
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;

        repeat (50) begin
            @(posedge clk);
            {j,k} = $urandom_range(0,3); // random JK
        end

        #20 $finish;
    end

endmodule