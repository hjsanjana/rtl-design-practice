module tb;
logic d;
logic en;
logic q;

d_latch dut(.d(d), .en(en), .q(q));
initial begin 
d=0;

en=0;
#1;
 for (int i=0;i <4 ;i++) begin
  {d,en}=i[1:0];
 #1;
$display("d=%b en=%b q=%b", d, en, q);
end
end
endmodule