`timescale 1ns/1ps

module tb_axi4_lite;

localparam DW = 32;
localparam AW = 32;

logic ACLK, ARESETn;
initial ACLK = 0;
always #10 ACLK = ~ACLK;

// AXI signals
logic          AWVALID, AWREADY, WVALID, WREADY;
logic          BVALID,  BREADY,  ARVALID, ARREADY;
logic          RVALID,  RREADY;
logic [AW-1:0] AWADDR,  ARADDR;
logic [DW-1:0] WDATA,   RDATA,   wr_data_in, rd_data_out;
logic [3:0]    WSTRB;
logic [2:0]    AWPROT,  ARPROT;
logic [1:0]    BRESP,   RRESP;

// Control
logic          wr_en, rd_en, wr_done, rd_done, err;
logic [AW-1:0] addr;

// Instantiate master
axi4_lite_master #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) u_mst (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .wr_en(wr_en), .rd_en(rd_en),
    .addr(addr), .wr_data(wr_data_in), .wr_strb(WSTRB),
    .rd_data(rd_data_out), .wr_done(wr_done), .rd_done(rd_done), .err(err),
    .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR), .AWPROT(AWPROT),
    .WVALID(WVALID),   .WREADY(WREADY),   .WDATA(WDATA),   .WSTRB(WSTRB),
    .BVALID(BVALID),   .BREADY(BREADY),   .BRESP(BRESP),
    .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR), .ARPROT(ARPROT),
    .RVALID(RVALID),   .RREADY(RREADY),   .RDATA(RDATA),   .RRESP(RRESP)
);

// Instantiate slave
axi4_lite_slave #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) u_slv (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR), .AWPROT(AWPROT),
    .WVALID(WVALID),   .WREADY(WREADY),   .WDATA(WDATA),   .WSTRB(WSTRB),
    .BVALID(BVALID),   .BREADY(BREADY),   .BRESP(BRESP),
    .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR), .ARPROT(ARPROT),
    .RVALID(RVALID),   .RREADY(RREADY),   .RDATA(RDATA),   .RRESP(RRESP)
);

// Tasks
task axi_write(input [31:0] a, input [31:0] d);
    @(posedge ACLK);
    addr = a; wr_data_in = d; WSTRB = 4'hF; wr_en = 1;
    @(posedge ACLK); wr_en = 0;
    wait(wr_done);
    $display("WR addr=0x%08h data=0x%08h err=%0b", a, d, err);
endtask

task axi_read(input [31:0] a, output [31:0] d);
    @(posedge ACLK);
    addr = a; rd_en = 1;
    @(posedge ACLK); rd_en = 0;
    wait(rd_done);
    d = rd_data_out;
    $display("RD addr=0x%08h data=0x%08h", a, d);
endtask

logic [31:0] rd;

initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb_axi4_lite);
    ARESETn = 0; wr_en = 0; rd_en = 0;
    addr = 0; wr_data_in = 0;
    repeat(5) @(posedge ACLK); ARESETn = 1;
    repeat(3) @(posedge ACLK);

    // Write all four registers
    axi_write(32'h00, 32'hDEAD_BEEF);
    axi_write(32'h04, 32'hCAFE_BABE);
    axi_write(32'h08, 32'h1234_5678);
    axi_write(32'h0C, 32'hFFFF_0000);

    // Read back and verify
    axi_read(32'h00, rd); assert(rd==32'hDEAD_BEEF) else $error("REG0 fail");
    axi_read(32'h04, rd); assert(rd==32'hCAFE_BABE) else $error("REG1 fail");
    axi_read(32'h08, rd); assert(rd==32'h1234_5678) else $error("REG2 fail");
    axi_read(32'h0C, rd); assert(rd==32'hFFFF_0000) else $error("REG3 fail");

    $display("===========================");
    $display("ALL AXI4-Lite TESTS PASSED");
    $display("===========================");
    $finish;
end

endmodule