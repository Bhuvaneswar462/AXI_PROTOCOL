`timescale 1ns/1ps

module top_axi_ace #(
    parameter int MEM_WORDS = 64
)(
    input  logic clk,
    input  logic rst_n,

    // AXI
    input  logic        AWVALID,
    output logic        AWREADY,
    input  logic [31:0] AWADDR,

    input  logic        WVALID,
    output logic        WREADY,
    input  logic [31:0] WDATA,
    input  logic        WLAST,

    output logic        BVALID,
    input  logic        BREADY,
    output logic [1:0]  BRESP,

    input  logic        ARVALID,
    output logic        ARREADY,
    input  logic [31:0] ARADDR,

    output logic        RVALID,
    input  logic        RREADY,
    output logic [31:0] RDATA,
    output logic [1:0]  RRESP,
    output logic        RLAST,

    // ACE
    input  logic        ACVALID,
    output logic        ACREADY,
    input  logic [31:0] ACADDR,
    input  logic [2:0]  ACSNOOP,

    output logic        CRVALID,
    input  logic        CRREADY,
    output logic [4:0]  CRRESP,

    output logic        CDVALID,
    input  logic        CDREADY,
    output logic [31:0] CDDATA
);

    // cache core wires
    logic axi_rd_req, axi_rd_ack;
    logic [31:0] axi_rd_addr, axi_rd_data;

    logic axi_wr_req, axi_wr_ack;
    logic [31:0] axi_wr_addr, axi_wr_data;

    logic sn_req, sn_ack;
    logic [31:0] sn_addr;
    logic [2:0]  sn_snoop;

    logic [4:0]  sn_crresp;
    logic sn_need_cd, sn_inv_after_cd;

    logic sn_cd_next;
    logic [31:0] sn_cd_data;
    logic sn_cd_last;

    // AXI module
    axi4_slave_if u_axi (
        .clk(clk), .rst_n(rst_n),

        .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR),
        .WVALID(WVALID), .WREADY(WREADY), .WDATA(WDATA), .WLAST(WLAST),
        .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP),

        .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR),
        .RVALID(RVALID), .RREADY(RREADY), .RDATA(RDATA), .RRESP(RRESP), .RLAST(RLAST),

        .axi_rd_req(axi_rd_req), .axi_rd_addr(axi_rd_addr),
        .axi_rd_ack(axi_rd_ack), .axi_rd_data(axi_rd_data),

        .axi_wr_req(axi_wr_req), .axi_wr_addr(axi_wr_addr), .axi_wr_data(axi_wr_data),
        .axi_wr_ack(axi_wr_ack)
    );

    // ACE module
    ace_snoop_if u_ace (
        .clk(clk), .rst_n(rst_n),

        .ACVALID(ACVALID), .ACREADY(ACREADY), .ACADDR(ACADDR), .ACSNOOP(ACSNOOP),
        .CRVALID(CRVALID), .CRREADY(CRREADY), .CRRESP(CRRESP),
        .CDVALID(CDVALID), .CDREADY(CDREADY), .CDDATA(CDDATA),

        .sn_req(sn_req), .sn_addr(sn_addr), .sn_snoop(sn_snoop), .sn_ack(sn_ack),

        .sn_crresp(sn_crresp), .sn_need_cd(sn_need_cd),
        .sn_inv_after_cd(sn_inv_after_cd),

        .sn_cd_next(sn_cd_next),
        .sn_cd_data(sn_cd_data),
        .sn_cd_last(sn_cd_last)
    );

    // Cache core
    cache_core_mesi_singleline #(.MEM_WORDS(MEM_WORDS)) u_core (
        .clk(clk), .rst_n(rst_n),

        .axi_rd_req(axi_rd_req),
        .axi_rd_addr(axi_rd_addr),
        .axi_rd_ack(axi_rd_ack),
        .axi_rd_data(axi_rd_data),

        .axi_wr_req(axi_wr_req),
        .axi_wr_addr(axi_wr_addr),
        .axi_wr_data(axi_wr_data),
        .axi_wr_ack(axi_wr_ack),

        .sn_req(sn_req),
        .sn_addr(sn_addr),
        .sn_snoop(sn_snoop),
        .sn_ack(sn_ack),

        .sn_crresp(sn_crresp),
        .sn_need_cd(sn_need_cd),
        .sn_inv_after_cd(sn_inv_after_cd),

        .sn_cd_next(sn_cd_next),
        .sn_cd_data(sn_cd_data),
        .sn_cd_last(sn_cd_last)
    );

endmodule
