module demux1to2(
    input  logic d,
    input  logic sel,
    output logic y0,
    output logic y1
);

assign y0 = d & ~sel;
assign y1 = d & sel;

endmodule