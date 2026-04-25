`timescale 1ns/1ps

module tb_axis_system;

localparam DW = 32;

logic ACLK, ARESETn;
initial ACLK = 0;
always #10 ACLK = ~ACLK;

// Master → FIFO
logic         M_TVALID, M_TREADY, M_TLAST;
logic [DW-1:0] M_TDATA;
logic [DW/8-1:0] M_TKEEP;

// FIFO → Slave
logic         F_TVALID, F_TREADY, F_TLAST;
logic [DW-1:0] F_TDATA;

// Slave outputs
logic [DW-1:0] rx_buf [0:255];
logic [8:0]    rx_count;
logic          pkt_done;

// Master control
logic          send, busy, mst_done;
logic [8:0]    beat_count;
logic [DW-1:0] data_in [0:255];

// Instantiate master
axis_master #(.DATA_WIDTH(DW), .MAX_BEATS(256)) u_mst (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .send(send), .beat_count(beat_count),
    .data_in(data_in), .busy(busy), .done(mst_done),
    .TVALID(M_TVALID), .TREADY(M_TREADY),
    .TDATA(M_TDATA),   .TLAST(M_TLAST), .TKEEP(M_TKEEP)
);

// Instantiate FIFO
axis_fifo #(.DATA_WIDTH(DW), .DEPTH(16)) u_fifo (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .S_TVALID(M_TVALID), .S_TREADY(M_TREADY),
    .S_TDATA(M_TDATA),   .S_TLAST(M_TLAST),
    .M_TVALID(F_TVALID), .M_TREADY(F_TREADY),
    .M_TDATA(F_TDATA),   .M_TLAST(F_TLAST)
);

// Instantiate slave
axis_slave #(.DATA_WIDTH(DW), .MAX_BEATS(256)) u_slv (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .TVALID(F_TVALID), .TREADY(F_TREADY),
    .TDATA(F_TDATA),   .TLAST(F_TLAST),
    .TKEEP({DW/8{1'b1}}),
    .rx_buf(rx_buf), .rx_count(rx_count),
    .packet_done(pkt_done), .ready_to_rx(1'b1)
);

initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb_axis_system);
    ARESETn = 0; send = 0; beat_count = 0;
    repeat(5) @(posedge ACLK); ARESETn = 1;
    repeat(3) @(posedge ACLK);

    // Build a 4-beat packet
    for (int i = 0; i < 4; i++)
        data_in[i] = 32'hBEEF_0000 + i;
    beat_count = 4;

    // Send it
    @(posedge ACLK); send = 1;
    @(posedge ACLK); send = 0;

    // Wait for slave to receive complete packet
    wait(pkt_done);
    $display("Packet received! %0d beats", rx_count);
    for (int i = 0; i < rx_count; i++)
        $display("  beat[%0d] = 0x%08h", i, rx_buf[i]);

    // Verify data integrity
    for (int i = 0; i < 4; i++) begin
        assert(rx_buf[i] == 32'hBEEF_0000 + i)
            else $error("Beat %0d mismatch", i);
    end

    $display("ALL AXIS TESTS PASSED");
    repeat(10) @(posedge ACLK);
    $finish;
end

endmodule