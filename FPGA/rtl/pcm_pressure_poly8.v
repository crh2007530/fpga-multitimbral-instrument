`timescale 1ns/1ps
// Eight pressure notes: C5 D5 E5 F5 G5 A5 B5 C6; one shared I2S frame clock.
module pcm_pressure_poly8 #(
    parameter integer WARMUP_FRAMES=1024, DYNAMIC_PITCH=0, PER_VOICE=0,
    // Original volume restored: sum/4. +2 remains an optional high-gain setting.
    parameter integer MASTER_SHIFT=-2
)(
    input wire clk,rst_n,input wire [7:0] pressure_valid,input wire [63:0] pressure_raw,
    output wire [7:0] held,output wire bclk,lrclk,din,xsmt,
    output wire [15:0] underruns, input wire [1:0] pitch_mode, input wire [15:0] voice_modes,
    input wire test_mode,input wire [3:0] test_mask);
    // One selected octave bank applies to all eight scale notes.
    // Pitch edits never reset DDS phase or retrigger ADSR.
    wire sample_ce;
    wire signed [15:0] note_pcm[0:7];
    wire [7:0] note_valid;
    genvar v;
    generate for(v=0;v<8;v=v+1) begin: notes
        localparam [31:0] INC=(v==0) ? 32'd46774041 : (v==1) ? 32'd52502086 :
            (v==2) ? 32'd58931599 : (v==3) ? 32'd62435854 :
            (v==4) ? 32'd70081876 : (v==5) ? 32'd78664247 :
            (v==6) ? 32'd88297631 : 32'd93548082;
        wire fft=PER_VOICE && test_mode;
        wire [1:0] mode=fft ? 2'd0 : PER_VOICE ? voice_modes[v*2+:2] : pitch_mode;
        wire [7:0] input_raw=fft ? ((v<4 && test_mask[v%4]) ? 8'd96 : 8'd0) : pressure_raw[v*8+:8];
        wire [31:0] runtime_inc=(mode==1) ? (INC>>1) :
            (mode==2) ? (INC<<1) : INC;
        pcm_pressure_note #(.PHASE_INC(INC),.DYNAMIC_PITCH(DYNAMIC_PITCH),.DUAL_WAVE(PER_VOICE)) note(.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),
            .pressure_valid(fft ? 1'b1 : pressure_valid[v]),.pressure_raw(input_raw),.sine_mode(fft),
            .runtime_inc(runtime_inc),.held(held[v]),.pcm(note_pcm[v]),.pcm_valid(note_valid[v]));
    end endgenerate
    // Balanced signed adder tree. Each note is bounded by about 8192.
    wire signed [16:0] pair[0:3];
    generate for(v=0;v<4;v=v+1) begin: pairs
        assign pair[v]=$signed({note_pcm[v*2][15],note_pcm[v*2]})+
                       $signed({note_pcm[v*2+1][15],note_pcm[v*2+1]});
    end endgenerate
    wire signed [17:0] low_group=$signed({pair[0][16],pair[0]})+$signed({pair[1][16],pair[1]});
    wire signed [17:0] high_group=$signed({pair[2][16],pair[2]})+$signed({pair[3][16],pair[3]});
    wire signed [18:0] sum=$signed({low_group[17],low_group})+$signed({high_group[17],high_group});
    // Extend BEFORE shifting: sum*4 fits 21 bits even for eight full-scale
    // signed 16-bit injected samples. Saturation prevents sign-wrap distortion.
    wire signed [20:0] wide_sum={{2{sum[18]}},sum};
    wire signed [20:0] master_pcm=(MASTER_SHIFT>=0) ?
        (wide_sum<<<MASTER_SHIFT) : (wide_sum>>>(-MASTER_SHIFT));
    function signed [15:0] saturate16;
        input signed [20:0] value;
        begin
            if(value>21'sd32767) saturate16=16'sh7fff;
            else if(value< -21'sd32768) saturate16=16'sh8000;
            else saturate16=value[15:0];
        end
    endfunction
    reg signed [15:0] mixed_pcm;
    reg mixed_valid;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin mixed_pcm<=0;mixed_valid<=0;end
        else begin mixed_valid<=&note_valid;if(&note_valid) mixed_pcm<=saturate16(master_pcm);end
    end
    reg [15:0] warmup;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) warmup<=0;
        else if(sample_ce && warmup<WARMUP_FRAMES) warmup<=warmup+1'b1;
    end
    assign xsmt=rst_n && warmup>=WARMUP_FRAMES;
    i2s_tx tx(.clk(clk),.rst_n(rst_n),.sample_data(xsmt ? mixed_pcm : 16'sd0),
        .sample_valid(mixed_valid),.sample_ce(sample_ce),.bclk(bclk),.lrclk(lrclk),
        .din(din),.underruns(underruns));
endmodule
