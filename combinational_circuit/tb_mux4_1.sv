module tb;

logic i0,i1,i2,i3;
logic s1,s0;
logic y;

mux4to1 dut(i0,i1,i2,i3,s1,s0,y);

initial begin

for(int i=0;i<64;i++)
begin
    {i0,i1,i2,i3,s1,s0} = i[5:0];
    #1;
    $display("i0=%b i1=%b i2=%b i3=%b s1=%b s0=%b y=%b",
             i0,i1,i2,i3,s1,s0,y);
end

$finish;

end

endmodule