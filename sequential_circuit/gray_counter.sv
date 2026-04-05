odule gray_counter #(
    parameter WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    output logic [WIDTH-1:0] gray_out,
    output logic [WIDTH-1:0] binary_out
);
    // Keep binary counter internally
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) binary_out <= '0;
        else if(en) binary_out <= binary_out + 1;
    end

    // Convert to Gray combinationally (no extra FF needed)
    assign gray_out = binary_out ^ (binary_out >> 1);

endmodule