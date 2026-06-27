`timescale 1ns / 1ps

module onboard_sram_controller (
    input  wire        clk,
    input  wire        reset,

    input  wire        req,
    input  wire        write_en,
    input  wire [18:0] addr,
    input  wire [7:0]  wr_data,
    output reg  [7:0]  rd_data = 8'd0,
    output reg         busy = 1'b0,
    output reg         done = 1'b0,

    output reg  [18:0] ram_addr = 19'd0,
    inout  wire [7:0]  ram_dq,
    output reg         ram_ce_n = 1'b1,
    output reg         ram_oe_n = 1'b1,
    output reg         ram_we_n = 1'b1
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WRITE_LOW  = 3'd1;
    localparam [2:0] ST_WRITE_HIGH = 3'd2;
    localparam [2:0] ST_READ_WAIT0 = 3'd3;
    localparam [2:0] ST_READ_WAIT1 = 3'd4;
    localparam [2:0] ST_READ_DONE  = 3'd5;

    reg [2:0] state = ST_IDLE;
    reg [7:0] dq_out = 8'd0;
    reg dq_drive = 1'b0;

    assign ram_dq = dq_drive ? dq_out : 8'hZZ;

    always @(posedge clk) begin
        done <= 1'b0;

        if (reset) begin
            state <= ST_IDLE;
            rd_data <= 8'd0;
            busy <= 1'b0;
            ram_addr <= 19'd0;
            ram_ce_n <= 1'b1;
            ram_oe_n <= 1'b1;
            ram_we_n <= 1'b1;
            dq_out <= 8'd0;
            dq_drive <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    ram_ce_n <= 1'b1;
                    ram_oe_n <= 1'b1;
                    ram_we_n <= 1'b1;
                    dq_drive <= 1'b0;

                    if (req) begin
                        busy <= 1'b1;
                        ram_addr <= addr;
                        ram_ce_n <= 1'b0;

                        if (write_en) begin
                            ram_oe_n <= 1'b1;
                            ram_we_n <= 1'b1;
                            dq_out <= wr_data;
                            dq_drive <= 1'b1;
                            state <= ST_WRITE_LOW;
                        end else begin
                            ram_oe_n <= 1'b0;
                            ram_we_n <= 1'b1;
                            dq_drive <= 1'b0;
                            state <= ST_READ_WAIT0;
                        end
                    end
                end

                ST_WRITE_LOW: begin
                    ram_we_n <= 1'b0;
                    state <= ST_WRITE_HIGH;
                end

                ST_WRITE_HIGH: begin
                    ram_we_n <= 1'b1;
                    ram_ce_n <= 1'b1;
                    dq_drive <= 1'b0;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                ST_READ_WAIT0: begin
                    state <= ST_READ_WAIT1;
                end

                ST_READ_WAIT1: begin
                    rd_data <= ram_dq;
                    state <= ST_READ_DONE;
                end

                ST_READ_DONE: begin
                    ram_oe_n <= 1'b1;
                    ram_ce_n <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
