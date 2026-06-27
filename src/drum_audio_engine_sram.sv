`include "rtl/generated/sample_meta.vh"

module drum_audio_engine_sram (
    input               clk_audio,
    input               reset,
    input       [7:0]   trigger_toggle,
    input       [7:0]   live_keys,
    input       [63:0]  mix_vols,
    input       [63:0]  mix_pans,
    input       [7:0]   master_vol,
    input               bank_load_start,
    input               bank_load_valid,
    input       [7:0]   bank_load_data,
    output reg          sample_bank_ready,
    output reg          sample_bank_loading,
    output reg  [7:0]   meter_l,
    output reg  [7:0]   meter_r,
    output reg  signed [15:0] audio_l,
    output reg  signed [15:0] audio_r,

    output wire [18:0]  ram_addr,
    inout  wire [7:0]   ram_dq,
    output wire         ram_ce_n,
    output wire         ram_oe_n,
    output wire         ram_we_n
);
    localparam integer AUDIO_DIV_48K = 256;
    localparam signed [31:0] LIM_T = 32'sd22000;
    localparam signed [31:0] LIM_MAX = 32'sd52000;

    localparam [3:0] ST_LOAD_WAIT  = 4'd0;
    localparam [3:0] ST_LOAD_WRITE = 4'd1;
    localparam [3:0] ST_READY      = 4'd2;
    localparam [3:0] ST_VOICE_REQ  = 4'd3;
    localparam [3:0] ST_VOICE_WAIT = 4'd4;
    localparam [3:0] ST_MIX        = 4'd5;

    reg [3:0] state = ST_LOAD_WAIT;

    reg        sram_req = 1'b0;
    reg        sram_write = 1'b0;
    reg [18:0] sram_addr = 19'd0;
    reg [7:0]  sram_wdata = 8'd0;
    wire [7:0] sram_rdata;
    wire       sram_done;

    onboard_sram_controller sram (
        .clk(clk_audio),
        .reset(reset),
        .req(sram_req),
        .write_en(sram_write),
        .addr(sram_addr),
        .wr_data(sram_wdata),
        .rd_data(sram_rdata),
        .busy(),
        .done(sram_done),
        .ram_addr(ram_addr),
        .ram_dq(ram_dq),
        .ram_ce_n(ram_ce_n),
        .ram_oe_n(ram_oe_n),
        .ram_we_n(ram_we_n)
    );

    reg [18:0] load_addr = 19'd0;
    reg [2:0] render_voice = 3'd0;
    reg [7:0] render_triggers = 8'd0;
    reg [18:0] render_pos = 19'd0;

    reg [7:0] trig_meta = 8'd0;
    reg [7:0] trig_sync = 8'd0;
    reg [7:0] trig_prev = 8'd0;
    wire [7:0] trig_event = trig_sync ^ trig_prev;

    reg [8:0] sample_div = 9'd0;
    wire sample_tick = (sample_div == (AUDIO_DIV_48K - 1));
    reg [7:0] pending_triggers = 8'd0;

    reg voice_active0 = 1'b0;
    reg voice_active1 = 1'b0;
    reg voice_active2 = 1'b0;
    reg voice_active3 = 1'b0;
    reg voice_active4 = 1'b0;
    reg voice_active5 = 1'b0;
    reg voice_active6 = 1'b0;
    reg voice_active7 = 1'b0;

    reg [18:0] voice_pos0 = 19'd0;
    reg [18:0] voice_pos1 = 19'd0;
    reg [18:0] voice_pos2 = 19'd0;
    reg [18:0] voice_pos3 = 19'd0;
    reg [18:0] voice_pos4 = 19'd0;
    reg [18:0] voice_pos5 = 19'd0;
    reg [18:0] voice_pos6 = 19'd0;
    reg [18:0] voice_pos7 = 19'd0;

    reg signed [17:0] v0 = 18'sd0;
    reg signed [17:0] v1 = 18'sd0;
    reg signed [17:0] v2 = 18'sd0;
    reg signed [17:0] v3 = 18'sd0;
    reg signed [17:0] v4 = 18'sd0;
    reg signed [17:0] v5 = 18'sd0;
    reg signed [17:0] v6 = 18'sd0;
    reg signed [17:0] v7 = 18'sd0;

    wire [7:0] vol0 = mix_vols[7:0];
    wire [7:0] vol1 = mix_vols[15:8];
    wire [7:0] vol2 = mix_vols[23:16];
    wire [7:0] vol3 = mix_vols[31:24];
    wire [7:0] vol4 = mix_vols[39:32];
    wire [7:0] vol5 = mix_vols[47:40];
    wire [7:0] vol6 = mix_vols[55:48];
    wire [7:0] vol7 = mix_vols[63:56];

    wire [7:0] pan0 = mix_pans[7:0];
    wire [7:0] pan1 = mix_pans[15:8];
    wire [7:0] pan2 = mix_pans[23:16];
    wire [7:0] pan3 = mix_pans[31:24];
    wire [7:0] pan4 = mix_pans[39:32];
    wire [7:0] pan5 = mix_pans[47:40];
    wire [7:0] pan6 = mix_pans[55:48];
    wire [7:0] pan7 = mix_pans[63:56];

    wire [7:0] lg0 = 8'd255 - pan0;
    wire [7:0] lg1 = 8'd255 - pan1;
    wire [7:0] lg2 = 8'd255 - pan2;
    wire [7:0] lg3 = 8'd255 - pan3;
    wire [7:0] lg4 = 8'd255 - pan4;
    wire [7:0] lg5 = 8'd255 - pan5;
    wire [7:0] lg6 = 8'd255 - pan6;
    wire [7:0] lg7 = 8'd255 - pan7;

    wire signed [35:0] mul0l = $signed(v0) * $signed({1'b0, vol0}) * $signed({1'b0, lg0});
    wire signed [35:0] mul1l = $signed(v1) * $signed({1'b0, vol1}) * $signed({1'b0, lg1});
    wire signed [35:0] mul2l = $signed(v2) * $signed({1'b0, vol2}) * $signed({1'b0, lg2});
    wire signed [35:0] mul3l = $signed(v3) * $signed({1'b0, vol3}) * $signed({1'b0, lg3});
    wire signed [35:0] mul4l = $signed(v4) * $signed({1'b0, vol4}) * $signed({1'b0, lg4});
    wire signed [35:0] mul5l = $signed(v5) * $signed({1'b0, vol5}) * $signed({1'b0, lg5});
    wire signed [35:0] mul6l = $signed(v6) * $signed({1'b0, vol6}) * $signed({1'b0, lg6});
    wire signed [35:0] mul7l = $signed(v7) * $signed({1'b0, vol7}) * $signed({1'b0, lg7});

    wire signed [35:0] mul0r = $signed(v0) * $signed({1'b0, vol0}) * $signed({1'b0, pan0});
    wire signed [35:0] mul1r = $signed(v1) * $signed({1'b0, vol1}) * $signed({1'b0, pan1});
    wire signed [35:0] mul2r = $signed(v2) * $signed({1'b0, vol2}) * $signed({1'b0, pan2});
    wire signed [35:0] mul3r = $signed(v3) * $signed({1'b0, vol3}) * $signed({1'b0, pan3});
    wire signed [35:0] mul4r = $signed(v4) * $signed({1'b0, vol4}) * $signed({1'b0, pan4});
    wire signed [35:0] mul5r = $signed(v5) * $signed({1'b0, vol5}) * $signed({1'b0, pan5});
    wire signed [35:0] mul6r = $signed(v6) * $signed({1'b0, vol6}) * $signed({1'b0, pan6});
    wire signed [35:0] mul7r = $signed(v7) * $signed({1'b0, vol7}) * $signed({1'b0, pan7});

    wire signed [27:0] sum_l = (mul0l >>> 16) + (mul1l >>> 16) + (mul2l >>> 16) + (mul3l >>> 16) +
                              (mul4l >>> 16) + (mul5l >>> 16) + (mul6l >>> 16) + (mul7l >>> 16);
    wire signed [27:0] sum_r = (mul0r >>> 16) + (mul1r >>> 16) + (mul2r >>> 16) + (mul3r >>> 16) +
                              (mul4r >>> 16) + (mul5r >>> 16) + (mul6r >>> 16) + (mul7r >>> 16);

    wire signed [31:0] mix_l_pre = ($signed(sum_l) * $signed({1'b0, master_vol})) >>> 8;
    wire signed [31:0] mix_r_pre = ($signed(sum_r) * $signed({1'b0, master_vol})) >>> 8;
    wire signed [15:0] mix_l_out = clip16(soft_limit(mix_l_pre));
    wire signed [15:0] mix_r_out = clip16(soft_limit(mix_r_pre));
    wire [15:0] mix_l_abs = abs16(mix_l_out);
    wire [15:0] mix_r_abs = abs16(mix_r_out);

    reg [15:0] meter_env_l = 16'd0;
    reg [15:0] meter_env_r = 16'd0;

    function automatic [18:0] voice_start(input [2:0] voice);
        begin
            case (voice)
                3'd0: voice_start = `KICK_START;
                3'd1: voice_start = `SNARE_START;
                3'd2: voice_start = `HH_C_START;
                3'd3: voice_start = `HH_O_START;
                3'd4: voice_start = `CLAP_START;
                3'd5: voice_start = `TOM_L_START;
                3'd6: voice_start = `TOM_H_START;
                default: voice_start = `CRASH_START;
            endcase
        end
    endfunction

    function automatic [18:0] voice_len(input [2:0] voice);
        begin
            case (voice)
                3'd0: voice_len = `KICK_LEN;
                3'd1: voice_len = `SNARE_LEN;
                3'd2: voice_len = `HH_C_LEN;
                3'd3: voice_len = `HH_O_LEN;
                3'd4: voice_len = `CLAP_LEN;
                3'd5: voice_len = `TOM_L_LEN;
                3'd6: voice_len = `TOM_H_LEN;
                default: voice_len = `CRASH_LEN;
            endcase
        end
    endfunction

    function automatic integer voice_shift(input [2:0] voice);
        begin
            if (voice == 3'd7) voice_shift = 7;
            else voice_shift = 8;
        end
    endfunction

    function automatic voice_active(input [2:0] voice);
        begin
            case (voice)
                3'd0: voice_active = voice_active0;
                3'd1: voice_active = voice_active1;
                3'd2: voice_active = voice_active2;
                3'd3: voice_active = voice_active3;
                3'd4: voice_active = voice_active4;
                3'd5: voice_active = voice_active5;
                3'd6: voice_active = voice_active6;
                default: voice_active = voice_active7;
            endcase
        end
    endfunction

    function automatic [18:0] voice_pos(input [2:0] voice);
        begin
            case (voice)
                3'd0: voice_pos = voice_pos0;
                3'd1: voice_pos = voice_pos1;
                3'd2: voice_pos = voice_pos2;
                3'd3: voice_pos = voice_pos3;
                3'd4: voice_pos = voice_pos4;
                3'd5: voice_pos = voice_pos5;
                3'd6: voice_pos = voice_pos6;
                default: voice_pos = voice_pos7;
            endcase
        end
    endfunction

    function automatic signed [17:0] sample8_to_18(input signed [7:0] x, input integer amp_shift);
        begin
            sample8_to_18 = $signed({{10{x[7]}}, x}) <<< amp_shift;
        end
    endfunction

    function automatic signed [31:0] soft_limit(input signed [31:0] x);
        reg sign_neg;
        reg signed [31:0] ax;
        reg signed [31:0] y;
        begin
            sign_neg = x[31];
            ax = sign_neg ? -x : x;
            if (ax <= LIM_T) y = ax;
            else begin
                y = LIM_T + ((ax - LIM_T) >>> 2);
                if (y > LIM_MAX) y = LIM_MAX;
            end
            soft_limit = sign_neg ? -y : y;
        end
    endfunction

    function automatic signed [15:0] clip16(input signed [31:0] in);
        begin
            if (in > 32'sd32767) clip16 = 16'sd32767;
            else if (in < -32'sd32767) clip16 = 16'sh8000;
            else clip16 = in[15:0];
        end
    endfunction

    function automatic [15:0] abs16(input signed [15:0] in);
        reg signed [15:0] neg;
        begin
            if (!in[15]) abs16 = in[15:0];
            else if (in == 16'sh8000) abs16 = 16'd32767;
            else begin
                neg = -in;
                abs16 = neg[15:0];
            end
        end
    endfunction

    function automatic [15:0] meter_decay(input [15:0] in);
        reg [16:0] drop;
        begin
            drop = {1'b0, (in >> 4)} + 17'd1;
            if ({1'b0, in} > drop) meter_decay = in - drop[15:0];
            else meter_decay = 16'd0;
        end
    endfunction

    task automatic set_voice_sample(input [2:0] voice, input signed [17:0] value);
        begin
            case (voice)
                3'd0: v0 <= value;
                3'd1: v1 <= value;
                3'd2: v2 <= value;
                3'd3: v3 <= value;
                3'd4: v4 <= value;
                3'd5: v5 <= value;
                3'd6: v6 <= value;
                default: v7 <= value;
            endcase
        end
    endtask

    task automatic set_voice_next(input [2:0] voice, input active, input [18:0] pos);
        begin
            case (voice)
                3'd0: begin voice_active0 <= active; voice_pos0 <= pos; end
                3'd1: begin voice_active1 <= active; voice_pos1 <= pos; end
                3'd2: begin voice_active2 <= active; voice_pos2 <= pos; end
                3'd3: begin voice_active3 <= active; voice_pos3 <= pos; end
                3'd4: begin voice_active4 <= active; voice_pos4 <= pos; end
                3'd5: begin voice_active5 <= active; voice_pos5 <= pos; end
                3'd6: begin voice_active6 <= active; voice_pos6 <= pos; end
                default: begin voice_active7 <= active; voice_pos7 <= pos; end
            endcase
        end
    endtask

    always @(posedge clk_audio) begin
        sram_req <= 1'b0;

        if (reset) begin
            state <= ST_LOAD_WAIT;
            load_addr <= 19'd0;
            sample_bank_ready <= 1'b0;
            sample_bank_loading <= 1'b0;
            trig_meta <= 8'd0;
            trig_sync <= 8'd0;
            trig_prev <= 8'd0;
            sample_div <= 9'd0;
            pending_triggers <= 8'd0;
            render_voice <= 3'd0;
            render_triggers <= 8'd0;
            render_pos <= 19'd0;
            meter_env_l <= 16'd0;
            meter_env_r <= 16'd0;
            meter_l <= 8'd0;
            meter_r <= 8'd0;
            audio_l <= 16'sd0;
            audio_r <= 16'sd0;
            v0 <= 18'sd0;
            v1 <= 18'sd0;
            v2 <= 18'sd0;
            v3 <= 18'sd0;
            v4 <= 18'sd0;
            v5 <= 18'sd0;
            v6 <= 18'sd0;
            v7 <= 18'sd0;
            set_voice_next(3'd0, 1'b0, 19'd0);
            set_voice_next(3'd1, 1'b0, 19'd0);
            set_voice_next(3'd2, 1'b0, 19'd0);
            set_voice_next(3'd3, 1'b0, 19'd0);
            set_voice_next(3'd4, 1'b0, 19'd0);
            set_voice_next(3'd5, 1'b0, 19'd0);
            set_voice_next(3'd6, 1'b0, 19'd0);
            set_voice_next(3'd7, 1'b0, 19'd0);
        end else begin
            trig_meta <= trigger_toggle;
            trig_sync <= trig_meta;
            trig_prev <= trig_sync;

            if (sample_tick) sample_div <= 9'd0;
            else sample_div <= sample_div + 9'd1;

            if (bank_load_start) begin
                state <= ST_LOAD_WAIT;
                load_addr <= 19'd0;
                sample_bank_ready <= 1'b0;
                sample_bank_loading <= 1'b1;
                pending_triggers <= 8'd0;
                render_triggers <= 8'd0;
                v0 <= 18'sd0;
                v1 <= 18'sd0;
                v2 <= 18'sd0;
                v3 <= 18'sd0;
                v4 <= 18'sd0;
                v5 <= 18'sd0;
                v6 <= 18'sd0;
                v7 <= 18'sd0;
                set_voice_next(3'd0, 1'b0, 19'd0);
                set_voice_next(3'd1, 1'b0, 19'd0);
                set_voice_next(3'd2, 1'b0, 19'd0);
                set_voice_next(3'd3, 1'b0, 19'd0);
                set_voice_next(3'd4, 1'b0, 19'd0);
                set_voice_next(3'd5, 1'b0, 19'd0);
                set_voice_next(3'd6, 1'b0, 19'd0);
                set_voice_next(3'd7, 1'b0, 19'd0);
            end else if (sample_bank_ready && state != ST_READY) begin
                pending_triggers <= pending_triggers | trig_event;
            end

            case (state)
                ST_LOAD_WAIT: begin
                    if (bank_load_valid) begin
                        sram_write <= 1'b1;
                        sram_addr <= load_addr;
                        sram_wdata <= bank_load_data;
                        sram_req <= 1'b1;
                        sample_bank_loading <= 1'b1;
                        state <= ST_LOAD_WRITE;
                    end
                end

                ST_LOAD_WRITE: begin
                    if (sram_done) begin
                        if (load_addr == (`SAMPLE_BANK_LEN - 1)) begin
                            sample_bank_loading <= 1'b0;
                            sample_bank_ready <= 1'b1;
                            state <= ST_READY;
                        end else begin
                            load_addr <= load_addr + 19'd1;
                            state <= ST_LOAD_WAIT;
                        end
                    end
                end

                ST_READY: begin
                    pending_triggers <= pending_triggers | trig_event;
                    if (sample_tick) begin
                        render_triggers <= pending_triggers | trig_event;
                        pending_triggers <= 8'd0;
                        render_voice <= 3'd0;
                        state <= ST_VOICE_REQ;
                    end
                end

                ST_VOICE_REQ: begin
                    if (render_triggers[render_voice] || voice_active(render_voice)) begin
                        render_pos <= render_triggers[render_voice] ? 19'd0 : voice_pos(render_voice);
                        sram_write <= 1'b0;
                        sram_addr <= voice_start(render_voice) + (render_triggers[render_voice] ? 19'd0 : voice_pos(render_voice));
                        sram_req <= 1'b1;
                        state <= ST_VOICE_WAIT;
                    end else begin
                        set_voice_sample(render_voice, 18'sd0);
                        if (render_voice == 3'd7) state <= ST_MIX;
                        else render_voice <= render_voice + 3'd1;
                    end
                end

                ST_VOICE_WAIT: begin
                    if (sram_done) begin
                        set_voice_sample(render_voice, sample8_to_18(sram_rdata, voice_shift(render_voice)));
                        if (render_pos >= (voice_len(render_voice) - 19'd1)) begin
                            set_voice_next(render_voice, 1'b0, 19'd0);
                        end else begin
                            set_voice_next(render_voice, 1'b1, render_pos + 19'd1);
                        end

                        if (render_voice == 3'd7) state <= ST_MIX;
                        else begin
                            render_voice <= render_voice + 3'd1;
                            state <= ST_VOICE_REQ;
                        end
                    end
                end

                ST_MIX: begin
                    audio_l <= mix_l_out;
                    audio_r <= mix_r_out;

                    if (mix_l_abs >= meter_env_l) meter_env_l <= mix_l_abs;
                    else meter_env_l <= meter_decay(meter_env_l);

                    if (mix_r_abs >= meter_env_r) meter_env_r <= mix_r_abs;
                    else meter_env_r <= meter_decay(meter_env_r);

                    meter_l <= meter_env_l[14:7];
                    meter_r <= meter_env_r[14:7];
                    state <= ST_READY;
                end

                default: state <= ST_LOAD_WAIT;
            endcase
        end
    end

    wire _unused_ok = &{1'b0, live_keys};
endmodule
