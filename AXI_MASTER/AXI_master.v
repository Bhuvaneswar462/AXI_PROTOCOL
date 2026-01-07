`timescale 1ns/1ps
module axi4_master (
    input  wire        ACLK,
    input  wire        ARESETn,

    // WRITE ADDRESS
    output reg [31:0]  AWADDR,
    output reg [7:0]   AWLEN,
    output reg         AWVALID,
    input  wire        AWREADY,

    // WRITE DATA
    output reg [31:0]  WDATA,
    output reg         WLAST,
    output reg         WVALID,
    input  wire        WREADY,

    // WRITE RESPONSE
    input  wire        BVALID,
    output reg         BREADY,

    // READ ADDRESS
    output reg [31:0]  ARADDR,
    output reg [7:0]   ARLEN,
    output reg         ARVALID,
    input  wire        ARREADY,

    // READ DATA
    input  wire [31:0] RDATA,
    input  wire        RLAST,
    input  wire        RVALID,
    output reg         RREADY
);

    integer i;

    initial begin
        AWVALID = 0; WVALID = 0; BREADY = 0;
        ARVALID = 0; RREADY = 0; WLAST = 0;

        wait(ARESETn);

        // ---------------- WRITE BURST ----------------
        #10;
        AWADDR  = 32'h0000_0000;
        AWLEN   = 3;        // 4 beats
        AWVALID = 1;

        wait(AWREADY);
        AWVALID = 0;

        for (i = 0; i <= AWLEN; i = i + 1) begin
            WDATA  = 32'h100 + i;
            WVALID = 1;
            WLAST  = (i == AWLEN);
            wait(WREADY);
            #10;
        end

        WVALID = 0;
        WLAST  = 0;

        BREADY = 1;
        wait(BVALID);
        BREADY = 0;

        // ---------------- READ BURST ----------------
        #20;
        ARADDR  = 32'h0000_0000;
        ARLEN   = 3;
        ARVALID = 1;
        RREADY  = 1;

        wait(ARREADY);
        ARVALID = 0;

        wait(RLAST);
        RREADY = 0;
    end
endmodule
