module traffic_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic timer_done,
    output logic red, green, yellow
);

    typedef enum logic [1:0] {
        RED, GREEN, YELLOW
    } state_t;

    state_t state, next_state;

    // 1) State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= RED;
        else
            state <= next_state;
    end

    // 2) Next-state logic
    always_comb begin
        next_state = state;

        case (state)
            RED:    if (timer_done) next_state = GREEN;
            GREEN:  if (timer_done) next_state = YELLOW;
            YELLOW: if (timer_done) next_state = RED;
            default: next_state = RED;
        endcase
    end

    // 3) Output logic
    always_comb begin
        red = 0;
        green = 0;
        yellow = 0;

        case (state)
            RED:    red = 1;
            GREEN:  green = 1;
            YELLOW: yellow = 1;
        endcase
    end

endmodule