module dff_basic (
    input  logic clk,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk) begin
        q <= d;    // Sample D only at rising clock edge
    end
endmodule