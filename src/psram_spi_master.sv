`timescale 1ns / 1ps

module psram_spi_master #(
    parameter integer CLK_DIV = 8
) (
    input  wire       clk,
    input  wire       reset,

    input  wire       start,
    input  wire       write_en,
    input  wire [23:0] addr,
    input  wire [7:0] wr_data,
    output reg  [7:0] rd_data = 8'd0,
    output reg        busy = 1'b0,
    output reg        done = 1'b0,

    output reg        psram_cs_n = 1'b1,
    output reg        psram_sck = 1'b0,
    output reg        psram_mosi = 1'b0,
    input  wire       psram_miso
);
    localparam integer DIV_BITS = (CLK_DIV <= 2) ? 1 : $clog2(CLK_DIV);

    localparam [7:0] CMD_READ  = 8'h03;
    localparam [7:0] CMD_WRITE = 8'h02;

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_LOW  = 3'd1;
    localparam [2:0] ST_HIGH = 3'd2;
    localparam [2:0] ST_DONE = 3'd3;

    reg [2:0] state = ST_IDLE;
    reg [DIV_BITS-1:0] div_count = {DIV_BITS{1'b0}};
    reg [39:0] tx_shift = 40'd0;
    reg [7:0] rx_shift = 8'd0;
    reg [5:0] bit_count = 6'd0;
    reg op_write = 1'b0;

    wire div_last = (div_count == CLK_DIV - 1);

    always @(posedge clk) begin
        done <= 1'b0;

        if (reset) begin
            state <= ST_IDLE;
            div_count <= {DIV_BITS{1'b0}};
            tx_shift <= 40'd0;
            rx_shift <= 8'd0;
            rd_data <= 8'd0;
            bit_count <= 6'd0;
            op_write <= 1'b0;
            busy <= 1'b0;
            psram_cs_n <= 1'b1;
            psram_sck <= 1'b0;
            psram_mosi <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    psram_cs_n <= 1'b1;
                    psram_sck <= 1'b0;
                    div_count <= {DIV_BITS{1'b0}};

                    if (start) begin
                        op_write <= write_en;
                        tx_shift <= {write_en ? CMD_WRITE : CMD_READ, addr, wr_data};
                        rx_shift <= 8'd0;
                        bit_count <= 6'd39;
                        busy <= 1'b1;
                        psram_cs_n <= 1'b0;
                        psram_mosi <= write_en ? CMD_WRITE[7] : CMD_READ[7];
                        state <= ST_LOW;
                    end
                end

                ST_LOW: begin
                    if (div_last) begin
                        div_count <= {DIV_BITS{1'b0}};
                        psram_sck <= 1'b1;
                        state <= ST_HIGH;
                    end else begin
                        div_count <= div_count + 1'b1;
                    end
                end

                ST_HIGH: begin
                    if (div_last) begin
                        div_count <= {DIV_BITS{1'b0}};
                        psram_sck <= 1'b0;

                        if (!op_write && bit_count < 6'd8) begin
                            rx_shift <= {rx_shift[6:0], psram_miso};
                        end

                        if (bit_count == 6'd0) begin
                            state <= ST_DONE;
                        end else begin
                            bit_count <= bit_count - 1'b1;
                            tx_shift <= {tx_shift[38:0], 1'b0};
                            psram_mosi <= tx_shift[38];
                            state <= ST_LOW;
                        end
                    end else begin
                        div_count <= div_count + 1'b1;
                    end
                end

                ST_DONE: begin
                    psram_cs_n <= 1'b1;
                    psram_sck <= 1'b0;
                    busy <= 1'b0;
                    done <= 1'b1;
                    if (!op_write) rd_data <= rx_shift;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
