module stack #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 8,
    parameter int ADDR_WIDTH = 3
)(
    input  logic clk,
    input  logic rst_n,

    input  logic push,
    input  logic pop,

    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata,

    output logic full,
    output logic empty
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_WIDTH:0] sp; // stack pointer

    // Stack pointer update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sp <= 0;
        else begin
            if (push && !full)
                sp <= sp + 1;
            else if (pop && !empty)
                sp <= sp - 1;
        end
    end

    // Write logic (push)
    always_ff @(posedge clk) begin
        if (push && !full)
            mem[sp] <= wdata;
    end

    // Read logic (pop)
    always_ff @(posedge clk) begin
        if (pop && !empty)
            rdata <= mem[sp - 1];
    end

    // Status
    assign empty = (sp == 0);
    assign full  = (sp == DEPTH);

endmodule