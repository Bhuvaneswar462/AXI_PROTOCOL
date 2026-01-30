`timescale 1ns/1ps
module tb_axi_ace;

reg clk = 0;
reg rst_n = 0;
always #5 clk = ~clk;

// ---------------- AXI WRITE ----------------
reg         awvalid = 0;
wire        awready;
reg  [5:0]  awaddr  = 0;

reg         wvalid  = 0;
wire        wready;
reg  [31:0] wdata   = 0;

wire        bvalid;
reg         bready  = 0;

// ---------------- AXI READ -----------------
reg         arvalid = 0;
wire        arready;
reg  [5:0]  araddr  = 0;

wire        rvalid;
reg         rready  = 0;
wire [31:0] rdata;

// ---------------- ACE SNOOP ----------------
reg         acvalid = 0;
wire        acready;
reg  [5:0]  acaddr  = 0;

wire        crvalid;
reg         crready = 0;

// ---------------- DUT ----------------------
axi_ace_single_mem dut(
    .clk(clk), .rst_n(rst_n),

    .awvalid(awvalid), .awready(awready), .awaddr(awaddr),
    .wvalid(wvalid),   .wready(wready),   .wdata(wdata),
    .bvalid(bvalid),   .bready(bready),

    .arvalid(arvalid), .arready(arready), .araddr(araddr),
    .rvalid(rvalid),   .rready(rready),   .rdata(rdata),

    .acvalid(acvalid), .acready(acready), .acaddr(acaddr),
    .crvalid(crvalid), .crready(crready)
);

// ------------------------------------------------
// Helper tasks
// ------------------------------------------------
task axi_write(input [5:0] addr, input [31:0] data);
begin
    @(posedge clk);
    awaddr  <= addr;
    wdata   <= data;
    awvalid <= 1;
    wvalid  <= 1;
    bready  <= 1;

    wait(awready && wready);
    @(posedge clk);
    awvalid <= 0;
    wvalid  <= 0;

    wait(bvalid);
    @(posedge clk);
    bready  <= 0;

    $display("[%0t] WRITE  addr=%0d data=%h", $time, addr, data);
end
endtask


task axi_read(input [5:0] addr, output [31:0] data_out);
begin
    @(posedge clk);
    araddr  <= addr;
    arvalid <= 1;
    rready  <= 1;

    wait(arready);
    @(posedge clk);
    arvalid <= 0;

    wait(rvalid);
    @(posedge clk);
    data_out = rdata;
    rready <= 0;

    $display("[%0t] READ   addr=%0d data=%h", $time, addr, data_out);
end
endtask


task ace_snoop(input [5:0] addr);
begin
    @(posedge clk);
    acaddr  <= addr;
    acvalid <= 1;
    crready <= 1;

    wait(acready);
    @(posedge clk);
    acvalid <= 0;

    wait(crvalid);
    @(posedge clk);
    crready <= 0;

    $display("[%0t] SNOOP invalidate addr=%0d", $time, addr);
end
endtask

// ------------------------------------------------
// Test sequence
// ------------------------------------------------
reg [31:0] rd;

initial begin
    $dumpfile("axi_ace_test.vcd");
    $dumpvars(0, tb_axi_ace);

    // reset
    #20 rst_n = 1;

    // 1) Write value
    axi_write(6'd5, 32'hDEADBEEF);

    // 2) Read back and check
    axi_read(6'd5, rd);
    if (rd !== 32'hDEADBEEF)
        $display("ERROR: read mismatch after write");
    else
        $display("PASS: write/read OK");

    // 3) Read stall test (rready low first)
    @(posedge clk);
    araddr  <= 6'd5;
    arvalid <= 1;
    rready  <= 0;

    wait(arready);
    @(posedge clk);
    arvalid <= 0;

    // rvalid should go high but data not accepted yet
    wait(rvalid);
    $display("[%0t] rvalid asserted, stalling (rready=0)", $time);

    repeat(3) @(posedge clk); // stall few cycles

    rready <= 1;
    @(posedge clk);
    rd = rdata;
    rready <= 0;
    $display("[%0t] READ after stall data=%h", $time, rd);

    // 4) ACE snoop invalidate same address
    ace_snoop(6'd5);

    // 5) Read again, should be zero
    axi_read(6'd5, rd);
    if (rd !== 32'h00000000)
        $display("ERROR: snoop did not invalidate");
    else
        $display("PASS: snoop invalidate OK");

    // 6) Write new value and read again
    axi_write(6'd5, 32'h12345678);
    axi_read(6'd5, rd);
    if (rd !== 32'h12345678)
        $display("ERROR: rewrite after snoop failed");
    else
        $display("PASS: rewrite after snoop OK");

    #50;
    $display("ALL TESTS COMPLETED");
    $finish;
end

endmodule
