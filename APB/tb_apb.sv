`timescale 1ns/1ps

module tb_apb;

// Parameters
localparam ADDR_WIDTH  = 32;
localparam DATA_WIDTH  = 32;
localparam WAIT_STATES = 2;   // Test with 2 wait states

// Clock and reset
logic PCLK, PRESETn;
initial PCLK = 0;
always #10 PCLK = ~PCLK;     // 50 MHz

// APB bus signals
logic                  PSEL, PENABLE, PWRITE;
logic [ADDR_WIDTH-1:0] PADDR;
logic [DATA_WIDTH-1:0] PWDATA, PRDATA;
logic                  PREADY, PSLVERR;

// Master user interface
logic                  cmd_valid, cmd_write, cmd_done, cmd_err;
logic [ADDR_WIDTH-1:0] cmd_addr;
logic [DATA_WIDTH-1:0] cmd_wdata, cmd_rdata;

// Instantiate master
apb_master #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) u_master (
    .PCLK(PCLK), .PRESETn(PRESETn),
    .cmd_valid(cmd_valid), .cmd_write(cmd_write),
    .cmd_addr(cmd_addr),   .cmd_wdata(cmd_wdata),
    .cmd_rdata(cmd_rdata), .cmd_done(cmd_done),
    .cmd_err(cmd_err),
    .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
    .PADDR(PADDR), .PWDATA(PWDATA),
    .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
);

// Instantiate slave with 2 wait states
apb_slave #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .WAIT_STATES(WAIT_STATES)
) u_slave (
    .PCLK(PCLK), .PRESETn(PRESETn),
    .PSEL(PSEL), .PENABLE(PENABLE),
    .PWRITE(PWRITE), .PADDR(PADDR),
    .PWDATA(PWDATA), .PRDATA(PRDATA),
    .PREADY(PREADY), .PSLVERR(PSLVERR)
);

// ============================================================
// Task: APB write
// ============================================================
task apb_write(input [31:0] addr, input [31:0] data);
    @(posedge PCLK);
    cmd_valid = 1; cmd_write = 1;
    cmd_addr  = addr; cmd_wdata = data;
    @(posedge PCLK);
    cmd_valid = 0;
    wait(cmd_done);
    $display("WRITE addr=0x%08h data=0x%08h  done at %0t", addr, data, $time);
endtask

// ============================================================
// Task: APB read
// ============================================================
task apb_read(input [31:0] addr, output [31:0] rdata);
    @(posedge PCLK);
    cmd_valid = 1; cmd_write = 0;
    cmd_addr  = addr; cmd_wdata = 0;
    @(posedge PCLK);
    cmd_valid = 0;
    wait(cmd_done);
    rdata = cmd_rdata;
    $display("READ  addr=0x%08h data=0x%08h  done at %0t", addr, rdata, $time);
endtask

// ============================================================
// Test sequence
// ============================================================
logic [31:0] rd;

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_apb);

    // Reset
    PRESETn   = 0;
    cmd_valid = 0; cmd_write = 0;
    cmd_addr  = 0; cmd_wdata = 0;
    repeat(5) @(posedge PCLK);
    PRESETn = 1;
    repeat(3) @(posedge PCLK);

    // Write to all 4 registers
    apb_write(32'h00, 32'hDEAD_BEEF);
    apb_write(32'h04, 32'hCAFE_BABE);
    apb_write(32'h08, 32'h1234_5678);
    apb_write(32'h0C, 32'hABCD_EF01);
    repeat(3) @(posedge PCLK);

    // Read them back and verify
    apb_read(32'h00, rd);
    assert(rd == 32'hDEAD_BEEF) else $error("REG0 mismatch");

    apb_read(32'h04, rd);
    assert(rd == 32'hCAFE_BABE) else $error("REG1 mismatch");

    apb_read(32'h08, rd);
    assert(rd == 32'h1234_5678) else $error("REG2 mismatch");

    apb_read(32'h0C, rd);
    assert(rd == 32'hABCD_EF01) else $error("REG3 mismatch");

    $display("===============================");
    $display("All APB tests PASSED");
    $display("===============================");
    repeat(5) @(posedge PCLK);
    $finish;
end

endmodule