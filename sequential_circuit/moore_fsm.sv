
module simple_fsm (
    input  logic clk,
    input  logic rst_n,    // Active-low reset (most common in industry)
    input  logic start,
    input  logic done,
    output logic busy
);
// ─────────────────────────────────────────────
    // STEP 1: Declare state type using enum
    // enum gives names to states — tools can optimize
    // and it's readable. ALWAYS use this in interviews.
    // ─────────────────────────────────────────────
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        ACTIVE = 2'b01
    } state_t;

    state_t present_state, next_state;
	
	// ─────────────────────────────────────────────
    // BLOCK 1: State Register (sequential)
    // This is the memory — the flip-flops.
    // ONLY clk and reset go here. Nothing else.
    // ─────────────────────────────────────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            present_state <= IDLE;      // Reset → go to IDLE
        else
            present_state <= next_state; // Every clk edge: advance state
    end
	// ─────────────────────────────────────────────
    // BLOCK 2: Next State Logic (combinational)
    // Given WHERE I AM + INPUTS → decide WHERE TO GO
    // Use always_comb — tool ensures no latches
    // ─────────────────────────────────────────────
    always_comb begin
        next_state = present_state; // DEFAULT: stay in current state
                                    // This line prevents latches!
        case (present_state)
            IDLE: begin
                if (start)
                    next_state = ACTIVE;
                // else: next_state already = IDLE (from default)
            end

            ACTIVE: begin
                if (done)
                    next_state = IDLE;
                // else: next_state already = ACTIVE (from default)
            end

            default: next_state = IDLE; // Safety: illegal state → IDLE
        endcase
    end
	// ─────────────────────────────────────────────
    // BLOCK 3: Output Logic (combinational, Moore)
    // Moore: output depends ONLY on present_state
    // No inputs here — that's what makes it Moore!
    // ─────────────────────────────────────────────
    always_comb begin
        case (present_state)
            IDLE:    busy = 1'b0;
            ACTIVE:  busy = 1'b1;
            default: busy = 1'b0;  // Safety default
        endcase
    end

endmodule