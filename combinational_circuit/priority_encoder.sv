module priority_encoder8to3 (
    input  logic [7:0] i,      // 8 inputs
    output logic [2:0] y,      // 3-bit binary output
    output logic valid         // 1 = valid input, 0 = no input active
);

    always_comb begin
        y     = 3'b000;
        valid = 0;

        casez (i)              // casez allows ? as wildcard!
            8'b1???????: begin y = 3'b111; valid = 1; end  // I7 highest priority
            8'b01??????: begin y = 3'b110; valid = 1; end  // I6
            8'b001?????: begin y = 3'b101; valid = 1; end  // I5
            8'b0001????: begin y = 3'b100; valid = 1; end  // I4
            8'b00001???: begin y = 3'b011; valid = 1; end  // I3
            8'b000001??: begin y = 3'b010; valid = 1; end  // I2
            8'b0000001?: begin y = 3'b001; valid = 1; end  // I1
            8'b00000001: begin y = 3'b000; valid = 1; end  // I0 lowest priority
            default:     begin y = 3'b000; valid = 0; end  // nothing active
        endcase
    end

endmodule
```

### The Magic of `casez` and `?`
```
casez  → special case that treats ? as "don't care"
?      → this bit can be 0 OR 1 — I don't care which!

8'b1??????? means:
   bit 7 = 1      ← I care about this!
   bits 6-0 = ?   ← don't care, could be anything