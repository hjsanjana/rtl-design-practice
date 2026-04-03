module register #(
    parameter WIDTH = 8        // default 8-bit, changeable
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  logic [WIDTH-1:0] d,    // WIDTH-bit input
    output logic [WIDTH-1:0] q     // WIDTH-bit output
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= '0;       // '0 = fill ALL bits with 0 (any width)
        else if (en)
            q <= d;
    end
endmodule