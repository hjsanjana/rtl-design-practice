module booth_multiplier_4bit (
    input  logic signed [3:0] A,
    input  logic signed [3:0] B,
    output logic signed [7:0] P
);

    logic signed [7:0] ACC;
    logic signed [3:0] Q;
    logic Q_1;
    logic signed [7:0] M;

    integer i;

    always_comb begin
        ACC = 0;
        Q   = B;
        Q_1 = 0;
        M   = A;

        for (i = 0; i < 4; i++) begin
            case ({Q[0], Q_1})
                2'b01: ACC = ACC + M;
                2'b10: ACC = ACC - M;
                default: ;
            endcase

            // Arithmetic right shift
            {ACC, Q, Q_1} = {ACC[7], ACC, Q};

        end

        P = {ACC, Q};

    end

endmodule