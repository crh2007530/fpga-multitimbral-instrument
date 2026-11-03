`timescale 1ns/1ps
// Keep proven ADC and 115200 telemetry on the real 50 MHz clock. Only sound
// uses the generated audio clock; eight channels cross with independent mailboxes.
module pressure_poly8_top #(parameter integer DEMO=0,OLED_TELEMETRY=1,TRAINER_CLOCK_HZ=50000000,BT_CLOCK_HZ=50000000,BT_BAUD=115200,SPECTRUM_HOP=512,SPECTRUM_WINDOW=1,CLIP_ADDR_BITS=15)(
    input wire encoder_a,encoder_b,pluck_ir,
    input wire volume_a,volume_b,game_button_n,fx_button_n,
    input wire bt_rx,output wire bt_tx,
    output wire hdmi_power,output wire hdmi_clk_p,hdmi_clk_n,output wire[2:0] hdmi_data_p,hdmi_data_n,
    input wire clk_50m,inout wire adc0_scl,adc0_sda,adc1_scl,adc1_sda,
    output wire i2s_bclk,i2s_lrclk,i2s_din,xsmt,debug_tx,status_led,
    output wire pcm2_bclk,pcm2_lrclk,pcm2_din,pcm2_xsmt,
    output wire apds_scl,inout wire apds_sda,
    output wire dout,oled_scl,inout wire oled_sda,output wire ttp_scl,input wire ttp_sdo);
    reg [7:0] startup=0;
    wire rst_n=&startup;
    always @(posedge clk_50m) if(!rst_n) startup<=startup+1'b1;
    wire [31:0] time_us;
    timebase_us #(.CLOCK_HZ(50000000)) timer(.clk(clk_50m),.rst_n(rst_n),.time_us(time_us));
    wire [63:0] raw;
    wire [7:0] raw_valid;
    wire [255:0] stamps;
    wire [15:0] errors0,errors1;
    wire overdue0,overdue1;
    pcf8591_scan #(.ADDRESS(7'h48),.SCAN_CYCLES(75000),.QUARTER_CYCLES(125),.TIMEOUT_CYCLES(50000)) adc0(
        .clk(clk_50m),.rst_n(rst_n),.time_us(time_us),.scl(adc0_scl),.sda(adc0_sda),
        .raw(raw[31:0]),.raw_valid(raw_valid[3:0]),.sampled_at(stamps[127:0]),
        .scans(),.errors(errors0),.overdue(overdue0));
    pcf8591_scan #(.ADDRESS(7'h48),.SCAN_CYCLES(75000),.QUARTER_CYCLES(125),.TIMEOUT_CYCLES(50000)) adc1(
        .clk(clk_50m),.rst_n(rst_n),.time_us(time_us),.scl(adc1_scl),.sda(adc1_sda),
        .raw(raw[63:32]),.raw_valid(raw_valid[7:4]),.sampled_at(stamps[255:128]),
        .scans(),.errors(errors1),.overdue(overdue1));
    reg [7:0] seen;
    always @(posedge clk_50m) if(!rst_n) seen<=0;else seen<=seen|raw_valid;
    wire [7:0] stale;
    genvar ch;
    generate for(ch=0;ch<8;ch=ch+1) begin: freshness
        reg[31:0] age_q;reg seen_q,stale_q;
        always @(posedge clk_50m)begin
          if(!rst_n)begin age_q<=0;seen_q<=0;stale_q<=0;end
          else begin age_q<=time_us-stamps[ch*32+:32];seen_q<=seen[ch];stale_q<=seen_q && age_q>32'd10000;end
        end
        assign stale[ch]=stale_q;
    end endgenerate
    wire audio_clk,locked;
    audio_pll u_audio_pll(.clkin(clk_50m),.mdclk(clk_50m),.clkout0(audio_clk),.lock(locked));
    reg [2:0] release_audio=0;
    always @(posedge audio_clk or negedge locked) begin
        if(!locked) release_audio<=0;else release_audio<={release_audio[1:0],rst_n};
    end
    wire audio_rst_n=release_audio[2];
    reg [1:0] release_mailbox=0;
    always @(posedge clk_50m or negedge audio_rst_n) begin
        if(!audio_rst_n) release_mailbox<=0;
        else release_mailbox<={release_mailbox[0],rst_n};
    end
    wire [7:0] audio_valid;
    wire [63:0] audio_raw;
    genvar pad;
    generate for(pad=0;pad<8;pad=pad+1) begin: pad_crossing
        sample_mailbox mailbox(.src_clk(clk_50m),.src_rst_n(release_mailbox[1]),
            .src_valid(raw_valid[pad]),.src_data(raw[pad*8+:8]),.dst_clk(audio_clk),
            .dst_rst_n(audio_rst_n),.dst_valid(audio_valid[pad]),.dst_data(audio_raw[pad*8+:8]));
    end endgenerate
    wire [7:0] held_audio;
    wire [15:0] underruns;
    wire [63:0] demo_raw;
    generate if(DEMO) begin:demo_enabled
        scale_demo demo(.clk(audio_clk),.rst_n(audio_rst_n),.raw(demo_raw));
    end else begin:demo_disabled
        assign demo_raw=64'd0;
    end endgenerate
    wire [1:0] pitch_mode;
    wire [7:0] touch_keys;
    wire touch_valid;
    wire [7:0] touch_raw_keys;wire touch_raw_valid;
    wire [31:0] touch_scans;wire [15:0] touch_full,touch_commands;
    wire [7:0] touch_last_command;wire touch_sdo_level;
    // 2.5ms recovery plus 16-bit scan; two matching frames still required.
    ttp229_pitch #(.GAP_CYCLES(125000)) touch(.clk(clk_50m),.rst_n(rst_n),.scl(ttp_scl),.sdo(ttp_sdo),
        .keys(touch_raw_keys),.frame_valid(touch_raw_valid),.pitch_mode(),
        .scan_count(touch_scans),.full_keys(touch_full),.sdo_level(touch_sdo_level));
    wire test_mode;wire [7:0] pressure_held;
    wire trainer_active,trainer_running,trainer_done,trainer_wait,trainer_exit,trainer_beat;
    touch_command_guard touch_guard(.clk(clk_50m),.rst_n(rst_n),
      .frame_valid(touch_raw_valid),.raw_keys(touch_raw_keys),
      .slow_test(!trainer_active && !test_mode),.valid(touch_valid),.keys(touch_keys));
    wire [1:0] trainer_song,trainer_tempo;
    wire [4:0] trainer_step;wire [2:0] trainer_count;
    wire [7:0] trainer_hits,trainer_misses,trainer_wrong,trainer_target,trainer_next,trainer_light_target;
    wire [47:0] trainer_status;
    wire fx_click;reg manual_fx_bypass;wire fx_bypass;wire gesture_fx_bypass;wire panel_click;wire[4:0] volume_level;wire[6:0] volume_percent;
    wire [127:0] game_data,game_raw;
    reg practice_mode;wire bt_practice_start,local_practice_start;
    wire[2:0] led_event;wire[7:0] led_mask;
    // Unused high HUD bits carry explicit audio mode; atomic video snapshot.
    assign game_data={game_raw[127:101],trainer_active && (practice_mode || game_raw[100]),game_raw[99:31],trainer_active && !practice_mode,game_raw[29:0]} | {test_mode,test32,chord_mode,{expression_config[3] && !fx_bypass,expression_config[2:0]},epiano_mode,(fx_bypass ? 2'd0 : mixer_extra),fx_bypass,volume_percent,game_energy[7:3],timed_enabled,trainer_tempo,expression_config[0],101'd0};
    wire bt_command_pending;wire bt_key_valid,bt_trainer_toggle,bt_visual_valid,bt_control_lock;
    wire[7:0] bt_key_mask;wire[5:0] bt_effect_events;wire[1:0] bt_visual_select;
    wire control_tick,visual_valid;wire[15:0] visual_pcm;
    wire ext_tx_valid,ext_tx_ready,ext_busy,ext_rx_valid,ext_rx_error;
    wire stream_busy,stream_start,stream_stop,stream_recording,stream_tx_valid,stream_tx_ready,stream_packet;
    wire[7:0] stream_tx_data;wire[31:0] stream_dropped;wire mux_tx_ready;
    wire[1:0] pluck_config;wire[60:0] adsr_config;
    wire[7:0] ext_tx_data,ext_rx_data;wire[1:0] extra_fx;wire chart_enabled,map_enabled;wire[255:0] user_chart;wire[55:0] keymap;
    wire extra_fx_write;wire title_write,title_valid;wire[8:0] title_address;wire[7:0] title_data;
    wire chart_begin,chart_write,chart_commit,chart_disable,timed_enabled,timed_ready;
    wire[10:0] chart_count,timed_count;wire[9:0] chart_address,timed_position;
    wire[23:0] chart_event;wire[39:0] timed_masks;wire[79:0] timed_durations;
    wire signed[17:0] due_delta;wire[79:0] preview_deltas;
    timed_chart_store scores(clk_50m,rst_n,chart_begin,chart_count,chart_write,chart_address,chart_event,
      chart_commit,chart_disable,timed_position,timed_enabled,timed_count,timed_masks,timed_durations,timed_ready);
    wire[39:0] preview_masks;wire preview_ready;
    timed_chart_preview preview(clk_50m,rst_n,timed_ready,timed_position,due_delta,timed_masks,timed_durations,
      preview_deltas,preview_masks,preview_ready);

    bt_extensions #(.CLOCK_HZ(BT_CLOCK_HZ),.CLIP_ADDR_BITS(CLIP_ADDR_BITS),.LEGACY_CHART(0)) extensions(
      .clk(clk_50m),.rst_n(rst_n),.rx_data(ext_rx_data),.rx_valid(ext_rx_valid),.rx_error(ext_rx_error),
      .tx_valid(ext_tx_valid),.tx_data(ext_tx_data),.tx_ready(ext_tx_ready),.busy(ext_busy),
      .game_active(trainer_active),.pressed(pressure_held),.sample_valid(visual_valid),.pcm(visual_pcm),
      .chart_enabled(chart_enabled),.chart_data(user_chart),.map_enabled(map_enabled),.keymap(keymap),.extra_fx(extra_fx),.extra_fx_write(extra_fx_write),.pluck_config(pluck_config),.adsr_config(adsr_config),.stream_start(stream_start),.stream_stop(stream_stop),.stream_recording(stream_busy),.chart_begin(chart_begin),.chart_count(chart_count),.chart_write(chart_write),.chart_address(chart_address),.chart_event(chart_event),.chart_commit(chart_commit),.chart_disable(chart_disable),.title_write(title_write),.title_address(title_address),.title_data(title_data),.title_valid(title_valid));
    pcm_uart_stream streaming(.clk(clk_50m),.rst_n(rst_n),.start(stream_start),.stop(stream_stop),
      .sample_valid(visual_valid),.pcm(visual_pcm),.pause_new(ext_busy || bt_command_pending),.tx_valid(stream_tx_valid),.tx_data(stream_tx_data),
      .tx_ready(stream_tx_ready),.packet_active(stream_packet),.recording(stream_recording),.dropped(stream_dropped),.busy(stream_busy));
    assign ext_tx_ready=mux_tx_ready && !stream_packet;
    assign stream_tx_ready=mux_tx_ready && stream_packet;
    bluetooth_control #(.CLOCK_HZ(BT_CLOCK_HZ),.BAUD(BT_BAUD),.FEATURES(1),.PRACTICE(1)) bluetooth(
      .clk(clk_50m),.rst_n(rst_n),.rx(bt_rx),.tx(bt_tx),.test_mode(test_mode),
      .trainer_active(trainer_active),.trainer_running(trainer_running),.trainer_done(trainer_done),
      .key_valid(bt_key_valid),.key_mask(bt_key_mask),.trainer_toggle(bt_trainer_toggle),
      .effect_events(bt_effect_events),.visual_valid(bt_visual_valid),.visual_select(bt_visual_select),.control_lock(bt_control_lock),.ext_tx_valid(stream_packet?stream_tx_valid:ext_tx_valid),.ext_tx_data(stream_packet?stream_tx_data:ext_tx_data),.ext_busy(ext_busy || stream_packet),.ext_tx_ready(mux_tx_ready),.rx_data_out(ext_rx_data),.rx_valid_out(ext_rx_valid),.rx_error_out(ext_rx_error),.command_pending(bt_command_pending),.practice_mode(practice_mode),.practice_start(bt_practice_start));
    rhythm_game #(.CLOCK_HZ(TRAINER_CLOCK_HZ),.REMOTE(1),.CUSTOM_CHART(0),.TIMED_CHART(1),.PHYSICAL_CONTROL(1)) trainer(.led_event(led_event),.led_mask(led_mask),.panel_click(panel_click),.user_chart(user_chart),.chart_enabled(chart_enabled),.remote_valid(bt_key_valid),.remote_keys(bt_key_mask),.remote_toggle(bt_trainer_toggle || local_practice_start),.local_inhibit(1'b0),.clk(clk_50m),.rst_n(rst_n),.frame_valid(touch_valid),.keys(touch_keys),
      .test_mode(test_mode),.pressed(pressure_held),.active(trainer_active),.running(trainer_running),
      .done(trainer_done),.wait_mode(trainer_wait),.song(trainer_song),.tempo(trainer_tempo),
      .step_index(trainer_step),.count_in(trainer_count),.hits(trainer_hits),.misses(trainer_misses),
      .wrong(trainer_wrong),.target(trainer_target),.light_target(trainer_light_target),.next_target(trainer_next),.beat_flash(trainer_beat),
      .exit_pulse(trainer_exit),.status(trainer_status),.game_data(game_raw),.timed_enabled(timed_enabled),.timed_count(timed_count),.timed_masks(timed_masks),.timed_durations(timed_durations),.timed_ready(timed_ready),.timed_position(timed_position),.due_delta(due_delta));
    wire [15:0] voice_modes;
    wire [3:0] selected,test_mask;
    wire chord_mode,test32;wire [6:0] selected_test;wire [127:0] mask32;
    performance_controls #(.TEST_VOICES(128),.EXPANSION(1),.EXTERNAL_CLEAR(1),.REMOTE(1)) controls(.remote_valid(bt_key_valid && !trainer_active),.remote_keys(bt_key_mask),.clear(trainer_exit),.clk(clk_50m),.rst_n(rst_n),.keys(touch_keys),.frame_valid(touch_valid && !trainer_active),
      .modes(voice_modes),.selected(selected),.test_mode(test_mode),.test_mask(test_mask),.selected_mode(pitch_mode),
      .command_count(touch_commands),.last_command(touch_last_command),.chord_mode(chord_mode),
      .test32(test32),.selected_test(selected_test),.mask32(mask32));
    wire [5:0] gesture_events;
    wire [3:0] expression_config;
    wire enc_inc,enc_dec,enc_click;

    panel_controls panel(.clk(clk_50m),.rst_n(rst_n),.a(volume_a),.b(volume_b),
      .key_n(1'b1),.volume(volume_level),.percent(volume_percent),.click());
    reg [15:0] last_command_count;
    wire mixer_open,select_short,select_long,mixer_active;
    wire[3:0] mixer_item;wire[32:0] mixer_config;wire[2:0] mixer_enable,mixer_edited;
    wire[1:0] mixer_echo_preset,mixer_chorus_preset;
    wire[1:0] mixer_extra={mixer_enable[2],mixer_enable[0]};
    ui_press fx_button(clk_50m,rst_n,fx_button_n,fx_click,mixer_open);
    ui_press select_button(clk_50m,rst_n,game_button_n,select_short,select_long);
    // Long press from free play enters white-page lesson; short press enters game.
    assign local_practice_start=select_long && !mixer_active && !trainer_active && !test_mode && !bt_control_lock;
    assign panel_click=(select_short || (select_long && trainer_active)) && !mixer_active;
    always @(posedge clk_50m or negedge rst_n)
      if(!rst_n)practice_mode<=0;
      else if(bt_practice_start || local_practice_start)practice_mode<=1;
      else if(!trainer_active || trainer_exit)practice_mode<=0;
    wire[1:0] mixer_instrument,instrument_mode;
    instrument_mixer_controls mixer(clk_50m,rst_n,test_mode || trainer_active,mixer_open,select_short,select_long,enc_inc,enc_dec,
      {extra_fx[1],expression_bits[3],extra_fx[0]},mixer_active,mixer_item,mixer_config,mixer_enable,mixer_echo_preset,mixer_chorus_preset,mixer_edited,extra_fx_write,musical_events[1] && !test_mode,trainer_exit || touch_commands!=last_command_count && touch_last_command==8'h80,instrument_mode,mixer_instrument);
    wire[32:0] mixer_audio;reg[32:0] mixer_frame;
    sample_mailbox #(.WIDTH(33)) mixer_cross(clk_50m,release_mailbox[1],1'b1,mixer_config,audio_clk,audio_rst_n,,mixer_audio);
    always @(posedge audio_clk or negedge audio_rst_n)
      if(!audio_rst_n)mixer_frame<={2'd0,2'd0,5'd4,3'd2,2'd0,5'd4,2'd0,2'd0,5'd4,5'd16};
      else if(control_tick)mixer_frame<=mixer_audio;
    wire[63:0] mixer_display={6'd0,mixer_instrument,volume_percent,fx_bypass,mixer_edited,mixer_chorus_preset,mixer_echo_preset,mixer_enable,mixer_item,mixer_active,mixer_config};
    always @(posedge clk_50m or negedge rst_n)
      if(!rst_n)manual_fx_bypass<=0;else if(fx_click && !test_mode)manual_fx_bypass<=~manual_fx_bypass;
    gesture_fx_hold gesture_hold(clk_50m,rst_n,test_mode,bt_control_lock,gesture_events,gesture_fx_bypass);
    assign fx_bypass=manual_fx_bypass | gesture_fx_bypass;
    wire[5:0] volume_audio;reg[4:0] volume_frame;reg fx_bypass_frame;
    sample_mailbox #(.WIDTH(6)) volume_cross(.src_clk(clk_50m),.src_rst_n(release_mailbox[1]),
      .src_valid(1'b1),.src_data({fx_bypass,volume_level}),.dst_clk(audio_clk),.dst_rst_n(audio_rst_n),
      .dst_valid(),.dst_data(volume_audio));
    always @(posedge audio_clk or negedge audio_rst_n)
      if(!audio_rst_n)begin volume_frame<=16;fx_bypass_frame<=0;end
      else if(control_tick)begin volume_frame<=volume_audio[4:0];fx_bypass_frame<=volume_audio[5];end

    encoder_input encoder(.clk(clk_50m),.rst_n(rst_n),.a(encoder_a),.b(encoder_b),.key_n(1'b1),.inc(enc_inc),.dec(enc_dec),.click(enc_click));
    wire[3:0] expression_bits;

    wire epiano_mode=instrument_mode==2;
    wire[5:0] musical_events=(bt_control_lock ? 6'd0 : gesture_events) | bt_effect_events;
    assign expression_config={mixer_enable[1],expression_bits[2:1],instrument_mode==1};
    instrument_select instruments(.clk(clk_50m),.rst_n(rst_n),
      .clear(trainer_exit || touch_commands!=last_command_count && touch_last_command==8'h80),
      .test_mode(test_mode),.next_event(musical_events[0]),.inc(enc_inc && (!mixer_active || mixer_item==15)),.dec(enc_dec && (!mixer_active || mixer_item==15)),.mode(instrument_mode));
    always @(posedge clk_50m)if(!rst_n)last_command_count<=0;else last_command_count<=touch_commands;
    expression_controls expression_ui(.clk(clk_50m),.rst_n(rst_n),
      .clear(trainer_exit || touch_commands!=last_command_count && touch_last_command==8'h80),
      .test_mode(test_mode),.events({musical_events[5:1],1'b0}),.config_bits(expression_bits));
    wire [155:0] pitch_audio_data;
    wire pitch_audio_valid;
    sample_mailbox #(.WIDTH(156)) pitch_mailbox(.src_clk(clk_50m),.src_rst_n(release_mailbox[1]),
        .src_valid(1'b1),.src_data(trainer_active  ?  {epiano_mode,expression_config,151'd0} : {epiano_mode,expression_config,mask32,test32,chord_mode,test_mode,test_mask,voice_modes}),.dst_clk(audio_clk),
        .dst_rst_n(audio_rst_n),.dst_valid(pitch_audio_valid),.dst_data(pitch_audio_data));
    reg [155:0] audio_config_full;
    wire [91:0] audio_config={audio_config_full[155:151],audio_config_full[86:0]};
    wire [1:0] pitch_audio=audio_config[1:0];
    always @(posedge audio_clk or negedge audio_rst_n)
        if(!audio_rst_n) audio_config_full<=0;
        else if(control_tick) audio_config_full<=pitch_audio_data;
    wire[56:0] map_audio_data;
    sample_mailbox #(.WIDTH(57)) map_crossing(.src_clk(clk_50m),.src_rst_n(release_mailbox[1]),.src_valid(1'b1),
      .src_data({map_enabled,keymap}),.dst_clk(audio_clk),.dst_rst_n(audio_rst_n),.dst_valid(),.dst_data(map_audio_data));
    reg[56:0] map_audio_config;
    always @(posedge audio_clk or negedge audio_rst_n)
      if(!audio_rst_n)map_audio_config<=0;
      else if(control_tick)map_audio_config<=map_audio_data;
    wire map_use=map_audio_config[56];
    wire[1:0] extra_audio_data;reg[1:0] extra_audio_config;
    sample_mailbox #(.WIDTH(2)) extra_crossing(.src_clk(clk_50m),.src_rst_n(release_mailbox[1]),.src_valid(1'b1),.src_data(mixer_extra),.dst_clk(audio_clk),.dst_rst_n(audio_rst_n),.dst_valid(),.dst_data(extra_audio_data));
    always @(posedge audio_clk or negedge audio_rst_n)if(!audio_rst_n)extra_audio_config<=0;else if(control_tick)extra_audio_config<=extra_audio_data;
    wire pluck_event,pluck_blocked,pluck_armed;wire[15:0] pluck_count;
    optical_pluck optical(.clk(clk_50m),.rst_n(rst_n),.enable(pluck_config[0] && !trainer_active && !test_mode),
      .blocked_high(pluck_config[1]),.raw(pluck_ir),.event_pulse(pluck_event),.blocked(pluck_blocked),.armed(pluck_armed),.count(pluck_count));
    reg pluck_toggle;
    always @(posedge clk_50m or negedge rst_n)if(!rst_n)pluck_toggle<=0;else if(pluck_event)pluck_toggle<=~pluck_toggle;
    wire[62:0] performance_data;reg[62:0] performance_config;
    sample_mailbox #(.WIDTH(63)) performance_cross(.src_clk(clk_50m),.src_rst_n(release_mailbox[1]),.src_valid(1'b1),
      .src_data({adsr_config,pluck_config[0] && !trainer_active && !test_mode,pluck_toggle}),
      .dst_clk(audio_clk),.dst_rst_n(audio_rst_n),.dst_valid(),.dst_data(performance_data));
    always @(posedge audio_clk or negedge audio_rst_n)if(!audio_rst_n)performance_config<=0;else if(control_tick)performance_config<=performance_data;
    wire[7:0] performed_valid;wire[63:0] performed_raw;
    pluck_pressure pluck_route(.clk(audio_clk),.rst_n(audio_rst_n),.control_ce(control_tick),.enable(performance_config[1]),
      .event_toggle(performance_config[0]),.input_valid(audio_valid),.input_raw(audio_raw),.output_valid(performed_valid),.output_raw(performed_raw));
    wire [127:0] audio_held128;
    wire [63:0] audio_held32=audio_held128[63:0];
    wire[1:0] pluck_result_audio,pluck_result_sys;
    pluck_note_observer pluck_observer(audio_clk,audio_rst_n,performance_config[1],
      performance_config[0],audio_held32[7:0],pluck_result_audio);
    sample_mailbox #(.WIDTH(2)) pluck_result_cross(audio_clk,audio_rst_n,1'b1,
      pluck_result_audio,clk_50m,release_mailbox[1],,pluck_result_sys);
    wire[23:0] pluck_display;
    pluck_status pluck_status_ui(clk_50m,rst_n,pluck_config[0],trainer_active || test_mode,
      pluck_blocked,pluck_armed,pluck_event,pluck_result_sys,pluck_display);
    wire monitor_valid;
    wire signed [15:0] monitor_pcm;


    sample_mailbox #(.WIDTH(16)) visual_crossing(.src_clk(audio_clk),.src_rst_n(audio_rst_n),
      .src_valid(monitor_valid),.src_data(monitor_pcm),.dst_clk(clk_50m),
      .dst_rst_n(release_mailbox[1]),.dst_valid(visual_valid),.dst_data(visual_pcm));
    wire[31:0] spectrum_frames,spectrum_missed;
    wire[15:0] health_underruns;
    sample_mailbox #(.WIDTH(16)) health_crossing(.src_clk(audio_clk),.src_rst_n(audio_rst_n),
      .src_valid(1'b1),.src_data(underruns),.dst_clk(clk_50m),.dst_rst_n(release_mailbox[1]),.dst_valid(),.dst_data(health_underruns));
    wire fft_valid,fft_done;wire[9:0] fft_bin;wire signed[23:0] fft_real,fft_imag;
    spectrum2048_bars #(.HOP(SPECTRUM_HOP),.WINDOW(SPECTRUM_WINDOW)) spectrum(.frame_count(spectrum_frames),.missed_windows(spectrum_missed),.raw_valid(fft_valid),.raw_done(fft_done),.raw_bin(fft_bin),.raw_real(fft_real),.raw_imag(fft_imag),.clk(clk_50m),.rst_n(rst_n),.sample_valid(visual_valid),.sample_pcm(visual_pcm),.bars(),.updated());
    reg[7:0] energy_pair[0:3];reg[7:0] energy_half[0:1];reg[7:0] game_energy;integer energy_i;
    always @(posedge clk_50m or negedge rst_n)
    if(!rst_n)begin game_energy<=0;energy_half[0]<=0;energy_half[1]<=0;for(energy_i=0;energy_i<4;energy_i=energy_i+1)energy_pair[energy_i]<=0;end
    else begin
      for(energy_i=0;energy_i<4;energy_i=energy_i+1)
        energy_pair[energy_i]<=strip_pressure[energy_i*16+:8]>strip_pressure[energy_i*16+8+:8] ? strip_pressure[energy_i*16+:8]:strip_pressure[energy_i*16+8+:8];
      energy_half[0]<=energy_pair[0]>energy_pair[1] ? energy_pair[0]:energy_pair[1];
      energy_half[1]<=energy_pair[2]>energy_pair[3] ? energy_pair[2]:energy_pair[3];
      game_energy<=energy_half[0]>energy_half[1] ? energy_half[0]:energy_half[1];
    end
    pcm_pressure_poly32 #(.RAM_ENV(1),.RAM_PHASE(1),.VOICES(128),.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1),.SEND_FX(1)) voice(.send_config(mixer_frame),.send_bypass(fx_bypass_frame),.master_volume(volume_frame),.adsr_config(performance_config[62:2]),.epiano_mode(audio_config[91]),.extra_fx(fx_bypass_frame ? 2'd0 : extra_audio_config),.map_enabled(map_use),.keymap(map_audio_config[55:0]),.control_tick(control_tick),.monitor_valid(monitor_valid),.monitor_pcm(monitor_pcm),.expression_config({audio_config[90] && !fx_bypass_frame,audio_config[89:87]}),.clk(audio_clk),.rst_n(audio_rst_n),
        .pressure_valid(DEMO  ?  8'hff : performed_valid),.pressure_raw(DEMO  ?  demo_raw : performed_raw),.held(held_audio),
        .chord_mode(audio_config[21]),.test32(audio_config[22]),.mask32(audio_config_full[150:23]),.held32(audio_held128),.voice_modes(audio_config[15:0]),.test_mode(audio_config[20]),.test_mask(audio_config[19:16]),.bclk(i2s_bclk),.lrclk(i2s_lrclk),.din(i2s_din),.xsmt(xsmt),.underruns(underruns));
    reg [7:0] held_meta,held_sync;
    always @(posedge clk_50m) begin if(!rst_n) begin held_meta<=0;held_sync<=0;end else begin held_meta<=held_audio;held_sync<=held_meta;end end
    // Both PCM5102 modules receive the same complete eight-voice mix.
    assign pcm2_bclk=i2s_bclk;
    assign pcm2_lrclk=i2s_lrclk;
    assign pcm2_din=i2s_din;
    assign pcm2_xsmt=xsmt;

    // LEDs stay in the 50 MHz ADC clock domain. Hold the most recent
    // successful samples; unseen or >10 ms old channels go dark independently.
    wire [63:0] strip_pressure;
    // Share the actual hysteretic audio gate with display and diagnostics.
    wire[7:0] physical_selected;
    genvar ps;generate for(ps=0;ps<8;ps=ps+1)begin:physical_keys
      assign physical_selected[ps]=seen[ps] && !stale[ps] && raw[ps*8+:8]>=20;
    end endgenerate
    assign pressure_held=pluck_config[0] && !test_mode && !trainer_active ? physical_selected:held_sync;
    genvar ledch;
    generate for(ledch=0;ledch<8;ledch=ledch+1) begin: led_freshness
        assign strip_pressure[ledch*8+:8]=(seen[ledch] && !stale[ledch] && pressure_held[ledch] && !test_mode)  ?  raw[ledch*8+:8] : 8'd0;

    end endgenerate
    assign status_led=~(|pressure_held);
    // Joint-test build: APDS owns the single physical strip output.
    // Existing ADC/audio/UART paths remain independent.
    wire gesture_ready,gesture_prox_valid;
    wire [7:0] gesture_prox;
    wire [31:0] gesture_errors,gesture_recoveries;
    apds9960_joint #(.CLK_HZ(50000000),.UART_BAUD(115200),.ENABLE_LOGGER(0),.ENABLE_STRIP(0)) u_gesture (
        .clk(clk_50m),.rst_n(rst_n),.scl(apds_scl),.sda(apds_sda),
        .dout(),.gesture_near(),.gesture_far(),.uart_tx(),
        .diagnostic_events(gesture_events),.diagnostic_ready(gesture_ready),
        .diagnostic_prox_valid(gesture_prox_valid),.diagnostic_prox(gesture_prox),
        .diagnostic_errors(gesture_errors),.diagnostic_recoveries(gesture_recoveries));


    ws2812_joint_driver #(.TRAINER(1),.GAME_FX(1)) joint_lights(.practice_mode(practice_mode),.led_event(led_event),.led_mask(led_mask),.guide_active(trainer_active),.guide_running(trainer_running),
      .guide_done(trainer_done),.guide_wait(trainer_wait),.guide_beat(trainer_beat),.guide_target(trainer_light_target),
      .guide_next(trainer_next),.guide_pressed(pressure_held),.guide_misses(trainer_misses),.guide_wrong(trainer_wrong),.clk(clk_50m),.rst_n(rst_n),.events(gesture_events),
      .prox(gesture_prox),.p1(strip_pressure[7:0]),.p2(strip_pressure[15:8]),
      .p3(strip_pressure[23:16]),.p4(strip_pressure[31:24]),.p5(strip_pressure[39:32]),
      .p6(strip_pressure[47:40]),.p7(strip_pressure[55:48]),.p8(strip_pressure[63:56]),.dout(dout));
    // OLED removed: release its former open-drain pins, with no bus polling.
    // Keep pin names/constraints stable so existing wiring is not repurposed.
    assign oled_scl=1'bz;
    assign oled_sda=1'bz;
    reg [20:0] count;
    reg [15:0] sequence_id;
    // Legacy OLED_TELEMETRY parameter selects UART cadence only; no OLED driver.
    // V3 160-byte packets fit comfortably in the 40 ms interval.
    wire tick=(count==(OLED_TELEMETRY  ?  21'd1999999 : 21'd999999));
    always @(posedge clk_50m) begin
        if(!rst_n) begin count<=0;sequence_id<=0;end
        else if(tick) begin count<=0;sequence_id<=sequence_id+1'b1;end
        else count<=count+1'b1;
    end
    // V3 diagnostics require the Joint07 monitor.
    // Audio underruns cross as a coherent mailbox snapshot, never a raw bus.
    joint07_uart #(.CLOCK_HZ(50000000),.BAUD(115200),.EXTENDED(1),.TOUCH_DIAG(1),.EXPANSION(1),.EXPRESSION(1),.TRAINER(1),.HEALTH(1)) logger(.audio_underruns(health_underruns),.spectrum_frames(spectrum_frames),.spectrum_missed(spectrum_missed),.trainer_flags(trainer_status[7:0]),
        .clk(clk_50m),.rst_n(rst_n),.trigger(tick),.time_us(time_us),.sequence_id(sequence_id),
        .pressed(pressure_held),.seen(seen),.stale(stale),
        .flags({4'b1000,overdue1,overdue0,1'b1,(|held_sync)}),
        .raw(raw),.sampled_at(stamps),.errors0(errors0),.errors1(errors1),
        .pitch_mode(trainer_active  ?  2'd0 : pitch_mode),.touch_keys(touch_keys),
        .events(gesture_events),.apds_ready(gesture_ready),.prox_valid(gesture_prox_valid),
        .prox(gesture_prox),.apds_errors(gesture_errors),.recoveries(gesture_recoveries),
        .voice_modes(trainer_active  ?  16'd0 : voice_modes),.selected(selected),.test_mode(test_mode),.test_mask(test_mask),.tx(debug_tx),
        .touch_scans(touch_scans),.touch_full(touch_full),.command_count(touch_commands),
        .last_command(touch_last_command),.touch_sdo(touch_sdo_level),.expression_config(expression_config),
        .chord_mode(trainer_active  ?  1'b0 : chord_mode),.test32(test32),.selected_test(selected_test[5:0]),.mask32(mask32[63:0]));
    assign hdmi_power=1'b1; // Console32001C HDMI termination enable, K14.
    wire pixel_clk,serial_clk,video_locked;
    video_pll u_video_pll(.clkin(clk_50m),.mdclk(clk_50m),.clkout0(serial_clk),.clkout1(pixel_clk),.lock(video_locked));
    reg[2:0] video_release=0;
    always @(posedge pixel_clk or negedge video_locked)
    if(!video_locked)video_release<=0;else video_release<={video_release[1:0],rst_n};
    // Reset is released while the OSER fast clock is physically stopped.
    // Eight pixel periods then provide >107ns settling before gate enable.
    wire serializer_rst_n,serializer_clk;
    video_serializer_start video_start(.pixel_clk(pixel_clk),.ready(video_release[2]),
      .serial_clk(serial_clk),.serializer_rst_n(serializer_rst_n),.gated_clk(serializer_clk));
    wire vhs,vvs,vde;wire[7:0] vr,vg,vb;
    video_dashboard #(.TEST128(1),.CUSTOM_CHART(0),.TIMED_CHART(1)) dashboard(.display_pluck(pluck_display),.display_mixer(mixer_display),.display_pitch({selected,trainer_active?16'd0:voice_modes,gesture_fx_bypass,manual_fx_bypass}),.display_pressure(strip_pressure),.display_adsr(adsr_config),.title_write(title_write),.title_address(title_address),.title_data(title_data),.title_valid(title_valid),.timed_enabled(timed_enabled),.timed_ready(preview_ready),.timed_masks(preview_masks),.timed_deltas(preview_deltas),.test_mask64(selected_test[6]?mask32[127:64]:mask32[63:0]),.test_selected(selected_test),.user_chart(user_chart),.chart_enabled(chart_enabled),.game_data(game_data),.pixel_clk(pixel_clk),.pixel_rst_n(video_release[2]),.sys_clk(clk_50m),.sys_rst_n(rst_n),
    .fft_valid(fft_valid),.fft_done(fft_done),.fft_bin(fft_bin),.fft_real(fft_real),.fft_imag(fft_imag),
    .audio_valid(visual_valid),.audio_pcm(visual_pcm),.pressed(pressure_held),.target(trainer_target),.hs(vhs),.vs(vvs),.de(vde),.red(vr),.green(vg),.blue(vb));
    DVI_TX_Top video_output(.I_rst_n(serializer_rst_n),.I_serial_clk(serializer_clk),.I_rgb_clk(pixel_clk),
    .I_rgb_vs(vvs),.I_rgb_hs(vhs),.I_rgb_de(vde),.I_rgb_r(vr),.I_rgb_g(vg),.I_rgb_b(vb),
    .O_tmds_clk_p(hdmi_clk_p),.O_tmds_clk_n(hdmi_clk_n),.O_tmds_data_p(hdmi_data_p),.O_tmds_data_n(hdmi_data_n));
endmodule



