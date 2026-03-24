module tb_demux1to2;

logic d;
logic sel;
logic y0,y1;

demux1to2 dut(d,sel,y0,y1);

initial begin

for(int i=0;i<4;i++)
begin
    {d,sel} = i[1:0];
    #1;
    $display("d=%b sel=%b y0=%b y1=%b",d,sel,y0,y1);
end

$finish;

end

endmodule