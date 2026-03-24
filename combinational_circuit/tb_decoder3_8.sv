module tb;

logic A,B,C;
logic Y0,Y1,Y2,Y3,Y4,Y5,Y6,Y7;

decoder3to8 dut(A,B,C,Y0,Y1,Y2,Y3,Y4,Y5,Y6,Y7);

initial begin

for(int i=0;i<8;i++)
begin
    {A,B,C} = i[2:0];
    #1;

    $display("A=%b B=%b C=%b | %b %b %b %b %b %b %b %b",
              A,B,C,
              Y0,Y1,Y2,Y3,Y4,Y5,Y6,Y7);
end

$finish;

end

endmodule