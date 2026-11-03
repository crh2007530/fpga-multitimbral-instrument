`timescale 1ns/1ps
// One independent pressure note. PCM peak is <=8192 before the fixed mixer gain.
module pcm_pressure_note #(
    parameter [31:0] PHASE_INC=32'd23387020,
    parameter integer DYNAMIC_PITCH=0, DUAL_WAVE=0,
    parameter integer AUDIO_HZ=24600000,ON_RAW=20,OFF_RAW=10
)(input wire clk,rst_n,sample_ce,pressure_valid,input wire [7:0] pressure_raw,
    input wire [31:0] runtime_inc,
    output reg held,output reg signed [15:0] pcm,output reg pcm_valid, input wire sine_mode,output wire envelope_active);
    localparam integer STALE_CYCLES=AUDIO_HZ/100;
    reg note_on,note_off;
    reg [15:0] force_hold;
    reg [31:0] age;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin held<=0;note_on<=0;note_off<=0;force_hold<=0;age<=STALE_CYCLES;end
        else begin
            note_on<=0;note_off<=0;
            if(pressure_valid) begin
                age<=0;
                if(!held && pressure_raw>=ON_RAW) begin held<=1;note_on<=1;end
                else if(held && pressure_raw<=OFF_RAW) begin held<=0;note_off<=1;end
                if(pressure_raw>OFF_RAW) force_hold<={1'b0,pressure_raw,7'b0};
            end else begin
                if(age<STALE_CYCLES) age<=age+1'b1;
                if(age>=STALE_CYCLES && held) begin held<=0;note_off<=1;end
            end
        end
    end
    wire [15:0] envelope;
    adsr_env env(.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),
        .note_on(note_on),.note_off(note_off),.level(envelope),.active(envelope_active),.state());
    wire signed [15:0] sine_sample;
    wire sine_valid;
    dds_osc #(.DUAL_WAVE(DUAL_WAVE),.ROM_FILE("assets/bright_1024_16.hex")) sine(.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),.enable(rst_n),
        .sine_mode(sine_mode),.phase_inc(DYNAMIC_PITCH ? runtime_inc : PHASE_INC),.sample_out(sine_sample),.sample_valid(sine_valid));
    reg [31:0] gain_product;
    reg signed [15:0] delayed_sine;
    reg signed [32:0] audio_product;
    reg stage1,stage2;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin gain_product<=0;delayed_sine<=0;audio_product<=0;pcm<=0;stage1<=0;stage2<=0;pcm_valid<=0;end
        else begin
            stage1<=sine_valid;stage2<=stage1;pcm_valid<=stage2;
            if(sine_valid) begin gain_product<=force_hold*envelope;delayed_sine<=sine_sample;end
            if(stage1) audio_product<=$signed(delayed_sine)*$signed({1'b0,gain_product[30:15]});
            if(stage2) pcm<=audio_product>>>17;
        end
    end
endmodule
