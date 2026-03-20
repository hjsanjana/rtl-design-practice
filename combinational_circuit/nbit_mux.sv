module mux2_nbit #(parameter N = 8)
(
    input  logic [N-1:0] A,
    input  logic [N-1:0] B,
    input  logic         sel,
    output logic [N-1:0] Y
);

    assign Y = sel ? B : A;

endmodule