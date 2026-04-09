module clk_enable_gen #(
    parameter N = 4    // enable pulses every N cycles
)(
    input  logic clk,
    input  logic rst_n,
    output logic clk_en   // 1-cycle pulse every N cycles
);
    logic [$clog2(N)-1:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else
            count <= (count == N-1) ? '0 : count + 1;
    end

    // Pulse HIGH for exactly 1 cycle when count reaches N-1
    assign clk_en = (count == N-1);

endmodule