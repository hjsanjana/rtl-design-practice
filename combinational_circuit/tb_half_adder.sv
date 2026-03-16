module tb_half_adder;
logic a , b;
logic sum , carry;
half_adder uut (
        .a     (a),
        .b     (b),
        .sum   (sum),
        .carry (carry)
    );
initial begin
$display("A  B  | Sum  Carry");
        $display("------+-----------");

        a=0; b=0; #10;
        $display("%b  %b  |  %b     %b", a, b, sum, carry);

        a=0; b=1; #10;
        $display("%b  %b  |  %b     %b", a, b, sum, carry);

        a=1; b=0; #10;
        $display("%b  %b  |  %b     %b", a, b, sum, carry);

        a=1; b=1; #10;
        $display("%b  %b  |  %b     %b", a, b, sum, carry);

        $finish;
    end

endmodule