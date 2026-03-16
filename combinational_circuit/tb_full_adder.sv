module tb_full_adder;

    // Step 1: Declare signals
    logic a, b, cin;
    logic sum, cout;

    // Step 2: Connect to design
    full_adder uut (
        .a    (a),
        .b    (b),
        .cin  (cin),
        .sum  (sum),
        .cout (cout)
    );

    // Step 3: Test all 8 combinations
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_full_adder);

        $display("A  B  Cin | Sum  Cout");
        $display("----------+----------");

        a=0; b=0; cin=0; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        a=0; b=0; cin=1; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        a=0; b=1; cin=0; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        a=0; b=1; cin=1; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        a=1; b=0; cin=0; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        a=1; b=0; cin=1; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        a=1; b=1; cin=0; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        a=1; b=1; cin=1; #10;
        $display("%b  %b   %b  |  %b     %b", a, b, cin, sum, cout);

        $finish;
    end

endmodule