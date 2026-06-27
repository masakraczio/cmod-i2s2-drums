`timescale 1ns / 1ps

module cmod_psram_smoke_top (
    input  wire       clk,
    input  wire [1:0] btn,
    output wire [1:0] led,

    output wire       psram_cs_n,
    output wire       psram_sck,
    output wire       psram_mosi,
    input  wire       psram_miso
);
    reg btn0_meta = 1'b0;
    reg btn0_sync = 1'b0;
    reg btn0_prev = 1'b0;
    reg btn1_meta = 1'b0;
    reg btn1_sync = 1'b0;
    wire start = btn0_sync & ~btn0_prev;

    wire active;
    wire pass;
    wire fail;
    wire complete;

    always @(posedge clk) begin
        btn0_meta <= btn[0];
        btn0_sync <= btn0_meta;
        btn0_prev <= btn0_sync;
        btn1_meta <= btn[1];
        btn1_sync <= btn1_meta;
    end

    psram_pattern_tester #(
        .CLK_DIV(12)
    ) tester (
        .clk(clk),
        .reset(btn1_sync),
        .start(start),
        .active(active),
        .pass(pass),
        .fail(fail),
        .complete(complete),
        .psram_cs_n(psram_cs_n),
        .psram_sck(psram_sck),
        .psram_mosi(psram_mosi),
        .psram_miso(psram_miso)
    );

    assign led[0] = active | pass;
    assign led[1] = fail | (complete & !pass);
endmodule
