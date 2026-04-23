// ============================================================
// I2C Master — Write and Read transactions
// Supports clock stretching detection
// Standard mode: 100 kHz SCL with 50 MHz system clock
// ============================================================

module i2c_master #(
    parameter CLK_FREQ  = 50_000_000,
    parameter I2C_FREQ  = 100_000        // 100 kHz standard mode
)(
    input  logic        clk,
    input  logic        rst_n,

    // User interface
    input  logic        start,           // Pulse to begin transaction
    input  logic        rw,              // 0=write, 1=read
    input  logic [6:0]  addr,            // 7-bit slave address
    input  logic [7:0]  wr_data,         // Data to write
    output logic [7:0]  rd_data,         // Data read from slave
    output logic        done,            // Transaction complete
    output logic        ack_err,         // NACK received when ACK expected

    // I2C bus (open-drain — drive LOW or release)
    output logic        scl_oe,          // 1 = pull SCL LOW, 0 = release
    output logic        sda_oe,          // 1 = pull SDA LOW, 0 = release
    input  logic        scl_in,          // Read back SCL (for stretch detect)
    input  logic        sda_in           // Read back SDA (for ACK detect)
);

// ============================================================
// How open-drain works in RTL:
// scl_oe=1 → your output buffer drives SCL LOW
// scl_oe=0 → your output buffer is high-Z, pull-up makes it HIGH
// Same for sda_oe/sda_in
// On an FPGA: inout port + assign pad = oe ? 1'b0 : 1'bz
// ============================================================

localparam HALF_PERIOD  = CLK_FREQ / (2 * I2C_FREQ);  // 250 clocks
localparam QUART_PERIOD = HALF_PERIOD / 2;              // 125 clocks

// ============================================================
// State machine
// ============================================================
typedef enum logic [3:0] {
    S_IDLE       = 4'd0,
    S_START      = 4'd1,   // SDA falls, SCL still HIGH
    S_START2     = 4'd2,   // Pull SCL LOW after START
    S_ADDR       = 4'd3,   // Send 7-bit address + R/W
    S_ADDR_ACK   = 4'd4,   // Release SDA, read ACK
    S_DATA       = 4'd5,   // Send or receive 8 data bits
    S_DATA_ACK   = 4'd6,   // ACK phase after data byte
    S_STOP1      = 4'd7,   // Pull SDA LOW, raise SCL
    S_STOP2      = 4'd8    // Release SDA while SCL=HIGH (STOP)
} state_t;

state_t state;

// ============================================================
// Internal registers
// ============================================================
logic [8:0]  clk_cnt;       // Quarter-period counter
logic [3:0]  bit_cnt;       // Bit counter (0-7 for data, 0-7 for address)
logic [7:0]  shift_reg;     // TX/RX shift register
logic        scl_phase;     // 0=SCL LOW half, 1=SCL HIGH half
logic        saved_rw;      // Latched R/W direction
logic [6:0]  saved_addr;    // Latched address
logic [7:0]  saved_data;    // Latched write data

// ============================================================
// Quarter-period tick
// ============================================================
logic tick;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt <= 0;
    end else begin
        if (clk_cnt == QUART_PERIOD - 1) begin
            clk_cnt <= 0;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end
end
assign tick = (clk_cnt == QUART_PERIOD - 1);

// ============================================================
// Main FSM
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= S_IDLE;
        scl_oe     <= 1'b0;   // Release SCL (HIGH via pull-up)
        sda_oe     <= 1'b0;   // Release SDA (HIGH via pull-up)
        done       <= 1'b0;
        ack_err    <= 1'b0;
        bit_cnt    <= 0;
        shift_reg  <= 0;
        rd_data    <= 0;
        scl_phase  <= 0;
    end else begin

        done    <= 1'b0;
        ack_err <= 1'b0;

        case (state)

            // ------------------------------------------------
            S_IDLE: begin
                scl_oe <= 1'b0;  // Release both lines
                sda_oe <= 1'b0;
                if (start) begin
                    saved_rw   <= rw;
                    saved_addr <= addr;
                    saved_data <= wr_data;
                    state      <= S_START;
                end
            end

            // ------------------------------------------------
            // START: pull SDA LOW while SCL is HIGH
            S_START: begin
                scl_oe <= 1'b0;    // SCL stays HIGH (released)
                sda_oe <= 1'b1;    // Pull SDA LOW
                if (tick) begin
                    state <= S_START2;
                end
            end

            // ------------------------------------------------
            // Now pull SCL LOW, prepare to send address
            S_START2: begin
                scl_oe   <= 1'b1;  // Pull SCL LOW
                sda_oe   <= 1'b1;  // Keep SDA LOW
                if (tick) begin
                    // Load address + R/W into shift register
                    // Format: [addr6, addr5, addr4, addr3, addr2, addr1, addr0, rw]
                    shift_reg <= {saved_addr, saved_rw};
                    bit_cnt   <= 0;
                    state     <= S_ADDR;
                end
            end

            // ------------------------------------------------
            // Send 8 bits (7-bit address + R/W), MSB first
            S_ADDR: begin
                if (tick) begin
                    if (!scl_phase) begin
                        // SCL LOW half: put bit on SDA
                        sda_oe    <= ~shift_reg[7];  // OE=1 drives LOW, OE=0 releases HIGH
                        shift_reg <= {shift_reg[6:0], 1'b0};  // Shift left
                        scl_oe    <= 1'b0;           // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        // SCL HIGH half: check for clock stretching, then pull SCL LOW
                        if (scl_in == 1'b1) begin    // Slave not stretching
                            scl_oe    <= 1'b1;       // Pull SCL LOW
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_ADDR_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                        // If scl_in=0, slave stretching — stay here and wait
                    end
                end
            end

            // ------------------------------------------------
            // Address ACK phase: release SDA, slave should pull it LOW
            S_ADDR_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release SDA for slave to ACK
                        scl_oe    <= 1'b0;   // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            // Sample SDA — LOW=ACK, HIGH=NACK
                            if (sda_in == 1'b1) begin
                                // NACK — abort
                                ack_err <= 1'b1;
                                state   <= S_STOP1;
                            end else begin
                                // ACK received — load data, move to data phase
                                shift_reg <= saved_data;
                                bit_cnt   <= 0;
                                state     <= S_DATA;
                            end
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Send data byte (write mode) — same structure as ADDR
            S_DATA: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= ~shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_DATA_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Data ACK: read slave response
            S_DATA_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release for slave ACK
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            if (sda_in == 1'b1)
                                ack_err <= 1'b1;   // NACK from slave
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            state     <= S_STOP1;  // Single byte — go to stop
                        end
                    end
                end
            end

            // ------------------------------------------------
            // STOP: pull SDA LOW, raise SCL, then release SDA
            S_STOP1: begin
                if (tick) begin
                    sda_oe <= 1'b1;    // Pull SDA LOW
                    scl_oe <= 1'b0;    // Release SCL (goes HIGH)
                    state  <= S_STOP2;
                end
            end

            S_STOP2: begin
                if (tick) begin
                    sda_oe <= 1'b0;   // Release SDA — STOP condition!
                    done   <= 1'b1;
                    state  <= S_IDLE;
                end
            end

        endcase
    end
end

endmodule// ============================================================
// I2C Master — Write and Read transactions
// Supports clock stretching detection
// Standard mode: 100 kHz SCL with 50 MHz system clock
// ============================================================

module i2c_master #(
    parameter CLK_FREQ  = 50_000_000,
    parameter I2C_FREQ  = 100_000        // 100 kHz standard mode
)(
    input  logic        clk,
    input  logic        rst_n,

    // User interface
    input  logic        start,           // Pulse to begin transaction
    input  logic        rw,              // 0=write, 1=read
    input  logic [6:0]  addr,            // 7-bit slave address
    input  logic [7:0]  wr_data,         // Data to write
    output logic [7:0]  rd_data,         // Data read from slave
    output logic        done,            // Transaction complete
    output logic        ack_err,         // NACK received when ACK expected

    // I2C bus (open-drain — drive LOW or release)
    output logic        scl_oe,          // 1 = pull SCL LOW, 0 = release
    output logic        sda_oe,          // 1 = pull SDA LOW, 0 = release
    input  logic        scl_in,          // Read back SCL (for stretch detect)
    input  logic        sda_in           // Read back SDA (for ACK detect)
);

// ============================================================
// How open-drain works in RTL:
// scl_oe=1 → your output buffer drives SCL LOW
// scl_oe=0 → your output buffer is high-Z, pull-up makes it HIGH
// Same for sda_oe/sda_in
// On an FPGA: inout port + assign pad = oe ? 1'b0 : 1'bz
// ============================================================

localparam HALF_PERIOD  = CLK_FREQ / (2 * I2C_FREQ);  // 250 clocks
localparam QUART_PERIOD = HALF_PERIOD / 2;              // 125 clocks

// ============================================================
// State machine
// ============================================================
typedef enum logic [3:0] {
    S_IDLE       = 4'd0,
    S_START      = 4'd1,   // SDA falls, SCL still HIGH
    S_START2     = 4'd2,   // Pull SCL LOW after START
    S_ADDR       = 4'd3,   // Send 7-bit address + R/W
    S_ADDR_ACK   = 4'd4,   // Release SDA, read ACK
    S_DATA       = 4'd5,   // Send or receive 8 data bits
    S_DATA_ACK   = 4'd6,   // ACK phase after data byte
    S_STOP1      = 4'd7,   // Pull SDA LOW, raise SCL
    S_STOP2      = 4'd8    // Release SDA while SCL=HIGH (STOP)
} state_t;

state_t state;

// ============================================================
// Internal registers
// ============================================================
logic [8:0]  clk_cnt;       // Quarter-period counter
logic [3:0]  bit_cnt;       // Bit counter (0-7 for data, 0-7 for address)
logic [7:0]  shift_reg;     // TX/RX shift register
logic        scl_phase;     // 0=SCL LOW half, 1=SCL HIGH half
logic        saved_rw;      // Latched R/W direction
logic [6:0]  saved_addr;    // Latched address
logic [7:0]  saved_data;    // Latched write data

// ============================================================
// Quarter-period tick
// ============================================================
logic tick;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt <= 0;
    end else begin
        if (clk_cnt == QUART_PERIOD - 1) begin
            clk_cnt <= 0;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end
end
assign tick = (clk_cnt == QUART_PERIOD - 1);

// ============================================================
// Main FSM
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= S_IDLE;
        scl_oe     <= 1'b0;   // Release SCL (HIGH via pull-up)
        sda_oe     <= 1'b0;   // Release SDA (HIGH via pull-up)
        done       <= 1'b0;
        ack_err    <= 1'b0;
        bit_cnt    <= 0;
        shift_reg  <= 0;
        rd_data    <= 0;
        scl_phase  <= 0;
    end else begin

        done    <= 1'b0;
        ack_err <= 1'b0;

        case (state)

            // ------------------------------------------------
            S_IDLE: begin
                scl_oe <= 1'b0;  // Release both lines
                sda_oe <= 1'b0;
                if (start) begin
                    saved_rw   <= rw;
                    saved_addr <= addr;
                    saved_data <= wr_data;
                    state      <= S_START;
                end
            end

            // ------------------------------------------------
            // START: pull SDA LOW while SCL is HIGH
            S_START: begin
                scl_oe <= 1'b0;    // SCL stays HIGH (released)
                sda_oe <= 1'b1;    // Pull SDA LOW
                if (tick) begin
                    state <= S_START2;
                end
            end

            // ------------------------------------------------
            // Now pull SCL LOW, prepare to send address
            S_START2: begin
                scl_oe   <= 1'b1;  // Pull SCL LOW
                sda_oe   <= 1'b1;  // Keep SDA LOW
                if (tick) begin
                    // Load address + R/W into shift register
                    // Format: [addr6, addr5, addr4, addr3, addr2, addr1, addr0, rw]
                    shift_reg <= {saved_addr, saved_rw};
                    bit_cnt   <= 0;
                    state     <= S_ADDR;
                end
            end

            // ------------------------------------------------
            // Send 8 bits (7-bit address + R/W), MSB first
            S_ADDR: begin
                if (tick) begin
                    if (!scl_phase) begin
                        // SCL LOW half: put bit on SDA
                        sda_oe    <= ~shift_reg[7];  // OE=1 drives LOW, OE=0 releases HIGH
                        shift_reg <= {shift_reg[6:0], 1'b0};  // Shift left
                        scl_oe    <= 1'b0;           // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        // SCL HIGH half: check for clock stretching, then pull SCL LOW
                        if (scl_in == 1'b1) begin    // Slave not stretching
                            scl_oe    <= 1'b1;       // Pull SCL LOW
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_ADDR_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                        // If scl_in=0, slave stretching — stay here and wait
                    end
                end
            end

            // ------------------------------------------------
            // Address ACK phase: release SDA, slave should pull it LOW
            S_ADDR_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release SDA for slave to ACK
                        scl_oe    <= 1'b0;   // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            // Sample SDA — LOW=ACK, HIGH=NACK
                            if (sda_in == 1'b1) begin
                                // NACK — abort
                                ack_err <= 1'b1;
                                state   <= S_STOP1;
                            end else begin
                                // ACK received — load data, move to data phase
                                shift_reg <= saved_data;
                                bit_cnt   <= 0;
                                state     <= S_DATA;
                            end
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Send data byte (write mode) — same structure as ADDR
            S_DATA: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= ~shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_DATA_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Data ACK: read slave response
            S_DATA_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release for slave ACK
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            if (sda_in == 1'b1)
                                ack_err <= 1'b1;   // NACK from slave
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            state     <= S_STOP1;  // Single byte — go to stop
                        end
                    end
                end
            end

            // ------------------------------------------------
            // STOP: pull SDA LOW, raise SCL, then release SDA
            S_STOP1: begin
                if (tick) begin
                    sda_oe <= 1'b1;    // Pull SDA LOW
                    scl_oe <= 1'b0;    // Release SCL (goes HIGH)
                    state  <= S_STOP2;
                end
            end

            S_STOP2: begin
                if (tick) begin
                    sda_oe <= 1'b0;   // Release SDA — STOP condition!
                    done   <= 1'b1;
                    state  <= S_IDLE;
                end
            end

        endcase
    end
end

endmodule// ============================================================
// I2C Master — Write and Read transactions
// Supports clock stretching detection
// Standard mode: 100 kHz SCL with 50 MHz system clock
// ============================================================

module i2c_master #(
    parameter CLK_FREQ  = 50_000_000,
    parameter I2C_FREQ  = 100_000        // 100 kHz standard mode
)(
    input  logic        clk,
    input  logic        rst_n,

    // User interface
    input  logic        start,           // Pulse to begin transaction
    input  logic        rw,              // 0=write, 1=read
    input  logic [6:0]  addr,            // 7-bit slave address
    input  logic [7:0]  wr_data,         // Data to write
    output logic [7:0]  rd_data,         // Data read from slave
    output logic        done,            // Transaction complete
    output logic        ack_err,         // NACK received when ACK expected

    // I2C bus (open-drain — drive LOW or release)
    output logic        scl_oe,          // 1 = pull SCL LOW, 0 = release
    output logic        sda_oe,          // 1 = pull SDA LOW, 0 = release
    input  logic        scl_in,          // Read back SCL (for stretch detect)
    input  logic        sda_in           // Read back SDA (for ACK detect)
);

// ============================================================
// How open-drain works in RTL:
// scl_oe=1 → your output buffer drives SCL LOW
// scl_oe=0 → your output buffer is high-Z, pull-up makes it HIGH
// Same for sda_oe/sda_in
// On an FPGA: inout port + assign pad = oe ? 1'b0 : 1'bz
// ============================================================

localparam HALF_PERIOD  = CLK_FREQ / (2 * I2C_FREQ);  // 250 clocks
localparam QUART_PERIOD = HALF_PERIOD / 2;              // 125 clocks

// ============================================================
// State machine
// ============================================================
typedef enum logic [3:0] {
    S_IDLE       = 4'd0,
    S_START      = 4'd1,   // SDA falls, SCL still HIGH
    S_START2     = 4'd2,   // Pull SCL LOW after START
    S_ADDR       = 4'd3,   // Send 7-bit address + R/W
    S_ADDR_ACK   = 4'd4,   // Release SDA, read ACK
    S_DATA       = 4'd5,   // Send or receive 8 data bits
    S_DATA_ACK   = 4'd6,   // ACK phase after data byte
    S_STOP1      = 4'd7,   // Pull SDA LOW, raise SCL
    S_STOP2      = 4'd8    // Release SDA while SCL=HIGH (STOP)
} state_t;

state_t state;

// ============================================================
// Internal registers
// ============================================================
logic [8:0]  clk_cnt;       // Quarter-period counter
logic [3:0]  bit_cnt;       // Bit counter (0-7 for data, 0-7 for address)
logic [7:0]  shift_reg;     // TX/RX shift register
logic        scl_phase;     // 0=SCL LOW half, 1=SCL HIGH half
logic        saved_rw;      // Latched R/W direction
logic [6:0]  saved_addr;    // Latched address
logic [7:0]  saved_data;    // Latched write data

// ============================================================
// Quarter-period tick
// ============================================================
logic tick;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt <= 0;
    end else begin
        if (clk_cnt == QUART_PERIOD - 1) begin
            clk_cnt <= 0;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end
end
assign tick = (clk_cnt == QUART_PERIOD - 1);

// ============================================================
// Main FSM
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= S_IDLE;
        scl_oe     <= 1'b0;   // Release SCL (HIGH via pull-up)
        sda_oe     <= 1'b0;   // Release SDA (HIGH via pull-up)
        done       <= 1'b0;
        ack_err    <= 1'b0;
        bit_cnt    <= 0;
        shift_reg  <= 0;
        rd_data    <= 0;
        scl_phase  <= 0;
    end else begin

        done    <= 1'b0;
        ack_err <= 1'b0;

        case (state)

            // ------------------------------------------------
            S_IDLE: begin
                scl_oe <= 1'b0;  // Release both lines
                sda_oe <= 1'b0;
                if (start) begin
                    saved_rw   <= rw;
                    saved_addr <= addr;
                    saved_data <= wr_data;
                    state      <= S_START;
                end
            end

            // ------------------------------------------------
            // START: pull SDA LOW while SCL is HIGH
            S_START: begin
                scl_oe <= 1'b0;    // SCL stays HIGH (released)
                sda_oe <= 1'b1;    // Pull SDA LOW
                if (tick) begin
                    state <= S_START2;
                end
            end

            // ------------------------------------------------
            // Now pull SCL LOW, prepare to send address
            S_START2: begin
                scl_oe   <= 1'b1;  // Pull SCL LOW
                sda_oe   <= 1'b1;  // Keep SDA LOW
                if (tick) begin
                    // Load address + R/W into shift register
                    // Format: [addr6, addr5, addr4, addr3, addr2, addr1, addr0, rw]
                    shift_reg <= {saved_addr, saved_rw};
                    bit_cnt   <= 0;
                    state     <= S_ADDR;
                end
            end

            // ------------------------------------------------
            // Send 8 bits (7-bit address + R/W), MSB first
            S_ADDR: begin
                if (tick) begin
                    if (!scl_phase) begin
                        // SCL LOW half: put bit on SDA
                        sda_oe    <= ~shift_reg[7];  // OE=1 drives LOW, OE=0 releases HIGH
                        shift_reg <= {shift_reg[6:0], 1'b0};  // Shift left
                        scl_oe    <= 1'b0;           // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        // SCL HIGH half: check for clock stretching, then pull SCL LOW
                        if (scl_in == 1'b1) begin    // Slave not stretching
                            scl_oe    <= 1'b1;       // Pull SCL LOW
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_ADDR_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                        // If scl_in=0, slave stretching — stay here and wait
                    end
                end
            end

            // ------------------------------------------------
            // Address ACK phase: release SDA, slave should pull it LOW
            S_ADDR_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release SDA for slave to ACK
                        scl_oe    <= 1'b0;   // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            // Sample SDA — LOW=ACK, HIGH=NACK
                            if (sda_in == 1'b1) begin
                                // NACK — abort
                                ack_err <= 1'b1;
                                state   <= S_STOP1;
                            end else begin
                                // ACK received — load data, move to data phase
                                shift_reg <= saved_data;
                                bit_cnt   <= 0;
                                state     <= S_DATA;
                            end
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Send data byte (write mode) — same structure as ADDR
            S_DATA: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= ~shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_DATA_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Data ACK: read slave response
            S_DATA_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release for slave ACK
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            if (sda_in == 1'b1)
                                ack_err <= 1'b1;   // NACK from slave
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            state     <= S_STOP1;  // Single byte — go to stop
                        end
                    end
                end
            end

            // ------------------------------------------------
            // STOP: pull SDA LOW, raise SCL, then release SDA
            S_STOP1: begin
                if (tick) begin
                    sda_oe <= 1'b1;    // Pull SDA LOW
                    scl_oe <= 1'b0;    // Release SCL (goes HIGH)
                    state  <= S_STOP2;
                end
            end

            S_STOP2: begin
                if (tick) begin
                    sda_oe <= 1'b0;   // Release SDA — STOP condition!
                    done   <= 1'b1;
                    state  <= S_IDLE;
                end
            end

        endcase
    end
end

endmodule// ============================================================
// I2C Master — Write and Read transactions
// Supports clock stretching detection
// Standard mode: 100 kHz SCL with 50 MHz system clock
// ============================================================

module i2c_master #(
    parameter CLK_FREQ  = 50_000_000,
    parameter I2C_FREQ  = 100_000        // 100 kHz standard mode
)(
    input  logic        clk,
    input  logic        rst_n,

    // User interface
    input  logic        start,           // Pulse to begin transaction
    input  logic        rw,              // 0=write, 1=read
    input  logic [6:0]  addr,            // 7-bit slave address
    input  logic [7:0]  wr_data,         // Data to write
    output logic [7:0]  rd_data,         // Data read from slave
    output logic        done,            // Transaction complete
    output logic        ack_err,         // NACK received when ACK expected

    // I2C bus (open-drain — drive LOW or release)
    output logic        scl_oe,          // 1 = pull SCL LOW, 0 = release
    output logic        sda_oe,          // 1 = pull SDA LOW, 0 = release
    input  logic        scl_in,          // Read back SCL (for stretch detect)
    input  logic        sda_in           // Read back SDA (for ACK detect)
);

// ============================================================
// How open-drain works in RTL:
// scl_oe=1 → your output buffer drives SCL LOW
// scl_oe=0 → your output buffer is high-Z, pull-up makes it HIGH
// Same for sda_oe/sda_in
// On an FPGA: inout port + assign pad = oe ? 1'b0 : 1'bz
// ============================================================

localparam HALF_PERIOD  = CLK_FREQ / (2 * I2C_FREQ);  // 250 clocks
localparam QUART_PERIOD = HALF_PERIOD / 2;              // 125 clocks

// ============================================================
// State machine
// ============================================================
typedef enum logic [3:0] {
    S_IDLE       = 4'd0,
    S_START      = 4'd1,   // SDA falls, SCL still HIGH
    S_START2     = 4'd2,   // Pull SCL LOW after START
    S_ADDR       = 4'd3,   // Send 7-bit address + R/W
    S_ADDR_ACK   = 4'd4,   // Release SDA, read ACK
    S_DATA       = 4'd5,   // Send or receive 8 data bits
    S_DATA_ACK   = 4'd6,   // ACK phase after data byte
    S_STOP1      = 4'd7,   // Pull SDA LOW, raise SCL
    S_STOP2      = 4'd8    // Release SDA while SCL=HIGH (STOP)
} state_t;

state_t state;

// ============================================================
// Internal registers
// ============================================================
logic [8:0]  clk_cnt;       // Quarter-period counter
logic [3:0]  bit_cnt;       // Bit counter (0-7 for data, 0-7 for address)
logic [7:0]  shift_reg;     // TX/RX shift register
logic        scl_phase;     // 0=SCL LOW half, 1=SCL HIGH half
logic        saved_rw;      // Latched R/W direction
logic [6:0]  saved_addr;    // Latched address
logic [7:0]  saved_data;    // Latched write data

// ============================================================
// Quarter-period tick
// ============================================================
logic tick;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt <= 0;
    end else begin
        if (clk_cnt == QUART_PERIOD - 1) begin
            clk_cnt <= 0;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end
end
assign tick = (clk_cnt == QUART_PERIOD - 1);

// ============================================================
// Main FSM
// ============================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= S_IDLE;
        scl_oe     <= 1'b0;   // Release SCL (HIGH via pull-up)
        sda_oe     <= 1'b0;   // Release SDA (HIGH via pull-up)
        done       <= 1'b0;
        ack_err    <= 1'b0;
        bit_cnt    <= 0;
        shift_reg  <= 0;
        rd_data    <= 0;
        scl_phase  <= 0;
    end else begin

        done    <= 1'b0;
        ack_err <= 1'b0;

        case (state)

            // ------------------------------------------------
            S_IDLE: begin
                scl_oe <= 1'b0;  // Release both lines
                sda_oe <= 1'b0;
                if (start) begin
                    saved_rw   <= rw;
                    saved_addr <= addr;
                    saved_data <= wr_data;
                    state      <= S_START;
                end
            end

            // ------------------------------------------------
            // START: pull SDA LOW while SCL is HIGH
            S_START: begin
                scl_oe <= 1'b0;    // SCL stays HIGH (released)
                sda_oe <= 1'b1;    // Pull SDA LOW
                if (tick) begin
                    state <= S_START2;
                end
            end

            // ------------------------------------------------
            // Now pull SCL LOW, prepare to send address
            S_START2: begin
                scl_oe   <= 1'b1;  // Pull SCL LOW
                sda_oe   <= 1'b1;  // Keep SDA LOW
                if (tick) begin
                    // Load address + R/W into shift register
                    // Format: [addr6, addr5, addr4, addr3, addr2, addr1, addr0, rw]
                    shift_reg <= {saved_addr, saved_rw};
                    bit_cnt   <= 0;
                    state     <= S_ADDR;
                end
            end

            // ------------------------------------------------
            // Send 8 bits (7-bit address + R/W), MSB first
            S_ADDR: begin
                if (tick) begin
                    if (!scl_phase) begin
                        // SCL LOW half: put bit on SDA
                        sda_oe    <= ~shift_reg[7];  // OE=1 drives LOW, OE=0 releases HIGH
                        shift_reg <= {shift_reg[6:0], 1'b0};  // Shift left
                        scl_oe    <= 1'b0;           // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        // SCL HIGH half: check for clock stretching, then pull SCL LOW
                        if (scl_in == 1'b1) begin    // Slave not stretching
                            scl_oe    <= 1'b1;       // Pull SCL LOW
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_ADDR_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                        // If scl_in=0, slave stretching — stay here and wait
                    end
                end
            end

            // ------------------------------------------------
            // Address ACK phase: release SDA, slave should pull it LOW
            S_ADDR_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release SDA for slave to ACK
                        scl_oe    <= 1'b0;   // Release SCL (goes HIGH)
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            // Sample SDA — LOW=ACK, HIGH=NACK
                            if (sda_in == 1'b1) begin
                                // NACK — abort
                                ack_err <= 1'b1;
                                state   <= S_STOP1;
                            end else begin
                                // ACK received — load data, move to data phase
                                shift_reg <= saved_data;
                                bit_cnt   <= 0;
                                state     <= S_DATA;
                            end
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Send data byte (write mode) — same structure as ADDR
            S_DATA: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= ~shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            if (bit_cnt == 7) begin
                                state   <= S_DATA_ACK;
                                bit_cnt <= 0;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
            end

            // ------------------------------------------------
            // Data ACK: read slave response
            S_DATA_ACK: begin
                if (tick) begin
                    if (!scl_phase) begin
                        sda_oe    <= 1'b0;   // Release for slave ACK
                        scl_oe    <= 1'b0;
                        scl_phase <= 1'b1;
                    end else begin
                        if (scl_in == 1'b1) begin
                            if (sda_in == 1'b1)
                                ack_err <= 1'b1;   // NACK from slave
                            scl_oe    <= 1'b1;
                            scl_phase <= 1'b0;
                            state     <= S_STOP1;  // Single byte — go to stop
                        end
                    end
                end
            end

            // ------------------------------------------------
            // STOP: pull SDA LOW, raise SCL, then release SDA
            S_STOP1: begin
                if (tick) begin
                    sda_oe <= 1'b1;    // Pull SDA LOW
                    scl_oe <= 1'b0;    // Release SCL (goes HIGH)
                    state  <= S_STOP2;
                end
            end

            S_STOP2: begin
                if (tick) begin
                    sda_oe <= 1'b0;   // Release SDA — STOP condition!
                    done   <= 1'b1;
                    state  <= S_IDLE;
                end
            end

        endcase
    end
end

endmodule