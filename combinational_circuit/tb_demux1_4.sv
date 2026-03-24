module tb_demux1to4;

logic d;
logic s1,s0;
logic y0,y1,y2,y3;

demux1to4 dut(d,s1,s0,y0,y1,y2,y3);

initial begin

for(int i=0;i<8;i++)
begin
    {d,s1,s0} = i[2:0];
    #1;
    $display("d=%b s1=%b s0=%b | y0=%b y1=%b y2=%b y3=%b",
              d,s1,s0,y0,y1,y2,y3);
end

$finish;

end

endmodule