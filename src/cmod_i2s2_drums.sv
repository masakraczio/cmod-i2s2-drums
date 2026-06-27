`timescale 1ns / 1ps
`include "rtl/generated/sample_meta.vh"

module cmod_i2s2_drums (
    input  wire       clk,
    input  wire       uart_rx,
    input  wire [1:0] btn,
    output wire       uart_tx,
    output wire       da_mclk,
    output reg        da_lrck = 1'b0,
    output reg        da_sclk = 1'b0,
    output reg        da_sdin = 1'b0,
    output wire [18:0] ram_addr,
    inout  wire [7:0]  ram_dq,
    output wire        ram_ce_n,
    output wire        ram_oe_n,
    output wire        ram_we_n,
    output wire [1:0] led
);
    assign uart_tx = 1'b1;

    wire audio_clk_raw;
    wire audio_clk;
    wire clkfb;
    wire locked;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(83.333),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(64.000),
        .CLKFBOUT_PHASE(0.000),
        .CLKOUT0_DIVIDE_F(62.500),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(0.000),
        .STARTUP_WAIT("FALSE")
    ) audio_mmcm (
        .CLKIN1(clk),
        .CLKFBIN(clkfb),
        .CLKFBOUT(clkfb),
        .CLKOUT0(audio_clk_raw),
        .LOCKED(locked),
        .PWRDWN(1'b0),
        .RST(1'b0)
    );

    BUFG audio_bufg (
        .I(audio_clk_raw),
        .O(audio_clk)
    );

    assign da_mclk = audio_clk;

    reg locked_meta = 1'b0;
    reg locked_sync = 1'b0;

    always @(posedge clk) begin
        locked_meta <= locked;
        locked_sync <= locked_meta;
    end

    wire       rx_valid;
    wire [7:0] rx_data;

    uart_rx_8n1 #(
        .CLK_HZ(12_288_000),
        .BAUD(115_200)
    ) uart_in (
        .clk(audio_clk),
        .reset(!locked),
        .rx(uart_rx),
        .data(rx_data),
        .valid(rx_valid)
    );

    reg [7:0] trigger_toggle = 8'd0;
    reg [1:0] btn_meta = 2'd0;
    reg [1:0] btn_sync = 2'd0;
    reg [1:0] btn_prev = 2'd0;
    wire [1:0] btn_press = btn_sync & ~btn_prev;
    reg bank_uploading = 1'b0;
    reg bank_load_start = 1'b0;
    reg bank_load_valid = 1'b0;
    reg [7:0] bank_load_data = 8'd0;
    reg [18:0] bank_load_count = 19'd0;

    always @(posedge audio_clk) begin
        btn_meta <= btn;
        btn_sync <= btn_meta;
        btn_prev <= btn_sync;
        bank_load_start <= 1'b0;
        bank_load_valid <= 1'b0;

        if (!locked) begin
            trigger_toggle <= 8'd0;
            bank_uploading <= 1'b0;
            bank_load_count <= 19'd0;
        end else begin
            if (!bank_uploading) begin
                if (btn_press[0]) trigger_toggle[0] <= ~trigger_toggle[0];
                if (btn_press[1]) trigger_toggle[1] <= ~trigger_toggle[1];
            end

            if (rx_valid) begin
                if (bank_uploading) begin
                    bank_load_data <= rx_data;
                    bank_load_valid <= 1'b1;
                    if (bank_load_count == (`SAMPLE_BANK_LEN - 1)) begin
                        bank_uploading <= 1'b0;
                        bank_load_count <= 19'd0;
                    end else begin
                        bank_load_count <= bank_load_count + 19'd1;
                    end
                end else if (rx_data == "L") begin
                    bank_uploading <= 1'b1;
                    bank_load_count <= 19'd0;
                    bank_load_start <= 1'b1;
                end else begin
                    case (rx_data)
                        "1", "q", "Q": trigger_toggle[0] <= ~trigger_toggle[0];
                        "2", "w", "W": trigger_toggle[1] <= ~trigger_toggle[1];
                        "3", "e", "E": trigger_toggle[2] <= ~trigger_toggle[2];
                        "4", "r", "R": trigger_toggle[3] <= ~trigger_toggle[3];
                        "5", "a", "A": trigger_toggle[4] <= ~trigger_toggle[4];
                        "6", "s", "S": trigger_toggle[5] <= ~trigger_toggle[5];
                        "7", "d", "D": trigger_toggle[6] <= ~trigger_toggle[6];
                        "8", "f", "F": trigger_toggle[7] <= ~trigger_toggle[7];
                        default: trigger_toggle <= trigger_toggle;
                    endcase
                end
            end
        end
    end

    wire signed [15:0] audio_l;
    wire signed [15:0] audio_r;
    wire sample_bank_ready;
    wire sample_bank_loading;
    wire signed [15:0] i2s_audio_l = sample_bank_ready ? audio_l : 16'sd0;
    wire [7:0] meter_l;
    wire [7:0] meter_r;

    drum_audio_engine_sram drum_engine (
        .clk_audio(audio_clk),
        .reset(!locked),
        .trigger_toggle(trigger_toggle),
        .live_keys(8'd0),
        .mix_vols({8'd190, 8'd180, 8'd180, 8'd180, 8'd190, 8'd180, 8'd180, 8'd200}),
        .mix_pans({8'd128, 8'd128, 8'd128, 8'd128, 8'd128, 8'd128, 8'd128, 8'd128}),
        .master_vol(8'd120),
        .bank_load_start(bank_load_start),
        .bank_load_valid(bank_load_valid),
        .bank_load_data(bank_load_data),
        .sample_bank_ready(sample_bank_ready),
        .sample_bank_loading(sample_bank_loading),
        .meter_l(meter_l),
        .meter_r(meter_r),
        .audio_l(audio_l),
        .audio_r(audio_r),
        .ram_addr(ram_addr),
        .ram_dq(ram_dq),
        .ram_ce_n(ram_ce_n),
        .ram_oe_n(ram_oe_n),
        .ram_we_n(ram_we_n)
    );

    assign led[0] = locked_sync & sample_bank_ready;
    assign led[1] = sample_bank_loading | meter_l[7] | meter_r[7];

    reg [1:0] sclk_div = 2'd0;
    reg [5:0] bit_index = 6'd0;
    reg [23:0] left_shift = 24'd0;
    reg [23:0] right_shift = 24'd0;
    reg [23:0] shift_sample = 24'd0;

    always @(posedge audio_clk) begin
        if (!locked) begin
            sclk_div <= 2'd0;
            bit_index <= 6'd0;
            da_lrck <= 1'b0;
            da_sclk <= 1'b0;
            da_sdin <= 1'b0;
            left_shift <= 24'd0;
            right_shift <= 24'd0;
            shift_sample <= 24'd0;
        end else begin
            sclk_div <= sclk_div + 1'b1;

            if (sclk_div == 2'd0) begin
                case (bit_index)
                    6'd0: begin
                        da_lrck <= 1'b0;
                        da_sdin <= 1'b0;
                        left_shift <= {i2s_audio_l, 8'd0};
                        right_shift <= {i2s_audio_l, 8'd0};
                        shift_sample <= {i2s_audio_l, 8'd0};
                    end

                    6'd1, 6'd2, 6'd3, 6'd4, 6'd5, 6'd6, 6'd7, 6'd8,
                    6'd9, 6'd10, 6'd11, 6'd12, 6'd13, 6'd14, 6'd15, 6'd16,
                    6'd17, 6'd18, 6'd19, 6'd20, 6'd21, 6'd22, 6'd23, 6'd24: begin
                        da_sdin <= shift_sample[23];
                        shift_sample <= {shift_sample[22:0], 1'b0};
                    end

                    6'd32: begin
                        da_lrck <= 1'b1;
                        da_sdin <= 1'b0;
                        shift_sample <= right_shift;
                    end

                    6'd33, 6'd34, 6'd35, 6'd36, 6'd37, 6'd38, 6'd39, 6'd40,
                    6'd41, 6'd42, 6'd43, 6'd44, 6'd45, 6'd46, 6'd47, 6'd48,
                    6'd49, 6'd50, 6'd51, 6'd52, 6'd53, 6'd54, 6'd55, 6'd56: begin
                        da_sdin <= shift_sample[23];
                        shift_sample <= {shift_sample[22:0], 1'b0};
                    end

                    default: begin
                        da_sdin <= 1'b0;
                    end
                endcase
            end else if (sclk_div == 2'd1) begin
                da_sclk <= 1'b1;
            end else if (sclk_div == 2'd3) begin
                da_sclk <= 1'b0;

                if (bit_index == 6'd63) begin
                    bit_index <= 6'd0;
                end else begin
                    bit_index <= bit_index + 1'b1;
                end
            end
        end
    end
endmodule

module uart_rx_8n1 #(
    parameter integer CLK_HZ = 12_000_000,
    parameter integer BAUD = 115_200
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,
    output reg  [7:0] data = 8'd0,
    output reg        valid = 1'b0
);
    localparam integer BAUD_DIV = CLK_HZ / BAUD;
    localparam integer HALF_DIV = BAUD_DIV / 2;

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA = 2'd2;
    localparam [1:0] ST_STOP = 2'd3;

    reg [1:0] state = ST_IDLE;
    reg [15:0] baud_count = 16'd0;
    reg [2:0] bit_count = 3'd0;
    reg [7:0] shift = 8'd0;
    reg rx_meta = 1'b1;
    reg rx_sync = 1'b1;

    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
        valid <= 1'b0;

        if (reset) begin
            state <= ST_IDLE;
            baud_count <= 16'd0;
            bit_count <= 3'd0;
            shift <= 8'd0;
            data <= 8'd0;
            valid <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    baud_count <= 16'd0;
                    bit_count <= 3'd0;
                    if (!rx_sync) state <= ST_START;
                end

                ST_START: begin
                    if (baud_count == HALF_DIV[15:0]) begin
                        baud_count <= 16'd0;
                        if (!rx_sync) state <= ST_DATA;
                        else state <= ST_IDLE;
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                ST_DATA: begin
                    if (baud_count == BAUD_DIV - 1) begin
                        baud_count <= 16'd0;
                        shift <= {rx_sync, shift[7:1]};
                        if (bit_count == 3'd7) begin
                            bit_count <= 3'd0;
                            state <= ST_STOP;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end

                ST_STOP: begin
                    if (baud_count == BAUD_DIV - 1) begin
                        baud_count <= 16'd0;
                        data <= shift;
                        valid <= rx_sync;
                        state <= ST_IDLE;
                    end else begin
                        baud_count <= baud_count + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
