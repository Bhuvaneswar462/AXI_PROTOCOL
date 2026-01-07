`timescale 1ns/1ps

module tb_axi4_master;

    reg ACLK;
    reg ARESETn;

    // AXI signals
    wire [31:0] AWADDR;
    wire [7:0]  AWLEN;
    wire        AWVALID;
    reg         AWREADY;

    wire [31:0] WDATA;
    wire        WLAST;
    wire        WVALID;
    reg         WREADY;

    reg         BVALID;
    wire        BREADY;

    wire [31:0] ARADDR;
    wire [7:0]  ARLEN;
    wire        ARVALID;
    reg         ARREADY;

    reg  [31:0] RDATA;
    reg         RLAST;
    reg         RVALID;
    wire        RREADY;

    // Clock
    always #5 ACLK = ~ACLK;

    // DUT
    axi4_master dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .AWADDR(AWADDR),
        .AWLEN(AWLEN),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),

        .WDATA(WDATA),
        .WLAST(WLAST),
        .WVALID(WVALID),
        .WREADY(WREADY),

        .BVALID(BVALID),
        .BREADY(BREADY),

        .ARADDR(ARADDR),
        .ARLEN(ARLEN),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        .RDATA(RDATA),
        .RLAST(RLAST),
        .RVALID(RVALID),
        .RREADY(RREADY)
    );

    initial begin
        // GTKWave dump
        $dumpfile("axi4_master.vcd");
        $dumpvars(0, tb_axi4_master);

        // Init
        ACLK = 0;
        ARESETn = 0;
        AWREADY = 0; WREADY = 0;
        BVALID  = 0;
        ARREADY = 0;
        RVALID  = 0; RLAST = 0;
        RDATA   = 32'h0;

        #20 ARESETn = 1;

        // Dummy AXI Slave behavior
        forever begin
            #10;
            AWREADY = AWVALID;
            WREADY  = WVALID;

            if (WLAST && WVALID) begin
                BVALID = 1;
                #10 BVALID = 0;
            end

            ARREADY = ARVALID;

            if (RREADY) begin
                RVALID = 1;
                RDATA  = 32'hDEAD_BEEF;
                RLAST  = 1;
                #10;
                RVALID = 0;
                RLAST  = 0;
            end
        end
    end

    initial begin
        #500 $finish;
    end
endmodule
