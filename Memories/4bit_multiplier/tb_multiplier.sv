module tb_multiplier;

    logic [3:0] A, B;
    logic [7:0] P;

    array_multiplier_4bit_struct dut (.*);

    initial begin
        A = 4'b1011; // 11
        B = 4'b0011; // 3

        #10;
        $display("A=%0d B=%0d P=%0d", A, B, P);

        A = 4'b0101; // 5
        B = 4'b0010; // 2

        #10;
        $display("A=%0d B=%0d P=%0d", A, B, P);

        #10 $finish;
    end

endmodule