module mod_n_counter #(
    parameter N     = 6,          // change this for any modulus!
    parameter WIDTH = $clog2(N)   // auto-calculate bits needed
    // $clog2(6)  = 3  (need 3 bits for values 0-5)
    // $clog2(10) = 4  (need 4 bits for values 0-9)
    // $clog2(16) = 4  (need 4 bits for values 0-15)
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    output logic [WIDTH-1:0] count,
    output logic             tc      // Terminal Count: HIGH at N-1
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (en)
            count <= (count == N-1) ? '0 : count + 1;
    end

    // tc = terminal count = HIGH when we're at the last value
    // Used to chain counters together!
    assign tc = (count == N-1) & en;

endmodule