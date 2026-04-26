`timescale 1ns/1ps

module tb_ahb_lite;

localparam AW = 32;
localparam DW = 32;

logic         HCLK, HRESETn;
initial HCLK = 0;
always #10 HCLK = ~HCLK;

// AHB bus signals
logic [AW-1:0] HADDR;
logic          HWRITE, HREADY, HREADYOUT, HRESP, HSEL;
logic [1:0]    HTRANS;
logic [2:0]    HSIZE, HBURST;
logic [DW-1:0] HWDATA, HRDATA;

// User control
logic          cmd_valid, cmd_write, cmd_done, cmd_err;
logic [AW-1:0] cmd_addr;
logic [DW-1:0] cmd_wdata, cmd_rdata;

// HREADY comes from slave HREADYOUT in single-slave system
assign HREADY = HREADYOUT;
assign HSEL   = 1'b1;  // Single slave — always selected

// Instantiate master
ahb_lite_master #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) u_mst (
    .HCLK(HCLK), .HRESETn(HRESETn),
    .cmd_valid(cmd_valid), .cmd_write(cmd_write),
    .cmd_addr(cmd_addr),   .cmd_wdata(cmd_wdata),
    .cmd_rdata(cmd_rdata), .cmd_done(cmd_done), .cmd_err(cmd_err),
    .HADDR(HADDR), .HWRITE(HWRITE), .HTRANS(HTRANS),
    .HSIZE(HSIZE), .HBURST(HBURST), .HWDATA(HWDATA),
    .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP)
);

// Instantiate slave with 1 wait state
ahb_lite_slave #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW), .WAIT_STATES(1)) u_slv (
    .HCLK(HCLK), .HRESETn(HRESETn),
    .HSEL(HSEL), .HREADY(HREADY),
    .HADDR(HADDR), .HWRITE(HWRITE), .HTRANS(HTRANS),
    .HSIZE(HSIZE), .HBURST(HBURST), .HWDATA(HWDATA),
    .HREADYOUT(HREADYOUT), .HRDATA(HRDATA), .HRESP(HRESP)
);

// Task: write
task ahb_write(input [31:0] addr, input [31:0] data);
    @(posedge HCLK);
    cmd_valid = 1; cmd_write = 1;
    cmd_addr  = addr; cmd_wdata = data;
    @(posedge HCLK); cmd_valid = 0;
    wait(cmd_done);
    $display("WR addr=0x%08h data=0x%08h", addr, data);
endtask

// Task: read
task ahb_read(input [31:0] addr, output [31:0] rdata);
    @(posedge HCLK);
    cmd_valid = 1; cmd_write = 0;
    cmd_addr  = addr; cmd_wdata = 0;
    @(posedge HCLK); cmd_valid = 0;
    wait(cmd_done);
    rdata = cmd_rdata;
    $display("RD addr=0x%08h data=0x%08h", addr, rdata);
endtask

logic [31:0] rd;

initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb_ahb_lite);
    HRESETn = 0; cmd_valid = 0; cmd_write = 0;
    cmd_addr = 0; cmd_wdata = 0;
    repeat(5) @(posedge HCLK); HRESETn = 1;
    repeat(3) @(posedge HCLK);

    // Write all 4 registers
    ahb_write(32'h00, 32'hDEAD_BEEF);
    ahb_write(32'h04, 32'hCAFE_BABE);
    ahb_write(32'h08, 32'h1234_5678);
    ahb_write(32'h0C, 32'hABCD_EF01);

    repeat(3) @(posedge HCLK);

    // Read back and verify
    ahb_read(32'h00, rd); assert(rd==32'hDEAD_BEEF) else $error("REG0");
    ahb_read(32'h04, rd); assert(rd==32'hCAFE_BABE) else $error("REG1");
    ahb_read(32'h08, rd); assert(rd==32'h1234_5678) else $error("REG2");
    ahb_read(32'h0C, rd); assert(rd==32'hABCD_EF01) else $error("REG3");

    $display("================================");
    $display("ALL AHB TESTS PASSED");
    $display("================================");
    $finish;
end

endmodule