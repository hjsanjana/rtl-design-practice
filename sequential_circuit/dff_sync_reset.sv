module dff_sync_rst (
    input  logic clk,
    input  logic rst,     // active-HIGH, synchronous
    input  logic d,
    output logic q
);
    always_ff @(posedge clk) begin
        if (rst)           // checked INSIDE block — needs clock edge
            q <= 1'b0;     // reset to 0 AT clock edge
        else
            q <= d;        // normal capture
    end
endmodule