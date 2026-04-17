module fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 8,
    parameter int ADDR_WIDTH = 3
)(
    input  logic clk,
    input  logic rst_n,

    input  logic wr_en,
    input  logic rd_en,

    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata,

    output logic full,
    output logic empty
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;

    // Write pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 0;
        else if (wr_en && !full)
            wr_ptr <= wr_ptr + 1;
    end

    // Read pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= 0;
        else if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1;
    end

    // Write logic
    always_ff @(posedge clk) begin
        if (wr_en && !full)
            mem[wr_ptr] <= wdata;
    end

    // Read logic
    always_ff @(posedge clk) begin
        if (rd_en && !empty)
            rdata <= mem[rd_ptr];
    end

    // Status logic
    assign empty = (wr_ptr == rd_ptr);
    assign full  = ((wr_ptr + 1) == rd_ptr);

endmodule