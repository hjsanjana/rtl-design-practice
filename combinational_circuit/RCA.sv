module full_adder (
    input  logic a, b, cin,
    output logic sum, cout
);
    logic s1, c1, c2;
    assign s1   = a ^ b;
    assign c1   = a & b;
    assign sum  = s1 ^ cin;
    assign c2   = s1 & cin;
    assign cout = c1 | c2;
endmodule



module rca4(
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       cout
);

    logic [4:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : GEN_FA
            full_adder fa (
                .a   (a[i]),
                .b   (b[i]),
                .cin (carry[i]),
                .sum (sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[4];

endmodule