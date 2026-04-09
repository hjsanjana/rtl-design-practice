module div_odd #(
    parameter N = 3         // odd number
)(
    input  logic clk,
    input  logic rst_n,
    output logic clk_out    // 50% duty cycle
);
    logic [$clog2(N)-1:0] count;
    logic clk_p;   // posedge-based signal
    logic clk_n;   // negedge-based signal

    // Counter on RISING edge
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= '0;
        else        count <= (count == N-1) ? '0 : count + 1;
    end

    // Signal from RISING edge
    // HIGH for first (N-1)/2 + 1 counts
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) clk_p <= 1'b0;
        else        clk_p <= (count < (N/2));
        // N=3: N/2=1: HIGH when count<1 → only count=0
    end

    // Same signal but sampled on FALLING edge
    // This shifts it by half a clock period
    always_ff @(negedge clk or negedge rst_n) begin
        if (!rst_n) clk_n <= 1'b0;
        else        clk_n <= (count < (N/2));
        // Same logic, different edge → half-cycle shift
    end

    // OR the two signals → 50% duty cycle!
    assign clk_out = clk_p | clk_n;

endmodule