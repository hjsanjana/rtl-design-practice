// ============================================================
// AXI4-Stream Master
// Sends an array of data beats as a single packet
// Asserts TLAST on the final beat
// ============================================================

module axis_master #(
    parameter DATA_WIDTH = 32,
    parameter MAX_BEATS  = 256
)(
    input  logic                      ACLK,
    input  logic                      ARESETn,

    // User interface
    input  logic                      send,         // Pulse to start sending
    input  logic [$clog2(MAX_BEATS):0] beat_count,  // How many beats to send
    input  logic [DATA_WIDTH-1:0]     data_in [0:MAX_BEATS-1],

    output logic                      busy,
    output logic                      done,

    // AXI4-Stream interface
    output logic                      TVALID,
    input  logic                      TREADY,
    output logic [DATA_WIDTH-1:0]     TDATA,
    output logic                      TLAST,
    output logic [DATA_WIDTH/8-1:0]   TKEEP
);

localparam KEEP_ALL = {(DATA_WIDTH/8){1'b1}};  // All bytes valid

typedef enum logic [1:0] {
    IDLE = 2'b00,
    SEND = 2'b01
} state_t;

state_t state;

logic [$clog2(MAX_BEATS):0] beat_idx;   // Current beat being sent
logic [$clog2(MAX_BEATS):0] total_beats; // Latched beat count
logic [DATA_WIDTH-1:0] data_buf [0:MAX_BEATS-1]; // Latched data

always_ff @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        state       <= IDLE;
        TVALID      <= 1'b0;
        TDATA       <= '0;
        TLAST       <= 1'b0;
        TKEEP       <= '0;
        beat_idx    <= '0;
        total_beats <= '0;
        busy        <= 1'b0;
        done        <= 1'b0;
    end else begin
        done <= 1'b0;

        case (state)

            // ------------------------------------------------
            IDLE: begin
                TVALID <= 1'b0;
                busy   <= 1'b0;
                if (send) begin
                    // Latch everything before starting
                    data_buf    <= data_in;
                    total_beats <= beat_count;
                    beat_idx    <= 0;
                    // Present first beat immediately
                    TVALID <= 1'b1;
                    TDATA  <= data_in[0];
                    TKEEP  <= KEEP_ALL;
                    TLAST  <= (beat_count == 1);
                    busy   <= 1'b1;
                    state  <= SEND;
                end
            end

            // ------------------------------------------------
            SEND: begin
                TVALID <= 1'b1;

                // Handshake completed this cycle
                if (TVALID && TREADY) begin
                    if (TLAST) begin
                        // Last beat just sent
                        TVALID <= 1'b0;
                        TLAST  <= 1'b0;
                        done   <= 1'b1;
                        state  <= IDLE;
                    end else begin
                        // Advance to next beat
                        beat_idx <= beat_idx + 1;
                        TDATA    <= data_buf[beat_idx + 1];
                        TKEEP    <= KEEP_ALL;
                        TLAST    <= (beat_idx + 1 == total_beats - 1);
                    end
                end
                // If TREADY=0: hold TDATA, TVALID, TLAST stable — do nothing
            end

        endcase
    end
end

endmodule