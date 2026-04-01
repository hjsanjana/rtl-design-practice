module tb;

logic clk;
logic d;
logic q;

dff dut (
    .clk(clk),
    .d(d),
    .q(q)
);

// clock generation
initial clk = 0;
always #5 clk = ~clk;

initial begin
    $display("time clk d q");
    $monitor("%0t   %b   %b %b", $time, clk, d, q);

    d = 0;   // before first posedge
    #7;

    d = 1;   // before next posedge
    #10;

    d = 0;   // before next posedge
    #10;

    d = 1;
    #10;

    $finish;
end

endmodule