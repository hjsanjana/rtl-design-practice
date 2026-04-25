// ============================================================
// AXI4 Full Master — initiates burst write transactions
// ============================================================

module axi4_full_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MAX_BURST  = 16
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // User interface
    input  logic                    wr_start,
    input  logic [ADDR_WIDTH-1:0]   wr_addr,
    input  logic [7:0]              wr_len,     // AWLEN value
    input  logic [DATA_WIDTH-1:0]   wr_data [0:MAX_BURST-1],
    output logic                    wr_done,
    output logic                    wr_err,

    // AXI4 Write channels
    output logic                    AWVALID,
    input  logic                    AWREADY,
    output logic [ADDR_WIDTH-1:0]   AWADDR,
    output logic [7:0]              AWLEN,
    output logic [2:0]              AWSIZE,
    output logic [1:0]              AWBURST,

    output logic                    WVALID,
    input  logic                    WREADY,
    output logic [DATA_WIDTH-1:0]   WDATA,
    output logic [DATA_WIDTH/8-1:0] WSTRB,
    output logic                    WLAST,

    input  logic                    BVALID,
    output logic                    BREADY,
    input  logic [1:0]              BRESP
);

typedef enum logic [2:0] {
    M_IDLE    = 3'd0,
    M_AW      = 3'd1,   // Sending write address
    M_W       = 3'd2,   // Sending write data beats
    M_B       = 3'd3    // Waiting for write response
} mst_state_t;

mst_state_t state;

logic [7:0]  beat_cnt;
logic [7:0]  burst_len_lat;
logic [DATA_WIDTH-1:0] data_buf [0:MAX_BURST-1];

always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        state    <= M_IDLE;
        AWVALID  <= 1'b0;
        WVALID   <= 1'b0;
        WLAST    <= 1'b0;
        BREADY   <= 1'b0;
        wr_done  <= 1'b0;
        wr_err   <= 1'b0;
        beat_cnt <= '0;
    end else begin
        wr_done <= 1'b0;
        wr_err  <= 1'b0;

        case (state)
            M_IDLE: begin
                if (wr_start) begin
                    // Latch data buffer
                    data_buf     <= wr_data;
                    burst_len_lat <= wr_len;
                    beat_cnt     <= '0;
                    // Assert AW
                    AWVALID  <= 1'b1;
                    AWADDR   <= wr_addr;
                    AWLEN    <= wr_len;
                    AWSIZE   <= 3'b010;    // 4 bytes per beat
                    AWBURST  <= 2'b01;     // INCR
                    state    <= M_AW;
                end
            end

            M_AW: begin
                if (AWVALID && AWREADY) begin
                    AWVALID <= 1'b0;
                    // Start sending data immediately
                    WVALID  <= 1'b1;
                    WDATA   <= data_buf[0];
                    WSTRB   <= 4'hF;
                    WLAST   <= (burst_len_lat == 0);
                    beat_cnt <= 0;
                    state   <= M_W;
                end
            end

            M_W: begin
                if (WVALID && WREADY) begin
                    if (WLAST) begin
                        // Last beat sent
                        WVALID  <= 1'b0;
                        WLAST   <= 1'b0;
                        BREADY  <= 1'b1;
                        state   <= M_B;
                    end else begin
                        // Send next beat
                        beat_cnt <= beat_cnt + 1;
                        WDATA    <= data_buf[beat_cnt + 1];
                        WLAST    <= (beat_cnt + 1 == burst_len_lat);
                    end
                end
            end

            M_B: begin
                if (BVALID && BREADY) begin
                    BREADY  <= 1'b0;
                    wr_done <= 1'b1;
                    wr_err  <= (BRESP != 2'b00);
                    state   <= M_IDLE;
                end
            end
        endcase
    end
end

endmodule