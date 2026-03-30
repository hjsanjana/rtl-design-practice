module dff_async_rst (
    input  logic clk,
    input  logic rst_n,   // active-LOW (n = not/bar)
    input  logic d,
    output logic q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        // rst_n=0 means reset is ON
            q <= 1'b0;     // fires IMMEDIATELY — no clock needed
        else
            q <= d;
    end
endmodule