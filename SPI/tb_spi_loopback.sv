`timescale 1ns/1ps

module tb_spi_loopback;

logic       clk, rst_n, start, done;
logic [7:0] mosi_data, miso_data;
logic [7:0] slave_rx, slave_tx;
logic       slave_done;
logic       sclk, mosi, miso, cs_n;

// Master
spi_master #(.CLK_DIV(4)) u_master (
    .clk(clk), .rst_n(rst_n),
    .start(start), .mosi_data(mosi_data),
    .miso_data(miso_data),
    .sclk(sclk), .mosi(mosi), .miso(miso),
    .cs_n(cs_n), .done(done)
);

// Slave — tx_data is what it sends back
spi_slave u_slave (
    .clk(clk), .rst_n(rst_n),
    .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n),
    .tx_data(8'hBC),     // Slave always sends back 0xBC
    .rx_data(slave_rx),
    .rx_done(slave_done)
);

initial clk = 0;
always #10 clk = ~clk;   // 50 MHz

initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb_spi_loopback);
    rst_n = 0; start = 0; mosi_data = 0;
    repeat(5) @(posedge clk); rst_n = 1;
    repeat(3) @(posedge clk);

    // Send 0xA5 to slave, expect slave to send back 0xBC
    mosi_data = 8'hA5;
    start = 1; @(posedge clk); start = 0;
    wait(done);

    $display("Master sent:     0x%0h", 8'hA5);
    $display("Master received: 0x%0h", miso_data);
    $display("Slave received:  0x%0h", slave_rx);

    if (miso_data == 8'hBC && slave_rx == 8'hA5)
        $display("PASS: Full duplex SPI loopback correct");
    else
        $display("FAIL: Data mismatch");

    repeat(10) @(posedge clk);
    $finish;
end

endmodule