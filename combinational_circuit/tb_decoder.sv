module tb_decoder;

logic A,B;
logic Y0,Y1,Y2,Y3;

decoder2to4 dut(A,B,Y0,Y1,Y2,Y3);

initial begin

for(int i=0;i<4;i++)
begin
    {A,B} = i[1:0];
    #1;
    $display("A=%b B=%b | Y0=%b Y1=%b Y2=%b Y3=%b",
              A,B,Y0,Y1,Y2,Y3);
end

$finish;

end

endmodule
endmodule