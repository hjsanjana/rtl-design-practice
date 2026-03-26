module tb_rca4;

    logic [3:0] a;
    logic [3:0] b;
    logic       cin;
    logic [3:0] sum;
    logic       cout;

    // Instantiate DUT
    rca4 dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    logic [4:0] expected;  // 5 bits to hold carry-out

    initial begin
        int errors = 0;

        // Exhaustive test
        for (int c = 0; c < 2; c++) begin
            cin = c;

            for (int i = 0; i < 16; i++) begin
                a = i;

                for (int j = 0; j < 16; j++) begin
                    b = j;

                    #1;  // allow propagation

                    expected = a + b + cin;

                    // Compare using case equality
                    assert ({cout, sum} === expected)
                    else begin
                        errors++;
                        $error("FAIL: a=%0d b=%0d cin=%0b | got=%0b_%0d exp=%0b_%0d",
                               a, b, cin,
                               cout, sum,
                               expected[4], expected[3:0]);
                    end
                end
            end
        end

        if (errors == 0) begin
            $display("=================================");
            $display("PASS: All 512 RCA4 tests passed.");
            $display("=================================");
        end
        else begin
            $display("=================================");
            $display("DONE: %0d errors found.", errors);
            $display("=================================");
        end

        $finish;
    end

endmodule