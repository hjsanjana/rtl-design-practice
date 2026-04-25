// ============================================================
// AXI4-Stream FIFO
// Decouples upstream and downstream timing
// Propagates backpressure only when full
// ============================================================

module axis_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16     // Must be power of 2
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // Upstream (slave port — receives data)
    input  logic                    S_TVALID,
    output logic                    S_TREADY,
    input  logic [DATA_WIDTH-1:0]   S_TDATA,
    input  logic                    S_TLAST,

    // Downstream (master port — sends data)
    output logic                    M_TVALID,
    input  logic                    M_TREADY,
    output logic [DATA_WIDTH-1:0]   M_TDATA,
    output logic                    M_TLAST
);

localparam PTR_WIDTH = $clog2(DEPTH);

// FIFO storage — store data + TLAST together
logic [DATA_WIDTH:0] mem [0:DEPTH-1];  // DATA_WIDTH + 1 bit for TLAST
logic [PTR_WIDTH:0]  wr_ptr, rd_ptr;   // Extra bit for full/empty detection
logic                full, empty;

// Full and empty detection using the extra pointer bit
assign full  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) &&
               (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);
assign empty = (wr_ptr == rd_ptr);

// Slave port: accept when not full
assign S_TREADY = !full;

// Master port: valid when not empty
assign M_TVALID = !empty;
assign M_TDATA  = mem[rd_ptr[PTR_WIDTH-1:0]][DATA_WIDTH-1:0];
assign M_TLAST  = mem[rd_ptr[PTR_WIDTH-1:0]][DATA_WIDTH];

// Write side
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        wr_ptr <= '0;
    end else if (S_TVALID && S_TREADY) begin
        mem[wr_ptr[PTR_WIDTH-1:0]] <= {S_TLAST, S_TDATA};
        wr_ptr <= wr_ptr + 1;
    end
end

// Read side
always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        rd_ptr <= '0;
    end else if (M_TVALID && M_TREADY) begin
        rd_ptr <= rd_ptr + 1;
    end
end

endmodule