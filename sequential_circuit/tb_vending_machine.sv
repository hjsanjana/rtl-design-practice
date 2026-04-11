// ═══════════════════════════════════════════════════
// Testbench — vending machine
// Tests exact change, overpayment, multiple sequences
// ═══════════════════════════════════════════════════

module tb_vending_machine;

    logic clk, rst_n;
    logic nickel, dime, quarter;
    logic dispense, change_5, change_10, change_15, change_20;

    vending_machine dut (.*);

    initial clk = 0;
    always  #5 clk = ~clk;

    // Task: insert one coin cleanly
    task insert_nickel();
        @(posedge clk); #1;
        nickel = 1; dime = 0; quarter = 0;
        @(posedge clk); #1;
        nickel = 0;
        $display("  Inserted nickel  | state=%-6s | dispense=%b chg5=%b chg10=%b",
                  dut.present_state.name(), dispense,
                  change_5, change_10);
    endtask

    task insert_dime();
        @(posedge clk); #1;
        nickel = 0; dime = 1; quarter = 0;
        @(posedge clk); #1;
        dime = 0;
        $display("  Inserted dime    | state=%-6s | dispense=%b chg5=%b chg10=%b",
                  dut.present_state.name(), dispense,
                  change_5, change_10);
    endtask

    task insert_quarter();
        @(posedge clk); #1;
        nickel = 0; dime = 0; quarter = 1;
        @(posedge clk); #1;
        quarter = 0;
        $display("  Inserted quarter | state=%-6s | dispense=%b chg5=%b chg10=%b",
                  dut.present_state.name(), dispense,
                  change_5, change_10);
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_vending_machine);

        // Reset
        rst_n = 0; nickel = 0; dime = 0; quarter = 0;
        repeat(2) @(posedge clk); #1;
        rst_n = 1;

        // ── Test 1: exact change 5+5+5+5+5+5 ──────
        $display("\n=== Test 1: Six nickels (exact 30¢) ===");
        repeat(6) insert_nickel();
        // Should see dispense=1 after 6th nickel
        @(posedge clk); #1; // one cycle in S30

        // ── Test 2: dime + dime + dime ─────────────
        $display("\n=== Test 2: Three dimes (exact 30¢) ===");
        repeat(3) insert_dime();
        @(posedge clk); #1;

        // ── Test 3: quarter + nickel ────────────────
        $display("\n=== Test 3: Quarter + nickel (exact 30¢) ===");
        insert_quarter();
        insert_nickel();
        @(posedge clk); #1;

        // ── Test 4: quarter + dime (overpay 5¢) ─────
        $display("\n=== Test 4: Quarter + dime (35¢, expect 5¢ change) ===");
        insert_quarter();
        insert_dime();
        @(posedge clk); #1;

        // ── Test 5: two quarters (overpay 20¢) ──────
        $display("\n=== Test 5: Two quarters (50¢, expect 20¢ change) ===");
        insert_quarter();
        insert_quarter();
        @(posedge clk); #1;

        $display("\n=== All tests complete ===");
        $finish;
    end

endmodule