module tb;

logic i0;
logic i1;
logic sel;
logic y;

mux2to1 dut(i0,i1,sel,y);

initial begin

for(int i=0;i<8;i++)
begin
    {i0,i1,sel} = i[2:0];
    #1;
    $display("i0=%b i1=%b sel=%b y=%b",i0,i1,sel,y);
end

$finish;

end

endmodule