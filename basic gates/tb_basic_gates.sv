module tb_basic_gates;

logic a ,b ;
logic y_and, y_or, y_not_a, y_nand, y_nor, y_xor, y_xnor ;
logic_gates uut (
        .a      (a),
        .b      (b),
        .y_and  (y_and),
        .y_or   (y_or),
        .y_not_a(y_not_a),
        .y_nand (y_nand),
        .y_nor  (y_nor),
        .y_xor  (y_xor),
        .y_xnor (y_xnor)
    );
	initial begin
        $display("A B | AND OR NOT_A NAND NOR XOR XNOR");
        $display("----+--------------------------------");

        a=0; b=0; #10;
        $display("%b %b |  %b   %b    %b     %b    %b   %b    %b",
                  a,b,y_and,y_or,y_not_a,y_nand,y_nor,y_xor,y_xnor);

        a=0; b=1; #10;
        $display("%b %b |  %b   %b    %b     %b    %b   %b    %b",
                  a,b,y_and,y_or,y_not_a,y_nand,y_nor,y_xor,y_xnor);

        a=1; b=0; #10;
        $display("%b %b |  %b   %b    %b     %b    %b   %b    %b",
                  a,b,y_and,y_or,y_not_a,y_nand,y_nor,y_xor,y_xnor);

        a=1; b=1; #10;
        $display("%b %b |  %b   %b    %b     %b    %b   %b    %b",
                  a,b,y_and,y_or,y_not_a,y_nand,y_nor,y_xor,y_xnor);

        $finish;
    end
endmodule