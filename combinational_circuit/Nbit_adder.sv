module adder #(parameter N = 4)
(
    input  logic [N-1:0] A,
    input  logic [N-1:0] B,
    input  logic Cin,
    output logic [N-1:0] Sum,
    output logic Cout
);

assign {Cout, Sum} = A + B + Cin;

endmodule