`timescale 1ns/1ps
// 64 independent phase/envelope states; eight voices per pad in chord mode.
// Shared arithmetic in groups of eight; test frequencies are 257+83*n Hz.
// Legacy signal names test32/mask32 are widened here; protocol version identifies 64.
module pcm_pressure_poly32 #(parameter integer RAM_ENV=0,RAM_PHASE=0,VOICES=64, WARMUP_FRAMES=1024, EXPRESSION=0, FRAME_CONTROL=0, SHARED_ENGINE=1, INSTRUMENTS=0,CUSTOM_MAP=0,MULTIFX=0,THIRD_TIMBRE=0,USER_ADSR=0,MASTER_VOLUME=0,SEND_FX=0,AUTO_STRUM=1)(
 input wire clk,rst_n,input wire [7:0] pressure_valid,input wire [63:0] pressure_raw,
 input wire [15:0] voice_modes,input wire chord_mode,test_mode,test32,
 input wire [3:0] expression_config, input wire [3:0] test_mask,input wire [VOICES-1:0] mask32,
 output wire control_tick,monitor_valid,output wire signed [15:0] monitor_pcm,
 output wire [7:0] held,output wire [VOICES-1:0] held32,
 output wire bclk,lrclk,din,xsmt,output wire [15:0] underruns,input map_enabled,input[55:0] keymap,input[1:0] extra_fx,input wire epiano_mode,input wire[60:0] adsr_config,input wire[4:0] master_volume,input[32:0] send_config,input send_bypass);
 function [31:0] chord_inc;
 input integer idx;reg [31:0] lookup;
 begin case(idx%32)
            0: lookup=32'd46774041;
            1: lookup=32'd52502086;
            2: lookup=32'd58931599;
            3: lookup=32'd62435854;
            4: lookup=32'd70081876;
            5: lookup=32'd78664247;
            6: lookup=32'd88297631;
            7: lookup=32'd93548082;
            8: lookup=32'd58931599;
            9: lookup=32'd66148483;
            10: lookup=32'd74249162;
            11: lookup=32'd78664247;
            12: lookup=32'd88297631;
            13: lookup=32'd99110741;
            14: lookup=32'd111248044;
            15: lookup=32'd117863198;
            16: lookup=32'd70081877;
            17: lookup=32'd78664247;
            18: lookup=32'd88297632;
            19: lookup=32'd93548082;
            20: lookup=32'd105004171;
            21: lookup=32'd117863198;
            22: lookup=32'd132296965;
            23: lookup=32'd140163753;
            24: lookup=32'd93548082;
            25: lookup=32'd105004172;
            26: lookup=32'd117863198;
            27: lookup=32'd124871708;
            28: lookup=32'd140163752;
            29: lookup=32'd157328494;
            30: lookup=32'd176595262;
            31: lookup=32'd187096164;
 default:lookup=0;endcase chord_inc=lookup>>(idx/32);end endfunction
 function [31:0] test_inc;
 input integer idx;
 reg [63:0] numerator;
 begin
  numerator=(64'd257+64'd83*idx)*64'd4294967296;
  test_inc=(numerator*64'd512+64'd12300000)/64'd24600000;
 end endfunction
 wire sample_ce;
 wire [7:0] scheduled_valid;
 wire [63:0] scheduled_raw;
 frame_pressure scheduler(.clk(clk),.rst_n(rst_n),.control_ce(control_tick),
 .input_valid(pressure_valid),.input_raw(pressure_raw),.output_valid(scheduled_valid),.output_raw(scheduled_raw));
 wire [7:0] voice_valid=FRAME_CONTROL ? scheduled_valid : pressure_valid;
 wire [63:0] voice_raw=FRAME_CONTROL ? scheduled_raw : pressure_raw;
 wire signed [4:0] lfo;
 expression_lfo lfo_gen(.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),.level(lfo));
 wire signed [15:0] note_pcm[0:VOICES-1];wire [VOICES-1:0] note_valid,env_active;
 wire [VOICES*32-1:0] pitch_bus;
 // Guitar chord onset: four chord-degree groups separated by 576 samples.
 // Base voices remain immediate and retain their original ADC watchdog.
 wire strum_enable=AUTO_STRUM && THIRD_TIMBRE && EXPRESSION &&
     expression_config[0] && !epiano_mode && chord_mode && !test_mode;
 wire[31:0] strum_groups;
 guitar_auto_strum strummer(clk,rst_n,sample_ce,strum_enable,held32[7:0],strum_groups);
 wire [7:0] pad_stale;
 wire [VOICES*10-1:0] shared_addresses;
 wire [VOICES*16-1:0] shared_forces,shared_envelopes,shared_samples;
 wire[VOICES*16-1:0] played_envelopes;
 wire[7:0] custom_active;wire[15:0] custom_level[0:7];reg[VOICES-1:0] custom_members;integer m;
 wire custom_enable=USER_ADSR && adsr_config[60] && !test_mode;
 genvar ce;
 generate if(USER_ADSR)begin:custom_adsr
 for(ce=0;ce<8;ce=ce+1)begin:pad
 adjustable_adsr env(.clk(clk),.rst_n(rst_n),.ce(sample_ce),.gate(held32[ce]),.enable(custom_enable),
 .attack_step(adsr_config[14:0]),.decay_step(adsr_config[29:15]),.sustain_level(adsr_config[44:30]),.release_step(adsr_config[59:45]),
 .level(custom_level[ce]),.active(custom_active[ce]));
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)custom_members<=0;
 else if(sample_ce)begin
  if(!custom_enable)custom_members<=0;
  else for(m=0;m<VOICES;m=m+1)begin
   if(held32[m])custom_members[m]<=1;
   else if(!custom_active[m%8])custom_members[m]<=0;
  end
 end
 end endgenerate
 generate for(ce=0;ce<VOICES;ce=ce+1)begin:envelope_route
 assign played_envelopes[ce*16+:16]=custom_enable ? (custom_members[ce]?custom_level[ce%8]:16'd0):shared_envelopes[ce*16+:16];
 end endgenerate
 wire shared_valid;wire[VOICES*16-1:0] shared_increments;
 wire[1023:0] pitch_targets;
 wire batch_valid,batch_busy,batch_overrun;wire[4:0] batch_index;wire[31:0] batch_increment;

 wire[VOICES*10-1:0]ram_addresses;
 wire[VOICES-1:0]phase_resets;
 wire[VOICES-1:0]envelope_on,envelope_off,ram_env_active;
 wire[VOICES*16-1:0]ram_env_levels;wire ram_envelope_fault;
 wire env_write;wire[5:0]env_write_index;wire[31:0]env_write_levels;
 generate if(RAM_ENV)begin:shared_envelopes_ram
 streamed_envelope_bank #(.VOICES(VOICES)) envbank(clk,rst_n,sample_ce,envelope_on,envelope_off,test_mode,epiano_mode||expression_config[0],env_write_levels,ram_env_active,ram_envelope_fault,env_write,env_write_index);
 assign ram_env_levels=0;
 end else begin assign ram_env_levels=0;assign ram_env_active=0;assign ram_envelope_fault=0;assign env_write=0;assign env_write_index=0;assign env_write_levels=0;end endgenerate
 wire ram_phase_fault,state_batch_valid;wire[4:0]state_batch_index;wire[31:0]state_batch_increment;
 wire bank_sample_ce;
 generate if(RAM_PHASE)begin:ram_phases
 ram_phase_bank #(.VOICES(VOICES)) phases(clk,rst_n,sample_ce,batch_valid,batch_index,batch_increment,test_mode,test32,phase_resets,ram_addresses,ram_phase_fault);
 reg[5:0]request_pipe,valid_pipe;reg[4:0]index_pipe[0:5];reg[31:0]increment_pipe[0:5];integer q;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin request_pipe<=0;valid_pipe<=0;for(q=0;q<6;q=q+1)begin index_pipe[q]<=0;increment_pipe[q]<=0;end end
  else begin
   request_pipe<={request_pipe[4:0],sample_ce};valid_pipe<={valid_pipe[4:0],batch_valid};
   index_pipe[0]<=batch_index;increment_pipe[0]<=batch_increment;
   for(q=1;q<6;q=q+1)begin index_pipe[q]<=index_pipe[q-1];increment_pipe[q]<=increment_pipe[q-1];end
  end
 end
 assign bank_sample_ce=request_pipe[5];assign state_batch_valid=valid_pipe[5];assign state_batch_index=index_pipe[5];assign state_batch_increment=increment_pipe[5];
 end else begin
 assign ram_addresses=0;assign ram_phase_fault=0;assign bank_sample_ce=sample_ce;
 assign state_batch_valid=batch_valid;assign state_batch_index=batch_index;assign state_batch_increment=batch_increment;
 end endgenerate
 reg captured_test,captured_test32;
 reg odd_batch_valid;reg[4:0]odd_batch_index;reg[31:0]odd_batch_increment;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin odd_batch_valid<=0;odd_batch_index<=0;odd_batch_increment<=0;end
 else begin odd_batch_valid<=state_batch_valid;odd_batch_index<=state_batch_index;odd_batch_increment<=state_batch_increment;end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin captured_test<=0;captured_test32<=0;end
 else if(sample_ce)begin captured_test<=test_mode;captured_test32<=test32;end
 generate if(SHARED_ENGINE && EXPRESSION)begin: batch_pitch
 shared_pitch_engine #(.CUSTOM_MAP(CUSTOM_MAP),.COMPACT_TARGETS(1)) batch(.diagnostic_mode(test_mode),.all_test(test32),.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),
 .map_enabled(map_enabled && !test_mode),.keymap(keymap),.modes(voice_modes),
 .glide(!test_mode && expression_config[1]),.vibrato(!test_mode && expression_config[2]),
 .targets(pitch_targets),.lfo(lfo),.valid(batch_valid),.index(batch_index),.increment(batch_increment),
 .busy(batch_busy),.overrun(batch_overrun));
 end endgenerate
 generate if(SHARED_ENGINE)begin: shared_compute
 if(RAM_ENV)begin:buffered
 buffered_voice_bank #(.PAIR_STATE_RAM(RAM_PHASE),.COUNTER_SCHED(RAM_PHASE),.VOICES(VOICES),.GROUP(64),.THIRD_TIMBRE(THIRD_TIMBRE),.SUM_ONLY(THIRD_TIMBRE)) bank(.increments(shared_increments),.gates(held32),.diagnostic_mode(test_mode),.epiano_mode(epiano_mode && !test_mode),.clk(clk),.rst_n(rst_n),.sample_ce(bank_sample_ce),
 .sine_mode(test_mode || (EXPRESSION && expression_config[0])),
 .addresses(shared_addresses),.forces(shared_forces),.envelopes(played_envelopes),
 .samples(shared_samples),.valid(shared_valid),.env_write(env_write),.env_write_index(env_write_index),.env_write_levels(env_write_levels),.custom_env(custom_enable));
 end else begin:original
 shared_voice_bank #(.PAIR_STATE_RAM(RAM_PHASE),.COUNTER_SCHED(RAM_PHASE),.VOICES(VOICES),.GROUP(64),.THIRD_TIMBRE(THIRD_TIMBRE),.SUM_ONLY(THIRD_TIMBRE)) bank(.increments(shared_increments),.gates(held32),.diagnostic_mode(test_mode),.epiano_mode(epiano_mode && !test_mode),.clk(clk),.rst_n(rst_n),.sample_ce(bank_sample_ce),
 .sine_mode(test_mode || (EXPRESSION && expression_config[0])),
 .addresses(shared_addresses),.forces(shared_forces),.envelopes(played_envelopes),
 .samples(shared_samples),.valid(shared_valid));
 end
 end endgenerate
 genvar v;
 generate for(v=0;v<VOICES;v=v+1)begin:notes
   wire voice_batch_valid=(RAM_PHASE && (v/64)%2==1)?odd_batch_valid:state_batch_valid;
   wire[4:0]voice_batch_index=(RAM_PHASE && (v/64)%2==1)?odd_batch_index:state_batch_index;
   wire[31:0]voice_batch_increment=(RAM_PHASE && (v/64)%2==1)?odd_batch_increment:state_batch_increment;
   localparam integer PAD=v%8;
   localparam [31:0] INC=chord_inc(v);
   wire [1:0] mode=voice_modes[PAD*2+:2];
   wire strum_allowed=!strum_enable || strum_groups[((v/8)%4)*8+PAD];
   wire enabled=test_mode ? (test32 ? mask32[v] : (v<4 && test_mask[v%4])) : ((v<8 || chord_mode) && strum_allowed);
   wire [7:0] level=test_mode ? (enabled ? 8'd96 : 8'd0) : (enabled ? voice_raw[PAD*8+:8] : 8'd0);
   wire [31:0] runtime_inc=test_mode ? (test32 ? test_inc(v) : chord_inc(PAD)) :
       mode==1 ? (INC>>1) : mode==2 ? (INC<<1) : INC;
   wire [31:0] expressive_inc;
   if(v<32)assign pitch_targets[v*32+:32]=runtime_inc;
   if(SHARED_ENGINE && EXPRESSION)begin: scheduled_pitch
    if(v<32)assign expressive_inc=voice_batch_increment;
    else assign expressive_inc=captured_test ? (captured_test32 ? test_inc(v) : chord_inc(PAD)) : (voice_batch_increment>>(v/32));
   end else if(v<32)begin: pitch_pair_base
   expression_pitch_dsp pitch_fx(.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),
    .glide(EXPRESSION && !test_mode && expression_config[1]),
    .vibrato(EXPRESSION && !test_mode && expression_config[2]),
    .target(runtime_inc),.lfo(lfo),.phase_inc(expressive_inc));
   end else begin: pitch_pair_octave
   // Octave partners share musical expression, but retain independent phase,
   // envelope, gain and test-frequency control. Test mode bypasses the pair.
   assign expressive_inc=test_mode ? runtime_inc : (pitch_bus[(v%32)*32+:32]>>(v/32));
   end
   assign pitch_bus[v*32+:32]=expressive_inc;
   if(SHARED_ENGINE)begin: shared_state
   wire stale_local;
   if(v<8)assign pad_stale[PAD]=stale_local;
   pressure_voice_state #(.EXTERNAL_ENV(RAM_ENV),.RAM_PHASE(RAM_PHASE),.SHARED_STALE(v>=8),.DEFER_PHASE(EXPRESSION),.INSTRUMENTS(INSTRUMENTS),.THIRD_TIMBRE(THIRD_TIMBRE)) state(.external_level(ram_env_levels[v*16+:16]),.external_active(ram_env_active[v]),.on_event(envelope_on[v]),.off_event(envelope_off[v]),.legacy_envelope_snapshot(),.ram_address(ram_addresses[v*10+:10]),.phase_reset(phase_resets[v]),.shared_stale(pad_stale[PAD]),.stale_out(stale_local),.epiano_mode(epiano_mode),.flute_mode(expression_config[0]),.test_mode(test_mode),.phase_ce(voice_batch_valid && voice_batch_index==(v%32)),.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),
    .pressure_valid(test_mode || !enabled ? 1'b1 : voice_valid[PAD]),.pressure_raw(level),
    .phase_inc(EXPRESSION ? expressive_inc : runtime_inc),.held(held32[v]),.envelope_active(env_active[v]),
    .increment_snapshot(shared_increments[v*16+:16]),.address(shared_addresses[v*10+:10]),.force_snapshot(shared_forces[v*16+:16]),
    .envelope_snapshot(shared_envelopes[v*16+:16]));
   assign note_pcm[v]=shared_samples[v*16+:16];
   assign note_valid[v]=shared_valid;
   end else begin: legacy_state
   pcm_pressure_note #(.PHASE_INC(INC),.DYNAMIC_PITCH(1),.DUAL_WAVE(1)) note(
    .clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),
    .pressure_valid(test_mode || !enabled ? 1'b1 : voice_valid[PAD]),.pressure_raw(level),
    .runtime_inc(EXPRESSION ? expressive_inc : runtime_inc),.sine_mode(test_mode || (EXPRESSION && expression_config[0])),.held(held32[v]),.pcm(note_pcm[v]),.pcm_valid(note_valid[v]),.envelope_active(env_active[v]));
   end
 end endgenerate
 // Physical pressure summary is separate at top; this is audio gate metadata.
 reg[7:0] held_reduce;integer hi;
 always @*begin held_reduce=0;for(hi=0;hi<VOICES;hi=hi+8)held_reduce=held_reduce|held32[hi+:8];end
 assign held=held_reduce;
 localparam SUM_W=16+$clog2(VOICES);
 reg signed[SUM_W-1:0] legacy_sum;integer si;
 always @*begin legacy_sum=0;for(si=0;si<VOICES;si=si+1)legacy_sum=legacy_sum+$signed(note_pcm[si]);end
 wire signed[SUM_W-1:0] sum=(SHARED_ENGINE && THIRD_TIMBRE)?$signed(shared_samples[SUM_W-1:0]):legacy_sum;
 wire expanded=(test_mode && test32)||(!test_mode && chord_mode)||(|env_active[VOICES-1:8])||(custom_enable && |custom_members[VOICES-1:8]);
 // One additional bit of headroom at 128 voices; single-note level unchanged.
 wire signed[SUM_W-1:0] scaled=expanded?(sum>>>($clog2(VOICES)-1)):(sum>>>2);
 function signed[15:0] sat;input signed[SUM_W-1:0] x;
 begin if(x>32767)sat=16'sh7fff;else if(x< -32768)sat=16'sh8000;else sat=x[15:0];end endfunction
 reg signed [15:0] mixed_pcm;reg mixed_valid;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin mixed_pcm<=0;mixed_valid<=0;end
 else begin mixed_valid<=&note_valid;if(&note_valid)mixed_pcm<=sat(scaled);end
 reg [15:0] warmup;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)warmup<=0;else if(sample_ce && warmup<WARMUP_FRAMES)warmup<=warmup+1'b1;
 assign xsmt=rst_n && warmup>=WARMUP_FRAMES;
 wire signed [15:0] fx_pcm,echo_pcm,reverb_pcm;wire fx_valid,echo_valid,reverb_valid;
 generate if(SEND_FX)begin: sends
 audio_send_fx bus(clk,rst_n,mixed_valid,mixed_pcm,send_config,{extra_fx[1],expression_config[3],extra_fx[0]},send_bypass,test_mode,fx_valid,fx_pcm);
 end else begin: legacy_fx
 if(EXPRESSION)begin: effects
 audio_echo echo(.clk(clk),.rst_n(rst_n),.enable(!test_mode && expression_config[3]),
 .input_valid(mixed_valid),.input_pcm(mixed_pcm),.output_valid(echo_valid),.output_pcm(echo_pcm));
 end else begin assign echo_pcm=mixed_pcm;assign echo_valid=mixed_valid;end
 if(MULTIFX)begin: extended_effects
 audio_reverb reverb(clk,rst_n,!test_mode && extra_fx[0],echo_valid,echo_pcm,reverb_valid,reverb_pcm);
 audio_chorus chorus(clk,rst_n,!test_mode && extra_fx[1],reverb_valid,reverb_pcm,fx_valid,fx_pcm);
 end else begin assign fx_pcm=echo_pcm;assign fx_valid=echo_valid;end
 end endgenerate
 // Master gain +6.02 dB after effects. Widen BEFORE doubling, then saturate;
 // a 16-bit shift would wrap the sign on loud samples. No added sample latency.
 wire signed [16:0] boosted_pcm=$signed({fx_pcm,1'b0});
 wire signed [15:0] loud_pcm=(boosted_pcm>17'sd32767) ? 16'sh7fff :
                          (boosted_pcm< -17'sd32768) ? 16'sh8000 : boosted_pcm[15:0];
 assign monitor_valid=fx_valid;
 // 0..16 attenuation, unity at 16 preserves V20 timbres and peak level.
 // Signed multiplication is widened; no sample or pipeline delay is added.
 wire[4:0] gain=master_volume>16?5'd16:master_volume;
 wire signed[21:0] volume_product=$signed(loud_pcm)*$signed({1'b0,gain});
 wire signed[15:0] volume_pcm=volume_product[19:4];
 assign monitor_pcm=xsmt ? (MASTER_VOLUME?volume_pcm:loud_pcm) : 16'sd0;
 i2s_tx #(.REQUEST_BIT(VOICES==128?39:51)) tx(.control_ce(control_tick),.clk(clk),.rst_n(rst_n),.sample_data(monitor_pcm),
 .sample_valid(fx_valid),.sample_ce(sample_ce),.bclk(bclk),.lrclk(lrclk),.din(din),.underruns(underruns));
endmodule


