module decoder2to4(
    input  logic A,
    input  logic B,
    output logic Y0,
    output logic Y1,
    output logic Y2,
    output logic Y3
);

assign Y0 = ~A & ~B;
assign Y1 = ~A &  B;
assign Y2 =  A & ~B;
assign Y3 =  A &  B;

endmodule