module tb_encoder;

logic D0,D1,D2,D3;
logic Y1,Y0;

encoder4to2 dut(D0,D1,D2,D3,Y1,Y0);

initial begin

D0=1; D1=0; D2=0; D3=0; #1;
$display("%b%b",Y1,Y0);

D0=0; D1=1; D2=0; D3=0; #1;
$display("%b%b",Y1,Y0);

D0=0; D1=0; D2=1; D3=0; #1;
$display("%b%b",Y1,Y0);

D0=0; D1=0; D2=0; D3=1; #1;
$display("%b%b",Y1,Y0);

$finish;

end

endmodule