module mux2to1(
    input logic i0,
    input logic i1,
    input logic sel,
    output logic y
);

assign y = sel ? i1 : i0;

endmodule

module mux4to1(
input logic i0,i1,i2,i3,
input logic s1,s0,
output logic y
);

logic y0,y1;

mux2to1 m1(i0,i1,s0,y0);
mux2to1 m2(i2,i3,s0,y1);
mux2to1 m3(y0,y1,s1,y);

endmodule
module mux8to1(
input logic i0,i1,i2,i3,i4,i5,i6,i7,
input logic s2,s1,s0,
output logic y
);

logic y0,y1;

mux4to1 m1(i0,i1,i2,i3,s1,s0,y0);
mux4to1 m2(i4,i5,i6,i7,s1,s0,y1);
mux2to1 m3(y0,y1,s2,y);

endmodule