`timescale 1ns/1ps

module axi4_slave_if (
    input  logic clk,
    input  logic rst_n,

    // AXI write address
    input  logic        AWVALID,
    output logic        AWREADY,
    input  logic [31:0] AWADDR,

    // AXI write data
    input  logic        WVALID,
    output logic        WREADY,
    input  logic [31:0] WDATA,
    input  logic        WLAST,

    // AXI write response
    output logic        BVALID,
    input  logic        BREADY,
    output logic [1:0]  BRESP,

    // AXI read address
    input  logic        ARVALID,
    output logic        ARREADY,
    input  logic [31:0] ARADDR,

    // AXI read data
    output logic        RVALID,
    input  logic        RREADY,
    output logic [31:0] RDATA,
    output logic [1:0]  RRESP,
    output logic        RLAST,

    // To cache core
    output logic        axi_rd_req,
    output logic [31:0] axi_rd_addr,
    input  logic        axi_rd_ack,
    input  logic [31:0] axi_rd_data,

    output logic        axi_wr_req,
    output logic [31:0] axi_wr_addr,
    output logic [31:0] axi_wr_data,
    input  logic        axi_wr_ack
);

    typedef enum logic [1:0] { W_IDLE, W_DATA, W_WAIT_ACK, W_RESP } wst_t;
    typedef enum logic [1:0] { R_IDLE, R_REQ, R_WAIT, R_SEND }      rst_t;

    wst_t wst;
    rst_t rst;

    logic [31:0] aw_lat;
    logic [31:0] ar_lat;
    logic [31:0] wdata_lat;

    //==============================
    // combinational defaults
    //==============================
    always_comb begin
        AWREADY = 1'b0;
        WREADY  = 1'b0;
        ARREADY = 1'b0;

        axi_rd_req  = 1'b0;
        axi_wr_req  = 1'b0;

        axi_rd_addr = ar_lat;
        axi_wr_addr = aw_lat;
        axi_wr_data = wdata_lat;

        BRESP = 2'b00;
        RRESP = 2'b00;
    end

    //==============================
    // WRITE FSM
    //==============================
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wst <= W_IDLE;
            aw_lat <= 32'h0;
            wdata_lat <= 32'h0;

            BVALID <= 1'b0;
        end else begin

            unique case (wst)

                W_IDLE: begin
                    BVALID <= 1'b0;

                    AWREADY <= 1'b1;
                    if (AWVALID && AWREADY) begin
                        aw_lat <= AWADDR;
                        wst <= W_DATA;
                    end
                end

                W_DATA: begin
                    WREADY <= 1'b1;
                    if (WVALID && WREADY) begin
                        wdata_lat <= WDATA;
                        wst <= W_WAIT_ACK;
                    end
                end

                // issue 1-cycle req pulse, then wait for ack
                W_WAIT_ACK: begin
                    axi_wr_req <= 1'b1;
                    if (axi_wr_ack) begin
                        BVALID <= 1'b1;
                        wst <= W_RESP;
                    end
                end

                W_RESP: begin
                    if (BVALID && BREADY) begin
                        BVALID <= 1'b0;
                        wst <= W_IDLE;
                    end
                end

                default: wst <= W_IDLE;
            endcase
        end
    end

    //==============================
    // READ FSM
    //==============================
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rst <= R_IDLE;
            ar_lat <= 32'h0;

            RVALID <= 1'b0;
            RDATA  <= 32'h0;
            RLAST  <= 1'b0;

        end else begin

            unique case (rst)

                R_IDLE: begin
                    RVALID <= 1'b0;
                    RLAST  <= 1'b0;

                    ARREADY <= 1'b1;
                    if (ARVALID && ARREADY) begin
                        ar_lat <= ARADDR;
                        rst <= R_REQ;
                    end
                end

                // pulse req
                R_REQ: begin
                    axi_rd_req <= 1'b1;
                    rst <= R_WAIT;
                end

                // wait for cache core ack
                R_WAIT: begin
                    if (axi_rd_ack) begin
                        RDATA  <= axi_rd_data;
                        RVALID <= 1'b1;
                        RLAST  <= 1'b1;
                        rst <= R_SEND;
                    end
                end

                // wait for master to accept
                R_SEND: begin
                    if (RVALID && RREADY) begin
                        RVALID <= 1'b0;
                        RLAST  <= 1'b0;
                        rst <= R_IDLE;
                    end
                end

                default: rst <= R_IDLE;
            endcase
        end
    end

endmodule
