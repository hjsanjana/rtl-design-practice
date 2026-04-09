module updown_counter #(
    parameter WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  logic             up_dn,    // 1=count up, 0=count down
    output logic [WIDTH-1:0] count
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (en) begin
            if (up_dn)
                count <= count + 1;   // go up
            else
                count <= count - 1;   // go down
                // 0 - 1 = 1111 (underflow wraps automatically)
        end
    end

endmodule

