module half_subtractor(
    input  logic a,
    input  logic b,
    output logic diff,
    output logic borrow
);

assign diff   = a ^ b;
assign borrow = (~a) & b;

endmodule