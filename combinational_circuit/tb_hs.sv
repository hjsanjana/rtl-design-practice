module tb_half_subtractor;

logic a,b;
logic diff,borrow;

half_subtractor dut(
    .a(a),
    .b(b),
    .diff(diff),
    .borrow(borrow)
);

initial begin
    for(int i=0;i<4;i++) begin
        {a,b} = i[1:0];
        #1;
        $display("A=%0b B=%0b | diff=%0b borrow=%0b",a,b,diff,borrow);
    end

    $finish;
end

endmodule