

module tb_johnson_counter;

    parameter int N = 4;
    localparam int NUM_STATES = 2 * N;

    logic         clk;
    logic         rst_n;
    logic [N-1:0] count;

    // DUT
    johnson_counter #(.N(N)) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .count (count)
    );

    // Clock generation: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // Expected next-state function
    function automatic logic [N-1:0] johnson_next(input logic [N-1:0] cur);
        johnson_next = {~cur[0], cur[N-1:1]};
    endfunction

    logic [N-1:0] exp_count;
    int i;

    initial begin
        // Init
        rst_n     = 0;
        exp_count = '0;

        // Hold reset for a couple of cycles
        repeat (2) @(posedge clk);
        rst_n = 1;

        // Check 2N states
        for (i = 0; i < NUM_STATES + 2; i++) begin
            @(posedge clk);

            exp_count = johnson_next(exp_count);

            assert (count === exp_count)
                else $fatal(1,
                    "Mismatch at cycle %0d: expected=%0b actual=%0b",
                    i, exp_count, count);
        end

        // Check that sequence wraps correctly after 2N states
        repeat (NUM_STATES - 2) begin
            @(posedge clk);
            exp_count = johnson_next(exp_count);

            assert (count === exp_count)
                else $fatal(1,
                    "Wrap check failed: expected=%0b actual=%0b",
                    exp_count, count);
        end

        $display("PASS: Johnson counter verified for N=%0d", N);
        $finish;
    end

    // Reset behavior check
    always @(negedge rst_n) begin
        #1;
        assert (count == '0)
            else $fatal(1, "Reset failed: count=%0b, expected=0", count);
    end

endmodule