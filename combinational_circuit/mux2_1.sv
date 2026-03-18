module mux2to1(
    input logic i0,
    input logic i1,
    input logic sel,
    output logic y
);

assign y = sel ? i1 : i0;

endmodule