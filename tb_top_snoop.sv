`timescale 1ns/1ps

module tb_top_snoop;

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;

    // AXI
    logic        AWVALID;
    logic        AWREADY;
    logic [31:0] AWADDR;

    logic        WVALID;
    logic        WREADY;
    logic [31:0] WDATA;
    logic        WLAST;

    logic        BVALID;
    logic        BREADY;
    logic [1:0]  BRESP;

    logic        ARVALID;
    logic        ARREADY;
    logic [31:0] ARADDR;

    logic        RVALID;
    logic        RREADY;
    logic [31:0] RDATA;
    logic [1:0]  RRESP;
    logic        RLAST;

    // ACE
    logic        ACVALID;
    logic        ACREADY;
    logic [31:0] ACADDR;
    logic [2:0]  ACSNOOP;

    logic        CRVALID;
    logic        CRREADY;
    logic [4:0]  CRRESP;

    logic        CDVALID;
    logic        CDREADY;
    logic [31:0] CDDATA;

    // DUT
    top_axi_ace #(.MEM_WORDS(64)) dut (
        .clk(clk),
        .rst_n(rst_n),

        .AWVALID(AWVALID), .AWREADY(AWREADY), .AWADDR(AWADDR),
        .WVALID(WVALID), .WREADY(WREADY), .WDATA(WDATA), .WLAST(WLAST),
        .BVALID(BVALID), .BREADY(BREADY), .BRESP(BRESP),

        .ARVALID(ARVALID), .ARREADY(ARREADY), .ARADDR(ARADDR),
        .RVALID(RVALID), .RREADY(RREADY), .RDATA(RDATA), .RRESP(RRESP), .RLAST(RLAST),

        .ACVALID(ACVALID), .ACREADY(ACREADY), .ACADDR(ACADDR), .ACSNOOP(ACSNOOP),
        .CRVALID(CRVALID), .CRREADY(CRREADY), .CRRESP(CRRESP),
        .CDVALID(CDVALID), .CDREADY(CDREADY), .CDDATA(CDDATA)
    );

    // snoop encodings (must match cache_core)
    localparam logic [2:0] SNOOP_ReadShared   = 3'd0;
    localparam logic [2:0] SNOOP_ReadUnique   = 3'd1;
    localparam logic [2:0] SNOOP_CleanInvalid = 3'd2;

    //==================================================
    // AXI write
    //==================================================
    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
        int guard;
        begin
            // AW
            AWADDR  = addr;
            AWVALID = 1;

            guard = 0;
            while (!(AWVALID && AWREADY)) begin
                @(posedge clk);
                guard++;
                if (guard > 200) $fatal(1, "❌ AW timeout addr=%h", addr);
            end
            @(posedge clk);
            AWVALID = 0;

            // W
            WDATA  = data;
            WLAST  = 1;
            WVALID = 1;

            guard = 0;
            while (!(WVALID && WREADY)) begin
                @(posedge clk);
                guard++;
                if (guard > 200) $fatal(1, "❌ W timeout addr=%h", addr);
            end
            @(posedge clk);
            WVALID = 0;
            WLAST  = 0;

            // B
            BREADY = 1;
            guard = 0;
            while (!(BVALID && BREADY)) begin
                @(posedge clk);
                guard++;
                if (guard > 200) $fatal(1, "❌ B timeout addr=%h", addr);
            end
            @(posedge clk);
            BREADY = 0;

            $display("✅ AXI WRITE addr=%h data=%h", addr, data);
        end
    endtask

    //==================================================
    // AXI read
    //==================================================
    task automatic axi_read(input logic [31:0] addr, output logic [31:0] data_out);
        int guard;
        begin
            // AR
            ARADDR  = addr;
            ARVALID = 1;

            guard = 0;
            while (!(ARVALID && ARREADY)) begin
                @(posedge clk);
                guard++;
                if (guard > 200) $fatal(1, "❌ AR timeout addr=%h", addr);
            end
            @(posedge clk);
            ARVALID = 0;

            // R
            RREADY = 1;

            guard = 0;
            while (!(RVALID && RREADY)) begin
                @(posedge clk);
                guard++;
                if (guard > 200) $fatal(1, "❌ R timeout addr=%h", addr);
            end

            data_out = RDATA;
            @(posedge clk);
            RREADY = 0;

            $display("✅ AXI READ  addr=%h data=%h", addr, data_out);
        end
    endtask

    //==================================================
    // ACE snoop
    //==================================================
    task automatic ace_snoop(
        input logic [31:0] addr,
        input logic [2:0]  snoop,
        input int          expect_cd_beats
    );
        int guard;
        int beats;
        begin
            // AC
            ACADDR  = addr;
            ACSNOOP = snoop;
            ACVALID = 1;

            guard = 0;
            while (!(ACVALID && ACREADY)) begin
                @(posedge clk);
                guard++;
                if (guard > 200) $fatal(1, "❌ AC timeout addr=%h", addr);
            end
            @(posedge clk);
            ACVALID = 0;

            // CR
            CRREADY = 1;
            guard = 0;
            while (!(CRVALID && CRREADY)) begin
                @(posedge clk);
                guard++;
                if (guard > 400) $fatal(1, "❌ CR timeout addr=%h", addr);
            end

            $display("📌 SNOOP addr=%h snoop=%0d CRRESP=%b", addr, snoop, CRRESP);

            // basic CRRESP checks
            if (CRRESP[4] !== 1'b1) $fatal(1, "❌ CRRESP OK bit not set!");
            if (expect_cd_beats > 0 && CRRESP[0] !== 1'b1)
                $fatal(1, "❌ Expected DataTransfer but CRRESP[0]=0");

            @(posedge clk);
            CRREADY = 0;

            // CD
            beats = 0;
            if (expect_cd_beats > 0) begin
                CDREADY = 1;

                while (beats < expect_cd_beats) begin
                    guard = 0;
                    while (!(CDVALID && CDREADY)) begin
                        @(posedge clk);
                        guard++;
                        if (guard > 400) $fatal(1, "❌ CD timeout addr=%h beat=%0d", addr, beats);
                    end

                    $display("   📦 CD beat %0d data=%h", beats, CDDATA);
                    beats++;
                    @(posedge clk);
                end

                CDREADY = 0;
            end

            $display("✅ SNOOP DONE addr=%h snoop=%0d", addr, snoop);
        end
    endtask

    //==================================================
    // TEST
    //==================================================
    logic [31:0] r;

    initial begin
        // init
        AWVALID=0; AWADDR=0;
        WVALID=0; WDATA=0; WLAST=0;
        BREADY=0;

        ARVALID=0; ARADDR=0;
        RREADY=0;

        ACVALID=0; ACADDR=0; ACSNOOP=0;
        CRREADY=0;
        CDREADY=0;

        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        //==========================================
        // 1) Make line Modified
        //==========================================
        $display("\n==============================");
        $display("STEP 1: Make cache line Modified (M)");
        $display("==============================\n");

        axi_write(32'h0000_0010, 32'hAAAA_1111);
        axi_write(32'h0000_0014, 32'hAAAA_2222);
        axi_write(32'h0000_0018, 32'hAAAA_3333);
        axi_write(32'h0000_001C, 32'hAAAA_4444);

        //==========================================
        // 2) ReadShared
        //==========================================
        $display("\n==============================");
        $display("TEST 1: SNOOP ReadShared (expect CD=4)");
        $display("==============================\n");

        ace_snoop(32'h0000_0010, SNOOP_ReadShared, 4);

        axi_read(32'h0000_0010, r);
        if (r !== 32'hAAAA_1111) $fatal(1, "❌ Data mismatch after ReadShared!");

        //==========================================
        // 3) ReadUnique
        //==========================================
        $display("\n==============================");
        $display("TEST 2: SNOOP ReadUnique (expect no CD, invalidate)");
        $display("==============================\n");

        ace_snoop(32'h0000_0010, SNOOP_ReadUnique, 0);

        // should miss and fetch from memory
        axi_read(32'h0000_0010, r);
        if (r !== 32'hAAAA_1111) $fatal(1, "❌ Data mismatch after ReadUnique!");

        //==========================================
        // 4) CleanInvalid
        //==========================================
        $display("\n==============================");
        $display("TEST 3: Make M again then CleanInvalid");
        $display("==============================\n");

        axi_write(32'h0000_0010, 32'hBBBB_1111);
        axi_write(32'h0000_0014, 32'hBBBB_2222);

        ace_snoop(32'h0000_0010, SNOOP_CleanInvalid, 0);

        axi_read(32'h0000_0010, r);
        if (r !== 32'hBBBB_1111) $fatal(1, "❌ CleanInvalid writeback failed!");

        $display("\n==============================");
        $display("✅ ALL SNOOP TESTS PASSED");
        $display("==============================\n");

        #50;
        $finish;
    end

endmodule
