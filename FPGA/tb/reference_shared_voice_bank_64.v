`timescale 1ns/1ps
// Two parallel DSP/single-port-ROM lanes, 32 independent voices per lane.
// Musical waves are real-time oscillators, not recorded PCM phrases.
module reference_shared_voice_bank_64 #(parameter integer VOICES=32,GROUP=4,THIRD_TIMBRE=0,SUM_ONLY=0)(
 input wire clk,rst_n,sample_ce,sine_mode,
 input wire[VOICES*10-1:0] addresses,input wire[VOICES*16-1:0] forces,envelopes,
 output wire[VOICES*16-1:0] samples,output wire valid,
 input wire epiano_mode,diagnostic_mode,
 input wire[VOICES*16-1:0] increments,input wire[VOICES-1:0] gates);
 generate if(!THIRD_TIMBRE)begin:legacy
 shared_voice_bank_legacy #(.VOICES(VOICES),.GROUP(GROUP),.THIRD_TIMBRE(0)) original(
 .clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),.sine_mode(sine_mode),.addresses(addresses),
 .forces(forces),.envelopes(envelopes),.samples(samples),.valid(valid),.epiano_mode(epiano_mode),.diagnostic_mode(diagnostic_mode));
 end else begin:instruments
 localparam SW=$clog2(GROUP);
 reg[2*GROUP+10:0] stages;reg piano,guitar,diagnostic;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin stages<=0;piano<=0;guitar<=0;diagnostic<=0;end
 else begin stages<={stages[2*GROUP+9:0],sample_ce};if(sample_ce)begin
 piano<=epiano_mode;guitar<=sine_mode;diagnostic<=diagnostic_mode;end end
 reg launch;reg[SW-1:0]slot;integer k;
 always @*begin slot=0;launch=0;for(k=0;k<GROUP;k=k+1)if(stages[2*k+2])begin slot=k;launch=1;end end
 assign valid=stages[2*GROUP+10];
 reg prefetch;reg[SW-1:0] pre_slot;integer pk;
 always @*begin prefetch=0;pre_slot=0;for(pk=0;pk<GROUP;pk=pk+1)if(stages[2*pk+1])begin prefetch=1;pre_slot=pk;end end
 localparam LANES=VOICES/GROUP;
 // SUM_ONLY packs the exact signed 22-bit sum into samples[21:0].
 // Accumulate the already-computed voice samples without a 64-input adder tree.
 wire signed[21:0] lane_sums[0:LANES-1];reg signed[21:0] total_sum;integer sum_lane;
 always @*begin total_sum=0;for(sum_lane=0;sum_lane<LANES;sum_lane=sum_lane+1)total_sum=total_sum+lane_sums[sum_lane];end
 if(SUM_ONLY)begin:packed_mix assign samples={{(VOICES*16-22){1'b0}},total_sum};end
 wire[12:0] rom_addr[0:LANES];wire[15:0] rom_q[0:LANES];wire[LANES:0] rom_en;
 assign rom_addr[LANES]=0;assign rom_en[LANES]=0;
 wire[9:0] curve_addr[0:LANES],pitch_addr[0:LANES];wire[31:0] curve_data[0:LANES];wire[15:0] pitch_data[0:LANES];
 assign curve_addr[LANES]=0;assign pitch_addr[LANES]=0;
 genvar pair;
 for(pair=0;pair<LANES;pair=pair+2)begin:tables
 approved_wave_rom table_rom(.clk(clk),.ena(rom_en[pair]),.enb(rom_en[pair+1]),.addra(rom_addr[pair]),.addrb(rom_addr[pair+1]),.qa(rom_q[pair]),.qb(rom_q[pair+1]));
 approved_control_rom control_rom(.clk(clk),.ena(launch),.enb(launch && pair+1<LANES),.ca(curve_addr[pair]),.cb(curve_addr[pair+1]),.pa(pitch_addr[pair]),.pb(pitch_addr[pair+1]),.qa(curve_data[pair]),.qb(curve_data[pair+1]),.pqa(pitch_data[pair]),.pqb(pitch_data[pair+1]));
 end
 genvar g,s;
 for(g=0;g<VOICES/GROUP;g=g+1)begin:lanes
 wire[GROUP*10-1:0] lane_addresses=addresses[g*GROUP*10+:GROUP*10];
 wire[GROUP*16-1:0] lane_envelopes=envelopes[g*GROUP*16+:GROUP*16];
 wire[GROUP*16-1:0] lane_forces=forces[g*GROUP*16+:GROUP*16];
 wire[GROUP*16-1:0] lane_steps=increments[g*GROUP*16+:GROUP*16];
 wire[GROUP-1:0] lane_gates=gates[g*GROUP+:GROUP];
 wire[9:0] address=lane_addresses[slot*10+:10];
 wire[15:0] env_in=lane_envelopes[slot*16+:16],force_in=lane_forces[slot*16+:16],step_in=lane_steps[slot*16+:16];
 wire gate=lane_gates[slot];
 reg[GROUP-1:0] state_valid;
 wire[35:0] state_read;
 wire[35:0] current_state=state_valid[slot]?state_read:36'd0;
 wire start=gate && !current_state[16];wire[17:0] current_age=start?18'd0:current_state[34:17];
 reg[17:0] age_next_pipe[0:3];reg[15:0] carrier_pipe[0:3];reg[3:0] gate_pipe;
 wire[17:0] late_age=current_age-18'd4096;
 wire[10:0] late_index=11'd256+{1'b0,late_age[17:8]};
 wire[9:0] curve_index=current_age<4096?{2'b0,current_age[11:4]}:
                          late_index>1023?10'd1023:late_index[9:0];
 wire[31:0] curve_q=curve_data[g];wire[15:0] pitch_q=pitch_data[g];
 assign curve_addr[g]=curve_index;assign pitch_addr[g]=step_in[14:5];
 reg[3:0] frame;reg[17:0] frame_start;reg[15:0] reciprocal;
 // 13 analysis-envelope knots; interpolate periodic waves between adjacent
 // knots. All voices advance their own phase and age independently.
 always @*begin
 frame=12;frame_start=153750;reciprocal=0;
 if(current_age<384)begin frame=0;frame_start=0;reciprocal=43691;end
 else if(current_age<961)begin frame=1;frame_start=384;reciprocal=29077;end
 else if(current_age<1922)begin frame=2;frame_start=961;reciprocal=17458;end
 else if(current_age<3363)begin frame=3;frame_start=1922;reciprocal=11643;end
 else if(current_age<5766)begin frame=4;frame_start=3363;reciprocal=6982;end
 else if(current_age<9609)begin frame=5;frame_start=5766;reciprocal=4366;end
 else if(current_age<16816)begin frame=6;frame_start=9609;reciprocal=2328;end
 else if(current_age<28828)begin frame=7;frame_start=16816;reciprocal=1397;end
 else if(current_age<48047)begin frame=8;frame_start=28828;reciprocal=873;end
 else if(current_age<76875)begin frame=9;frame_start=48047;reciprocal=582;end
 else if(current_age<115313)begin frame=10;frame_start=76875;reciprocal=436;end
 else if(current_age<153750)begin frame=11;frame_start=115313;reciprocal=436;end
 end
 wire[17:0] frame_distance=current_age-frame_start;
 reg[33:0] alpha_product;reg[7:0] alpha_pipe[0:4];
 reg[8:0] v;reg[SW-1:0] tag[0:8];
 reg[9:0] address_pipe[0:3];reg[15:0] step_pipe[0:3];reg[3:0] frame_pipe[0:3];
 reg[31:0] gain_pipe[0:5];reg[3:0] start_pipe;
 reg[8:0] amp_pipe[0:4];reg expired;
 reg signed[8:0] triangle,mod0,mod1;
 always @*case(address[9:8])
 0:triangle=$signed({2'b0,address[7:1]});
 1:triangle=9'sd128-$signed({2'b0,address[7:1]});
 2:triangle=-$signed({2'b0,address[7:1]});
 3:triangle=$signed({2'b0,address[7:1]})-9'sd128;
 endcase
 reg[23:0] depth_product;reg[8:0] reed_depth;
 wire[16:0] depth=piano?{1'b0,depth_product[23:8]}:{8'd0,reed_depth};
 reg signed[26:0] modulation_product;reg signed[43:0] frequency_product;
 wire signed[43:0] shifted_frequency=(frequency_product+44'sd16384)>>>15;
 wire[15:0] fm_delta=step_pipe[3]+shifted_frequency[15:0];
 wire[9:0] carrier_address=start_pipe[3]?10'd0:carrier_pipe[3][15:6];
 wire[3:0] next_frame=frame_pipe[3]==12?4'd12:frame_pipe[3]+1'b1;
 wire[12:0] read_a=diagnostic?(13'd6656+{3'd0,address_pipe[3]}):
 guitar && !piano?{frame_pipe[3],address_pipe[3][9:1]}:
 piano?(13'd6656+{3'd0,carrier_address}):(13'd7680+{4'd0,carrier_address[9:1]});
 wire[12:0] read_b=(!diagnostic && guitar && !piano)?{next_frame,address_pipe[3][9:1]}:read_a;
 reg signed[15:0] wave_a;wire signed[15:0] read_q=rom_q[g];reg[12:0] read_b_hold;
 wire[12:0] selected_read_address=v[3]?read_a:read_b_hold;
 assign rom_addr[g]=selected_read_address;assign rom_en[g]=v[3] || v[4];
 always @(posedge clk)begin
 if(v[3])read_b_hold<=read_b;
 if(v[4])wave_a<=read_q;
 end
 wire signed[16:0] wave_difference=$signed({read_q[15],read_q})-$signed({wave_a[15],wave_a});
 reg signed[25:0] interpolation;reg signed[15:0] wave_first,wave_final;
 wire state_write=rst_n && v[3];wire[SW-1:0] state_write_slot=tag[3];
 wire[15:0] carrier_next=start_pipe[3]?fm_delta:carrier_pipe[3]+fm_delta;
 wire[35:0] state_write_data={1'b0,age_next_pipe[3],gate_pipe[3],carrier_next};
 voice_state_ram #(.AW(SW)) state_ram(clk,prefetch,state_write,pre_slot,state_write_slot,state_write_data,state_read);
 always @(posedge clk or negedge rst_n)if(!rst_n)state_valid<=0;else if(state_write)state_valid[state_write_slot]<=1;
 reg[24:0] amplitude_product;reg[16:0] final_gain;reg signed[32:0] audio_product;
 wire signed[25:0] interpolated_wave=$signed({{10{wave_first[15]}},wave_first})+(interpolation>>>8);
 reg signed[15:0] output_samples[0:GROUP-1];integer i;
 wire signed[15:0] current_sample=audio_product>>>17;
 reg signed[20:0] lane_sum;
 assign lane_sums[g]=$signed({lane_sum[20],lane_sum});
 always @(posedge clk or negedge rst_n)if(!rst_n)lane_sum<=0;
 else if(v[8])lane_sum<=tag[8]==0 ? $signed({{5{current_sample[15]}},current_sample}) : lane_sum+$signed({{5{current_sample[15]}},current_sample});
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
 gate_pipe<=0;v<=0;start_pipe<=0;alpha_product<=0;expired<=0;mod0<=0;mod1<=0;
 depth_product<=0;reed_depth<=0;modulation_product<=0;frequency_product<=0;
 interpolation<=0;wave_first<=0;wave_final<=0;amplitude_product<=0;final_gain<=0;audio_product<=0;
 for(i=0;i<GROUP;i=i+1)begin output_samples[i]<=0;end
 for(i=0;i<9;i=i+1)tag[i]<=0;
 for(i=0;i<4;i=i+1)begin address_pipe[i]<=0;step_pipe[i]<=0;frame_pipe[i]<=0;age_next_pipe[i]<=0;carrier_pipe[i]<=0;end
 for(i=0;i<5;i=i+1)begin amp_pipe[i]<=0;alpha_pipe[i]<=0;end
 for(i=0;i<6;i=i+1)gain_pipe[i]<=0;
 end else begin
 v<={v[7:0],launch};start_pipe<={start_pipe[2:0],start};gate_pipe<={gate_pipe[2:0],gate};
 for(i=1;i<9;i=i+1)tag[i]<=tag[i-1];
 for(i=1;i<4;i=i+1)begin address_pipe[i]<=address_pipe[i-1];step_pipe[i]<=step_pipe[i-1];frame_pipe[i]<=frame_pipe[i-1];age_next_pipe[i]<=age_next_pipe[i-1];carrier_pipe[i]<=carrier_pipe[i-1];end
 for(i=1;i<5;i=i+1)begin amp_pipe[i]<=amp_pipe[i-1];alpha_pipe[i]<=alpha_pipe[i-1];end
 for(i=1;i<6;i=i+1)gain_pipe[i]<=gain_pipe[i-1];
 if(launch)begin
 tag[0]<=slot;address_pipe[0]<=address;step_pipe[0]<=step_in;frame_pipe[0]<=frame;
 gain_pipe[0]<=force_in*env_in;alpha_product<=frame_distance*reciprocal;
 age_next_pipe[0]<=current_age==262143?current_age:current_age+1'b1;carrier_pipe[0]<=current_state[15:0];
 mod0<=piano?triangle:(address[9]?-9'sd128:9'sd128);expired<=current_age>=200704;
 end
 if(v[0])begin
 depth_product<=curve_q[23:16]*pitch_q;reed_depth<=9'd256+{1'b0,curve_q[7:0]};mod1<=mod0;
 amp_pipe[0]<=diagnostic?9'd256:guitar && !piano?9'd256:piano?(expired?9'd0:{1'b0,curve_q[31:24]}):{1'b0,curve_q[15:8]};
 alpha_pipe[0]<=|alpha_product[33:24]?8'd255:alpha_product[23:16];
 end
 if(v[1])modulation_product<=mod1*$signed({1'b0,depth});
 if(v[2])frequency_product<=modulation_product*$signed({1'b0,step_pipe[2]});
 if(v[5])begin
 interpolation<=wave_difference*$signed({1'b0,alpha_pipe[4]});wave_first<=wave_a;
 amplitude_product<=gain_pipe[5][30:15]*amp_pipe[4];
 end
 if(v[6])begin wave_final<=interpolated_wave[15:0];final_gain<=amplitude_product[24:8];end
 if(v[7])audio_product<=wave_final*$signed(final_gain);
 if(v[8])output_samples[tag[8]]<=audio_product>>>17;
 end
 for(s=0;s<GROUP;s=s+1)begin:outputs
 if(!SUM_ONLY)assign samples[(g*GROUP+s)*16+:16]=output_samples[s];end
 end
 end endgenerate
endmodule
