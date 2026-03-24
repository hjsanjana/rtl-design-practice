module encoder4to2(
input  logic D0,D1,D2,D3,
output logic Y1,Y0
);

assign Y1 = D2 | D3;
assign Y0 = D1 | D3;

endmodule