module binary_up_counter #(
    parameter WIDTH = 4        // 4-bit = counts 0 to 15
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,       // enable: 1=count, 0=pause
    output logic [WIDTH-1:0] count,
    output logic             carry     // 1 when count is at maximum
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;           // reset → go to 0
        else if (en)
            count <= count + 1;    // add 1 every clock
                                   // auto wraps: 1111+1 = 10000
                                   // but only 4 bits kept → 0000 ✅
    end

    
    assign carry = en & (&count);
  

endmodule
```

### Line by line — what each line means:
```
count <= count + 1
```
- Read current count value
- Add 1 to it
- Store result back at next clock edge
```
&count  (AND reduction)