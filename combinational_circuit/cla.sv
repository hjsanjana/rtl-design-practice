module cla4 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       cout
);

    logic [3:0] P, G;
    logic [4:0] C;

    assign P = a ^ b;     // propagate
    assign G = a & b;     // generate

    assign C[0] = cin;

    // Carry lookahead equations
    assign C[1] = G[0] | (P[0] & C[0]);

    assign C[2] = G[1] 
                | (P[1] & G[0]) 
                | (P[1] & P[0] & C[0]);

    assign C[3] = G[2] 
                | (P[2] & G[1]) 
                | (P[2] & P[1] & G[0]) 
                | (P[2] & P[1] & P[0] & C[0]);

    assign C[4] = G[3] 
                | (P[3] & G[2]) 
                | (P[3] & P[2] & G[1]) 
                | (P[3] & P[2] & P[1] & G[0]) 
                | (P[3] & P[2] & P[1] & P[0] & C[0]);

    // Sum bits
    assign sum  = P ^ C[3:0];
    assign cout = C[4];

endmodule