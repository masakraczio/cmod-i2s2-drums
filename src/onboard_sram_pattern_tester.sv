`timescale 1ns / 1ps

module onboard_sram_pattern_tester (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,

    output reg         active = 1'b0,
    output reg         pass = 1'b0,
    output reg         fail = 1'b0,
    output reg         complete = 1'b0,

    output wire [18:0] ram_addr,
    inout  wire [7:0]  ram_dq,
    output wire        ram_ce_n,
    output wire        ram_oe_n,
    output wire        ram_we_n
);
    localparam [4:0] ST_IDLE    = 5'd0;
    localparam [4:0] ST_WRITE0  = 5'd1;
    localparam [4:0] ST_WAIT0   = 5'd2;
    localparam [4:0] ST_READ0   = 5'd3;
    localparam [4:0] ST_CHECK0  = 5'd4;
    localparam [4:0] ST_WRITE1  = 5'd5;
    localparam [4:0] ST_WAIT1   = 5'd6;
    localparam [4:0] ST_READ1   = 5'd7;
    localparam [4:0] ST_CHECK1  = 5'd8;
    localparam [4:0] ST_WRITE2  = 5'd9;
    localparam [4:0] ST_WAIT2   = 5'd10;
    localparam [4:0] ST_READ2   = 5'd11;
    localparam [4:0] ST_CHECK2  = 5'd12;
    localparam [4:0] ST_PASS    = 5'd13;
    localparam [4:0] ST_FAIL    = 5'd14;

    reg [4:0] state = ST_IDLE;
    reg req = 1'b0;
    reg write_en = 1'b0;
    reg [18:0] addr = 19'd0;
    reg [7:0] wr_data = 8'd0;

    wire [7:0] rd_data;
    wire busy;
    wire done;

    onboard_sram_controller sram (
        .clk(clk),
        .reset(reset),
        .req(req),
        .write_en(write_en),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .busy(busy),
        .done(done),
        .ram_addr(ram_addr),
        .ram_dq(ram_dq),
        .ram_ce_n(ram_ce_n),
        .ram_oe_n(ram_oe_n),
        .ram_we_n(ram_we_n)
    );

    always @(posedge clk) begin
        req <= 1'b0;

        if (reset) begin
            state <= ST_IDLE;
            write_en <= 1'b0;
            addr <= 19'd0;
            wr_data <= 8'd0;
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
                    write_en <= 1'b1;
                    addr <= 19'h00000;
                    wr_data <= 8'hA5;
                    req <= 1'b1;
                    state <= ST_WAIT0;
                end

                ST_WAIT0: if (done) state <= ST_READ0;

                ST_READ0: begin
                    write_en <= 1'b0;
                    addr <= 19'h00000;
                    req <= 1'b1;
                    state <= ST_CHECK0;
                end

                ST_CHECK0: if (done) state <= (rd_data == 8'hA5) ? ST_WRITE1 : ST_FAIL;

                ST_WRITE1: begin
                    write_en <= 1'b1;
                    addr <= 19'h15555;
                    wr_data <= 8'h5A;
                    req <= 1'b1;
                    state <= ST_WAIT1;
                end

                ST_WAIT1: if (done) state <= ST_READ1;

                ST_READ1: begin
                    write_en <= 1'b0;
                    addr <= 19'h15555;
                    req <= 1'b1;
                    state <= ST_CHECK1;
                end

                ST_CHECK1: if (done) state <= (rd_data == 8'h5A) ? ST_WRITE2 : ST_FAIL;

                ST_WRITE2: begin
                    write_en <= 1'b1;
                    addr <= 19'h7FFFF;
                    wr_data <= 8'hC3;
                    req <= 1'b1;
                    state <= ST_WAIT2;
                end

                ST_WAIT2: if (done) state <= ST_READ2;

                ST_READ2: begin
                    write_en <= 1'b0;
                    addr <= 19'h7FFFF;
                    req <= 1'b1;
                    state <= ST_CHECK2;
                end

                ST_CHECK2: if (done) state <= (rd_data == 8'hC3) ? ST_PASS : ST_FAIL;

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
