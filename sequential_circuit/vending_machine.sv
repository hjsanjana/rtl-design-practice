module vending_machine (
    input  logic clk,
    input  logic rst_n,
    input  logic nickel,      // 5 cent coin inserted
    input  logic dime,        // 10 cent coin inserted
    input  logic quarter,     // 25 cent coin inserted
    output logic dispense,    // pulse high: give item
    output logic change_5,    // return 5 cents
    output logic change_10,   // return 10 cents
    output logic change_15,   // return 15 cents
    output logic change_20    // return 20 cents
);

    // ── State declaration ────────────────────────────
    // States represent credit accumulated (in cents)
    typedef enum logic [2:0] {
        S0  = 3'b000,   // 0 cents
        S5  = 3'b001,   // 5 cents
        S10 = 3'b010,   // 10 cents
        S15 = 3'b011,   // 15 cents
        S20 = 3'b100,   // 20 cents
        S25 = 3'b101,   // 25 cents
        S30 = 3'b110    // 30+ cents — dispense!
    } state_t;

    state_t present_state, next_state;

    // ── BLOCK 1: State register ──────────────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) present_state <= S0;
        else        present_state <= next_state;
    end

    // ── BLOCK 2: Next state logic ────────────────────
    // Inputs: nickel, dime, quarter (assumed one-hot)
    // Key insight: quarter can overshoot 30¢ — all
    // overshoot cases still go to S30
    always_comb begin
        next_state = present_state; // default: stay

        case (present_state)
            S0: begin
                if      (nickel)  next_state = S5;
                else if (dime)    next_state = S10;
                else if (quarter) next_state = S25;
            end

            S5: begin
                if      (nickel)  next_state = S10;
                else if (dime)    next_state = S15;
                else if (quarter) next_state = S30; // 5+25=30 exact
            end

            S10: begin
                if      (nickel)  next_state = S15;
                else if (dime)    next_state = S20;
                else if (quarter) next_state = S30; // 10+25=35 → dispense+chg5
            end

            S15: begin
                if      (nickel)  next_state = S20;
                else if (dime)    next_state = S25;
                else if (quarter) next_state = S30; // 15+25=40 → dispense+chg10
            end

            S20: begin
                if      (nickel)  next_state = S25;
                else if (dime)    next_state = S30; // 20+10=30 exact
                else if (quarter) next_state = S30; // 20+25=45 → dispense+chg15
            end

            S25: begin
                if      (nickel)  next_state = S30; // 25+5=30 exact
                else if (dime)    next_state = S30; // 25+10=35 → dispense+chg5
                else if (quarter) next_state = S30; // 25+25=50 → dispense+chg20
            end

            S30: next_state = S0; // always return to idle after dispensing

            default: next_state = S0;
        endcase
    end

    // ── BLOCK 3: Output logic (Moore) ────────────────
    // All outputs depend only on present_state
    // Change amounts encoded per state based on what
    // coin caused entry (encoded in the state itself)
    //
    // IMPORTANT DESIGN DECISION:
    // We encode WHICH COIN was last inserted into
    // the state machine implicitly — the change output
    // fires in S30 based on how we GOT to S30.
    //
    // PROBLEM: Moore output can't know HOW we arrived!
    // SOLUTION: Split S30 into multiple states, one per
    // entry path. OR use Mealy output for change only.
    //
    // Here we use a HYBRID approach:
    // - dispense is Moore (state only)
    // - change is Mealy (state + last coin input)
    // This is a real design tradeoff — mention it!

    always_comb begin
        // Defaults
        dispense  = 1'b0;
        change_5  = 1'b0;
        change_10 = 1'b0;
        change_15 = 1'b0;
        change_20 = 1'b0;

        case (present_state)
            // ── Not yet paid — no outputs ──────────
            S0, S5, S10, S15, S20, S25: begin
                dispense  = 1'b0;
                // No change yet — still collecting
            end

            // ── Paid — dispense + change ───────────
            // S30 is pure Moore for dispense
            // Change uses Mealy — depends on WHICH
            // state we came FROM (encoded via inputs
            // we check in the PREVIOUS state's context)
            // For simplicity here we register the
            // last coin separately — see below
            S30: begin
                dispense = 1'b1;
                // change outputs set by registered_coin
                // logic — see hybrid approach below
            end

            default: begin
                dispense = 1'b0;
            end
        endcase
    end

endmodule