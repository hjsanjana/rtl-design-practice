module priority_encoder8to3_tb;

    logic [7:0] i;
    logic [2:0] y;
    logic valid;

    priority_encoder8to3 uut (.i(i), .y(y), .valid(valid));

    initial begin
        $display("Input    | Y   | Valid");
        $display("---------|-----|------");

        i = 8'b00000001; #10;   // Only I0 → expect 000
        $display("%b | %b | %b", i, y, valid);

        i = 8'b00000100; #10;   // Only I2 → expect 010
        $display("%b | %b | %b", i, y, valid);

        i = 8'b10000001; #10;   // I7 and I0 both high → I7 wins → expect 111
        $display("%b | %b | %b", i, y, valid);

        i = 8'b00000000; #10;   // Nothing active → valid=0
        $display("%b | %b | %b", i, y, valid);

        $finish;
    end
endmodule
```

---

## 🧠 casez vs case vs casex
```
case  → exact match only, no wildcards
casez → ? means don't care (use this for priority encoders!)
casex → ? and x both mean don't care (avoid — x can hide bugs!)