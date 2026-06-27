`include "rtl/generated/sample_meta.vh"

module drum_audio_engine (
	input               clk_audio,
	input               reset,
	input       [7:0]   trigger_toggle,
	input       [7:0]   live_keys,
	input       [63:0]  mix_vols,
	input       [63:0]  mix_pans,
	input       [7:0]   master_vol,
	output reg  [7:0]   meter_l,
	output reg  [7:0]   meter_r,
	output reg  signed [15:0] audio_l,
	output reg  signed [15:0] audio_r
);

	localparam integer AUDIO_DIV_48K = 256; // 12.288MHz / 256 = 48kHz
	localparam signed [31:0] LIM_T = 32'sd22000;
	localparam signed [31:0] LIM_MAX = 32'sd52000;

	reg [7:0] trig_meta = 8'd0;
	reg [7:0] trig_sync = 8'd0;
	reg [7:0] trig_prev = 8'd0;
	wire [7:0] trig_event = trig_sync ^ trig_prev;

	reg [8:0] sample_div = 9'd0;
	wire sample_tick = (sample_div == (AUDIO_DIV_48K - 1));

	reg [7:0] pending_triggers = 8'd0;
	wire [7:0] voice_triggers = sample_tick ? (pending_triggers | trig_event) : 8'd0;

	wire signed [17:0] v0, v1, v2, v3, v4, v5, v6, v7;

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

	wire signed [23:0] ch0l = mul0l >>> 16;
	wire signed [23:0] ch1l = mul1l >>> 16;
	wire signed [23:0] ch2l = mul2l >>> 16;
	wire signed [23:0] ch3l = mul3l >>> 16;
	wire signed [23:0] ch4l = mul4l >>> 16;
	wire signed [23:0] ch5l = mul5l >>> 16;
	wire signed [23:0] ch6l = mul6l >>> 16;
	wire signed [23:0] ch7l = mul7l >>> 16;

	wire signed [23:0] ch0r = mul0r >>> 16;
	wire signed [23:0] ch1r = mul1r >>> 16;
	wire signed [23:0] ch2r = mul2r >>> 16;
	wire signed [23:0] ch3r = mul3r >>> 16;
	wire signed [23:0] ch4r = mul4r >>> 16;
	wire signed [23:0] ch5r = mul5r >>> 16;
	wire signed [23:0] ch6r = mul6r >>> 16;
	wire signed [23:0] ch7r = mul7r >>> 16;

	wire signed [27:0] sum_l = ch0l + ch1l + ch2l + ch3l + ch4l + ch5l + ch6l + ch7l;
	wire signed [27:0] sum_r = ch0r + ch1r + ch2r + ch3r + ch4r + ch5r + ch6r + ch7r;

	wire signed [35:0] sum_l_master = $signed(sum_l) * $signed({1'b0, master_vol});
	wire signed [35:0] sum_r_master = $signed(sum_r) * $signed({1'b0, master_vol});

	wire signed [31:0] mix_l_pre = sum_l_master >>> 8;
	wire signed [31:0] mix_r_pre = sum_r_master >>> 8;
	wire signed [31:0] mix_l_limited = soft_limit(mix_l_pre);
	wire signed [31:0] mix_r_limited = soft_limit(mix_r_pre);
	wire signed [15:0] mix_l_out = clip16(mix_l_limited);
	wire signed [15:0] mix_r_out = clip16(mix_r_limited);
	wire [15:0] mix_l_abs = abs16(mix_l_out);
	wire [15:0] mix_r_abs = abs16(mix_r_out);

	reg [15:0] meter_env_l = 16'd0;
	reg [15:0] meter_env_r = 16'd0;

	function automatic signed [31:0] soft_limit(input signed [31:0] x);
		reg sign_neg;
		reg signed [31:0] ax;
		reg signed [31:0] y;
		begin
			sign_neg = x[31];
			ax = sign_neg ? -x : x;
			if (ax <= LIM_T) begin
				y = ax;
			end else begin
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

	always @(posedge clk_audio) begin
		if (reset) begin
			trig_meta <= 8'd0;
			trig_sync <= 8'd0;
			trig_prev <= 8'd0;
			sample_div <= 9'd0;
			pending_triggers <= 8'd0;
			meter_env_l <= 16'd0;
			meter_env_r <= 16'd0;
			meter_l <= 8'd0;
			meter_r <= 8'd0;
			audio_l <= 16'sd0;
			audio_r <= 16'sd0;
		end else begin
			trig_meta <= trigger_toggle;
			trig_sync <= trig_meta;
			trig_prev <= trig_sync;

			if (sample_tick) begin
				sample_div <= 9'd0;
				pending_triggers <= 8'd0;
				audio_l <= mix_l_out;
				audio_r <= mix_r_out;

				if (mix_l_abs >= meter_env_l) meter_env_l <= mix_l_abs;
				else meter_env_l <= meter_decay(meter_env_l);

				if (mix_r_abs >= meter_env_r) meter_env_r <= mix_r_abs;
				else meter_env_r <= meter_decay(meter_env_r);

				meter_l <= meter_env_l[14:7];
				meter_r <= meter_env_r[14:7];
			end else begin
				sample_div <= sample_div + 9'd1;
				pending_triggers <= pending_triggers | trig_event;
			end
		end
	end

	// 8 sample one-shot voices (BD, SD, HH, HO, CL, TL, TH, CR).
	drum_sample_voice #(.LENGTH(`KICK_LEN),  .ROM_FILE(`KICK_HEX),  .AMP_SHIFT(8)) kick     (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[0]), .sample(v0));
	drum_sample_voice #(.LENGTH(`SNARE_LEN), .ROM_FILE(`SNARE_HEX), .AMP_SHIFT(8)) snare    (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[1]), .sample(v1));
	drum_sample_voice #(.LENGTH(`HH_C_LEN),  .ROM_FILE(`HH_C_HEX),  .AMP_SHIFT(8)) hihat_c  (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[2]), .sample(v2));
	drum_sample_voice #(.LENGTH(`HH_O_LEN),  .ROM_FILE(`HH_O_HEX),  .AMP_SHIFT(8)) hihat_o  (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[3]), .sample(v3));
	drum_sample_voice #(.LENGTH(`CLAP_LEN),  .ROM_FILE(`CLAP_HEX),  .AMP_SHIFT(8)) clap     (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[4]), .sample(v4));
	drum_sample_voice #(.LENGTH(`TOM_L_LEN), .ROM_FILE(`TOM_L_HEX), .AMP_SHIFT(8)) tom_low  (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[5]), .sample(v5));
	drum_sample_voice #(.LENGTH(`TOM_H_LEN), .ROM_FILE(`TOM_H_HEX), .AMP_SHIFT(8)) tom_high (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[6]), .sample(v6));
	drum_sample_voice #(.LENGTH(`CRASH_LEN), .ROM_FILE(`CRASH_HEX), .AMP_SHIFT(7)) crash    (.clk(clk_audio), .reset(reset), .sample_tick(sample_tick), .trigger(voice_triggers[7]), .sample(v7));

	// Keep live_keys as part of v1 interface even if synthesis removes it.
	wire _unused_ok = &{1'b0, live_keys};

endmodule

module drum_sample_voice #(
	parameter integer LENGTH = 1,
	parameter ROM_FILE = "",
	parameter integer AMP_SHIFT = 10
) (
	input                    clk,
	input                    reset,
	input                    sample_tick,
	input                    trigger,
	output reg signed [17:0] sample
);

	reg signed [7:0] rom [0:LENGTH-1];
	reg [31:0] pos = 32'd0;
	reg        active = 1'b0;

	initial $readmemh(ROM_FILE, rom);

	function automatic signed [17:0] sample8_to_18(input signed [7:0] x);
		begin
			sample8_to_18 = $signed({{10{x[7]}}, x}) <<< AMP_SHIFT;
		end
	endfunction

	always @(posedge clk) begin
		if (reset) begin
			pos <= 32'd0;
			active <= 1'b0;
			sample <= 18'sd0;
		end else if (sample_tick) begin
			if (trigger) begin
				active <= 1'b1;
				pos <= 32'd0;
				sample <= sample8_to_18(rom[0]);
			end else if (active) begin
				sample <= sample8_to_18(rom[pos]);
				if (pos >= (LENGTH - 1)) begin
					active <= 1'b0;
					pos <= 32'd0;
				end else begin
					pos <= pos + 32'd1;
				end
			end else begin
				sample <= 18'sd0;
			end
		end
	end

endmodule
