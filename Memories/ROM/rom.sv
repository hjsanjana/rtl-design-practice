module rom #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 8,
    parameter int ADDR_WIDTH = 3
)(
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] rdata
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Load memory from file
    initial begin
        $readmemh("rom_data.mem", mem);
    end

    // Synchronous read
    always_ff @(posedge clk) begin
        rdata <= mem[addr];
    end

endmodule