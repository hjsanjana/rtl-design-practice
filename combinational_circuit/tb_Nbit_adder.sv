module tb_adder;

parameter N = 8;

logic [N-1:0] A;
logic [N-1:0] B;
logic Cin;

logic [N-1:0] Sum;
logic Cout;

adder #(N) dut(
    .A(A),
    .B(B),
    .Cin(Cin),
    .Sum(Sum),
    .Cout(Cout)
);

initial begin

$display("A       B       Cin | Cout Sum");
$display("-------------------------------");

for(int i=0;i<10;i++)
begin
    A = $urandom_range(0,(2**N)-1);
    B = $urandom_range(0,(2**N)-1);
    Cin = $urandom_range(0,1);

    #1;

    $display("%b %b %b | %b %b",A,B,Cin,Cout,Sum);
end

$finish;

end

endmodule