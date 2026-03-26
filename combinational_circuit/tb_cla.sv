module tb_cla4;

    logic [3:0] a, b;
    logic       cin;
    logic [3:0] sum;
    logic       cout;

    cla4 dut (
        .a(a), .b(b), .cin(cin),
        .sum(sum), .cout(cout)
    );

    logic [4:0] expected;
    int errors = 0;

    initial begin
        for (int c = 0; c < 2; c++) begin
            cin = c;

            for (int i = 0; i < 16; i++) begin
                a = i[3:0];

                for (int j = 0; j < 16; j++) begin
                    b = j[3:0];

                    #1;

                    expected = {1'b0, a} + {1'b0, b} + cin;

                    if ({cout, sum} !== expected) begin
                        errors++;
                        $error("FAIL: a=%h b=%h cin=%b | got=%b exp=%b",
                               a, b, cin, {cout, sum}, expected);
                    end
                end
            end
        end

        if (errors == 0) $display("PASS: CLA4 verified (512/512).");
        else             $display("FAIL: %0d mismatches.", errors);

        $finish;
    end

endmodule