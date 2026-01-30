module axi_ace_single_mem (
    input         clk,
    input         rst_n,

    // ---------- AXI WRITE ----------
    input         awvalid,
    output reg    awready,
    input  [5:0]  awaddr,

    input         wvalid,
    output reg    wready,
    input  [31:0] wdata,

    output reg    bvalid,
    input         bready,

    // ---------- AXI READ ----------
    input         arvalid,
    output reg    arready,
    input  [5:0]  araddr,

    output reg        rvalid,
    input             rready,
    output reg [31:0] rdata,

    // ---------- ACE SNOOP ----------
    input         acvalid,
    output reg    acready,
    input  [5:0]  acaddr,

    output reg    crvalid,
    input         crready
);

    // single shared memory
    reg [31:0] mem [0:63];

    // -------------------------------
    // WRITE FSM (AW+W+B combined)
    // -------------------------------
    localparam W_IDLE = 2'd0,
               W_RESP = 2'd1;

    reg [1:0] wstate;

    // -------------------------------
    // READ FSM (AR+R combined)
    // -------------------------------
    localparam R_IDLE = 2'd0,
               R_DATA = 2'd1;

    reg [1:0] rstate;

    // -------------------------------
    // ACE SNOOP FSM
    // -------------------------------
    localparam C_IDLE = 2'd0,
               C_RESP = 2'd1;

    reg [1:0] cstate;

    // -------------------------------
    // Main sequential logic
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // resets
            awready <= 0; wready <= 0; bvalid <= 0;
            arready <= 0; rvalid <= 0; rdata <= 0;
            acready <= 0; crvalid <= 0;

            wstate <= W_IDLE;
            rstate <= R_IDLE;
            cstate <= C_IDLE;
        end
        else begin
            // default deassert
            awready <= 0;
            wready  <= 0;
            arready <= 0;
            acready <= 0;

            // -------------------------
            // ACE SNOOP (highest prio)
            // -------------------------
            case (cstate)
            C_IDLE: begin
                if (acvalid) begin
                    acready <= 1;
                    // invalidate memory line
                    mem[acaddr] <= 32'h0;
                    cstate <= C_RESP;
                end
            end

            C_RESP: begin
                crvalid <= 1;
                if (crready) begin
                    crvalid <= 0;
                    cstate  <= C_IDLE;
                end
            end
            endcase

            // -------------------------
            // WRITE CHANNEL
            // -------------------------
            case (wstate)
            W_IDLE: begin
                if (awvalid && wvalid && !acvalid) begin
                    awready <= 1;
                    wready  <= 1;

                    // write to same single memory
                    mem[awaddr] <= wdata;

                    bvalid <= 1;
                    wstate <= W_RESP;
                end
            end

            W_RESP: begin
                if (bready) begin
                    bvalid <= 0;
                    wstate <= W_IDLE;
                end
            end
            endcase

            // -------------------------
            // READ CHANNEL
            // -------------------------
            case (rstate)
            R_IDLE: begin
                if (arvalid && !acvalid) begin
                    arready <= 1;
                    rdata   <= mem[araddr];
                    rvalid  <= 1;
                    rstate  <= R_DATA;
                end
            end

            R_DATA: begin
                if (rready) begin
                    rvalid <= 0;
                    rstate <= R_IDLE;
                end
            end
            endcase
        end
    end
endmodule
