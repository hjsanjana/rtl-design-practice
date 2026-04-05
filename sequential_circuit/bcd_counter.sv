module bcd_counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       en,
    output logic [3:0] ones,
    output logic [3:0] tens,
    output logic       carry    // overflows at 99→00
);
    logic ones_carry;

    // ONES digit: counts 0-9
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ones <= 4'd0;
        else if (en)
            ones <= (ones == 4'd9) ? 4'd0 : ones + 1;
    end

    // ones_carry = 1 when ones is about to wrap (at 9)
    assign ones_carry = (ones == 4'd9) & en;

    // TENS digit: only advances when ones overflows
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tens <= 4'd0;
        else if (ones_carry)   // ← driven by ones overflow!
            tens <= (tens == 4'd9) ? 4'd0 : tens + 1;
    end

    assign carry = (tens == 4'd9) & ones_carry;

endmodule