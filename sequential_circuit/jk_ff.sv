module jk_ff (
    input  logic clk,
    input  logic rst_n,
    input  logic j,
    input  logic k,
    output logic q
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;
    else
        q <= (j & ~q) | (~k & q);
end

endmodule