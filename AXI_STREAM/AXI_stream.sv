// ============================================================
// AXI4-Stream Slave
// Receives a packet and stores it in a buffer
// Signals packet_done when TLAST is received
// ============================================================

module axis_slave #(
    parameter DATA_WIDTH = 32,
    parameter MAX_BEATS  = 256
)(
    input  logic                      ACLK,
    input  logic                      ARESETn,

    // AXI4-Stream interface
    input  logic                      TVALID,
    output logic                      TREADY,
    input  logic [DATA_WIDTH-1:0]     TDATA,
    input  logic                      TLAST,
    input  logic [DATA_WIDTH/8-1:0]   TKEEP,

    // User interface
    output logic [DATA_WIDTH-1:0]     rx_buf [0:MAX_BEATS-1],
    output logic [$clog2(MAX_BEATS):0] rx_count,
    output logic                      packet_done,  // Pulses when full packet received
    input  logic                      ready_to_rx   // User logic: can accept data?
);

logic [$clog2(MAX_BEATS):0] wr_ptr;

// TREADY: accept data when user logic is ready AND buffer has space
assign TREADY = ready_to_rx && (wr_ptr < MAX_BEATS);

always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        wr_ptr      <= '0;
        rx_count    <= '0;
        packet_done <= 1'b0;
    end else begin
        packet_done <= 1'b0;

        if (TVALID && TREADY) begin
            // Store this beat
            rx_buf[wr_ptr] <= TDATA;
            wr_ptr         <= wr_ptr + 1;

            if (TLAST) begin
                // Packet complete
                rx_count    <= wr_ptr + 1;
                packet_done <= 1'b1;
                wr_ptr      <= '0;   // Reset for next packet
            end
        end
    end
end

endmodule