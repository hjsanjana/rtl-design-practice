module ring_counter #(
    parameter N = 4
)(
    input  logic         clk,
    input  logic         rst_n,
    output logic [N-1:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= {{(N-1){1'b0}}, 1'b1};
            // reset = 000...001 (single 1 at LSB)
        else
            count <= {count[0], count[N-1:1]};
            // rotate right: LSB goes to MSB
    end
endmodule