module tb_mux2_nbit;

    parameter N = 8;

    logic [N-1:0] A;
    logic [N-1:0] B;
    logic         sel;
    logic [N-1:0] Y;

    mux2_nbit #(N) dut (
        .A(A),
        .B(B),
        .sel(sel),
        .Y(Y)
    );

    initial begin
        $display("A        B        sel | Y");
        $display("--------------------------");

        A   = 8'b10101010;
        B   = 8'b01010101;
        sel = 0; #1;
        $display("%b %b  %b  | %b", A, B, sel, Y);

        sel = 1; #1;
        $display("%b %b  %b  | %b", A, B, sel, Y);

        A   = 8'b11110000;
        B   = 8'b00001111;
        sel = 0; #1;
        $display("%b %b  %b  | %b", A, B, sel, Y);

        sel = 1; #1;
        $display("%b %b  %b  | %b", A, B, sel, Y);

        $finish;
    end

endmodule