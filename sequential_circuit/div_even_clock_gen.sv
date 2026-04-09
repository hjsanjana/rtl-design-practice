module div_even #(
    parameter N = 4        // MUST be even!
)(
    input  logic clk,
    input  logic rst_n,
    output logic clk_out   // 50% duty cycle
);
    // Need enough bits to count to N-1
    logic [$clog2(N)-1:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (count == N-1)
            count <= '0;        // wrap at N-1
        else
            count <= count + 1;
    end

    // HIGH for first half, LOW for second half
    assign clk_out = (count < N/2);
    //                ↑
    //    count=0,1 → 0,1 < 2 → HIGH
    //    count=2,3 → 2,3 < 2 → LOW
    //    (for N=4, N/2=2)

endmodule