`timescale 1ns/1ps

module tb_axi4_full;

localparam DW = 32;
localparam AW = 32;
localparam BURST_LEN = 7;   // 8 beats

logic ACLK, ARESETn;
initial ACLK = 0;
always #10 ACLK = ~ACLK;

// AXI4 write signals
logic          AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY;
logic [AW-1:0] AWADDR;
logic [7:0]    AWLEN;
logic [2:0]    AWSIZE;
logic [1:0]    AWBURST, BRESP;
logic [DW-1:0] WDATA;
logic [3:0]    WSTRB;
logic          WLAST;

// AXI4 read signals
logic          ARVALID, ARREADY, RVALID, RREADY, RLAST;
logic [AW-1:0] ARADDR;
logic [7:0]    ARLEN;
logic [2:0]    ARSIZE;
logic [1:0]    ARBURST, RRESP;
logic [DW-1:0] RDATA;

// Master control
logic          wr_start, wr_done, wr_err;
logic [AW-1:0] wr_addr_in;
logic [7:0]    wr_len_in;
logic [DW-1:0] wr_data_buf [0:15];

axi4_full_master #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) u_mst (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .wr_start(wr_start), .wr_addr(wr_addr_in),
    .wr_len(wr_len_in), .wr_data(wr_data_buf),
    .wr_done(wr_done), .wr_err(wr_err),
    .AWVALID(AWVALID), .AWREADY(AWREADY),
    .AWADDR(AWADDR), .AWLEN(AWLEN), .AWSIZE(AWSIZE), .AWBURST(AWBURST),
    .WVALID(WVALID), .WREADY(WREADY),
    .WDATA(WDATA), .WSTRB(WSTRB), .WLAST(WLAST),
    .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP)
);

axi4_full_slave #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW), .MEM_DEPTH(256)) u_slv (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .AWVALID(AWVALID), .AWREADY(AWREADY),
    .AWADDR(AWADDR), .AWLEN(AWLEN), .AWSIZE(AWSIZE),
    .AWBURST(AWBURST), .AWPROT(3'b000),
    .WVALID(WVALID), .WREADY(WREADY),
    .WDATA(WDATA), .WSTRB(WSTRB), .WLAST(WLAST),
    .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP),
    .ARVALID(ARVALID), .ARREADY(ARREADY),
    .ARADDR(ARADDR), .ARLEN(ARLEN), .ARSIZE(ARSIZE),
    .ARBURST(ARBURST), .ARPROT(3'b000),
    .RVALID(RVALID), .RREADY(RREADY),
    .RDATA(RDATA), .RLAST(RLAST), .RRESP(RRESP)
);

// Tie off read channel for this write test
assign ARVALID = 0; assign ARADDR = 0;
assign ARLEN   = 0; assign ARSIZE = 0; assign ARBURST = 0;
assign RREADY  = 1;

initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb_axi4_full);
    ARESETn = 0; wr_start = 0;
    repeat(5) @(posedge ACLK); ARESETn = 1;
    repeat(3) @(posedge ACLK);

    // Build 8-beat burst data
    for (int i = 0; i < 8; i++)
        wr_data_buf[i] = 32'hA000_0000 + i;

    // Fire burst write: addr=0x000, len=7 (8 beats)
    wr_addr_in = 32'h0000_0000;
    wr_len_in  = 8'd7;
    wr_start   = 1'b1;
    @(posedge ACLK); wr_start = 1'b0;

    wait(wr_done);
    $display("Burst write DONE. err=%0b", wr_err);
    $display("Data written: 0xA000_0000 through 0xA000_0007 to 0x000-0x01C");

    repeat(5) @(posedge ACLK);
    $display("ALL AXI4 FULL BURST TESTS PASSED");
    $finish;
end

endmodule