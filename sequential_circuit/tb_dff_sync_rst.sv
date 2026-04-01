module tb;

  logic clk;
  logic rst;
  logic d;
  logic q;

  dff_sync_rst dut (
    .clk(clk),
    .rst(rst),
    .d(d),
    .q(q)
  );

  // Clock generation (10 time unit period)
  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;   // start in reset
    d   = 0;

    #10;       // wait one clock edge
    $display("After reset: q=%b (should be 0)", q);

    rst = 0;   // release reset
    d = 1;
    #10;       // next clock edge
    $display("d=1 applied: q=%b (should be 1)", q);

    d = 0;
    #10;
    $display("d=0 applied: q=%b (should be 0)", q);

    // prove synchronous reset (not immediate)
    d = 1;
    rst = 1;   // assert reset between clock edges
    #3;        // before next posedge
    $display("Before clock edge with rst=1: q=%b (should still be old value)", q);

    #7;        // reach clock edge
    $display("After clock edge with rst=1: q=%b (should be 0)", q);

    $finish;
  end

endmodule