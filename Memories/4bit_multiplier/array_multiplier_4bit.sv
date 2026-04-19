module array_multiplier_4bit_struct (
    input  logic [3:0] A,
    input  logic [3:0] B,
    output logic [7:0] P
);

    logic [3:0] pp0, pp1, pp2, pp3;

    // Partial products
    assign pp0 = A & {4{B[0]}};
    assign pp1 = A & {4{B[1]}};
    assign pp2 = A & {4{B[2]}};
    assign pp3 = A & {4{B[3]}};

    // Add shifted partial products
    assign P = (pp0 << 0) +
               (pp1 << 1) +
               (pp2 << 2) +
               (pp3 << 3);

endmodule