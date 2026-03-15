module full_adder(
input logic a , b ,cin , 
output logic  sum ,cout);
logic  s1,c1,c2;
assign s1=a ^ b;
assign c1= a & b;
assign sum = s1 ^ cin;
assign c2 = cin & s1;
assign cout = c1 | c2;
endmodule
