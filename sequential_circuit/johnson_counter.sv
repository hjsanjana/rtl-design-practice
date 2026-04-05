module johnson_counter #(
    parameter N = 4    // gives 2N=8 states
)(
    input  logic         clk,
    input  logic         rst_n,
    output logic [N-1:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;           // starts at 0000
        else
            count <= {~count[0], count[N-1:1]};
            // ↑ inverted LSB enters MSB (the "twist")
    end
endmodule