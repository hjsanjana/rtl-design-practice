module tb;

logic i0,i1,i2,i3,i4,i5,i6,i7;
logic s2,s1,s0;
logic y;

mux8to1 dut(i0,i1,i2,i3,i4,i5,i6,i7,s2,s1,s0,y);

initial begin

for(int i=0;i<2048;i++)
begin
    {i0,i1,i2,i3,i4,i5,i6,i7,s2,s1,s0} = i[10:0];
    #1;
    $display("sel=%b%b%b y=%b",s2,s1,s0,y);
end

$finish;

end

endmodule