`timescale 1ns / 1ps

module psram_pattern_tester #(
    parameter integer CLK_DIV = 8
) (
    input  wire clk,
    input  wire reset,
    input  wire start,

    output reg  active = 1'b0,
    output reg  pass = 1'b0,
    output reg  fail = 1'b0,
    output reg  complete = 1'b0,

    output wire psram_cs_n,
    output wire psram_sck,
    output wire psram_mosi,
    input  wire psram_miso
);
    localparam [3:0] ST_IDLE   = 4'd0;
    localparam [3:0] ST_WRITE0 = 4'd1;
    localparam [3:0] ST_WAIT0  = 4'd2;
    localparam [3:0] ST_READ0  = 4'd3;
    localparam [3:0] ST_CHECK0 = 4'd4;
    localparam [3:0] ST_WRITE1 = 4'd5;
    localparam [3:0] ST_WAIT1  = 4'd6;
    localparam [3:0] ST_READ1  = 4'd7;
    localparam [3:0] ST_CHECK1 = 4'd8;
    localparam [3:0] ST_PASS   = 4'd9;
    localparam [3:0] ST_FAIL   = 4'd10;

    reg [3:0] state = ST_IDLE;
    reg master_start = 1'b0;
    reg master_write = 1'b0;
    reg [23:0] master_addr = 24'd0;
    reg [7:0] master_wdata = 8'd0;

    wire [7:0] master_rdata;
    wire master_busy;
    wire master_done;

    psram_spi_master #(
        .CLK_DIV(CLK_DIV)
    ) psram_master (
        .clk(clk),
        .reset(reset),
        .start(master_start),
        .write_en(master_write),
        .addr(master_addr),
        .wr_data(master_wdata),
        .rd_data(master_rdata),
        .busy(master_busy),
        .done(master_done),
        .psram_cs_n(psram_cs_n),
        .psram_sck(psram_sck),
        .psram_mosi(psram_mosi),
        .psram_miso(psram_miso)
    );

    always @(posedge clk) begin
        master_start <= 1'b0;

        if (reset) begin
            state <= ST_IDLE;
            master_write <= 1'b0;
            master_addr <= 24'd0;
            master_wdata <= 8'd0;
            active <= 1'b0;
            pass <= 1'b0;
            fail <= 1'b0;
            complete <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    active <= 1'b0;
                    if (start) begin
                        pass <= 1'b0;
                        fail <= 1'b0;
                        complete <= 1'b0;
                        active <= 1'b1;
                        state <= ST_WRITE0;
                    end
                end

                ST_WRITE0: begin
                    master_write <= 1'b1;
                    master_addr <= 24'h000000;
                    master_wdata <= 8'hA5;
                    master_start <= 1'b1;
                    state <= ST_WAIT0;
                end

                ST_WAIT0: if (master_done) state <= ST_READ0;

                ST_READ0: begin
                    master_write <= 1'b0;
                    master_addr <= 24'h000000;
                    master_wdata <= 8'd0;
                    master_start <= 1'b1;
                    state <= ST_CHECK0;
                end

                ST_CHECK0: begin
                    if (master_done) begin
                        if (master_rdata == 8'hA5) state <= ST_WRITE1;
                        else state <= ST_FAIL;
                    end
                end

                ST_WRITE1: begin
                    master_write <= 1'b1;
                    master_addr <= 24'h000001;
                    master_wdata <= 8'h5A;
                    master_start <= 1'b1;
                    state <= ST_WAIT1;
                end

                ST_WAIT1: if (master_done) state <= ST_READ1;

                ST_READ1: begin
                    master_write <= 1'b0;
                    master_addr <= 24'h000001;
                    master_wdata <= 8'd0;
                    master_start <= 1'b1;
                    state <= ST_CHECK1;
                end

                ST_CHECK1: begin
                    if (master_done) begin
                        if (master_rdata == 8'h5A) state <= ST_PASS;
                        else state <= ST_FAIL;
                    end
                end

                ST_PASS: begin
                    active <= 1'b0;
                    pass <= 1'b1;
                    complete <= 1'b1;
                end

                ST_FAIL: begin
                    active <= 1'b0;
                    fail <= 1'b1;
                    complete <= 1'b1;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
