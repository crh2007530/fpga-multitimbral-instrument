`timescale 1ns/1ps
module tb_audio_endurance;
reg clk=0;always #20.325 clk=~clk;
reg rst=0,testmode=1,chord=0,piano=0,bypass=0;reg[3:0]expr=0;
reg[127:0]mask=~128'd0;reg[63:0]raw=0;reg[7:0]pv=255;
reg[15:0]modes=0;reg[4:0]gain=16;reg[1:0]extras=3;reg mapped=0;reg[55:0]notes={7'd72,7'd71,7'd69,7'd67,7'd65,7'd64,7'd62,7'd60};
reg[60:0]adsr=0;reg[32:0]fx=33'h104108110;
wire cv,mv,bc,lr,di,xs;wire signed[15:0]pcm;wire[7:0]held;wire[127:0]gates;wire[15:0]und;
pcm_pressure_poly32 #(.RAM_ENV(1),.RAM_PHASE(1),.VOICES(128),.WARMUP_FRAMES(8),.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1),.SEND_FX(1)) dut(
 .clk(clk),.rst_n(rst),.pressure_valid(pv),.pressure_raw(raw),.voice_modes(modes),.chord_mode(chord),.test_mode(testmode),.test32(1'b1),.expression_config(expr),.test_mask(4'hf),.mask32(mask),
 .control_tick(cv),.monitor_valid(mv),.monitor_pcm(pcm),.held(held),.held32(gates),.bclk(bc),.lrclk(lr),.din(di),.xsmt(xs),.underruns(und),.map_enabled(mapped),.keymap(notes),.extra_fx(extras),.epiano_mode(piano),.adsr_config(adsr),.master_volume(gain),.send_config(fx),.send_bypass(bypass));
integer cycle=0,request=-1,published=0,last_req=-1,last_pub=-1,lat_min=999,lat_max=0,frames=0;
reg signed[15:0]expected_frame;reg pending=0;
always @(posedge clk)if(rst)begin
cycle=cycle+1;
if(dut.sample_ce)begin
 if(last_req>=0 && cycle-last_req!=512)$fatal(1,"sample rate changed");
 last_req=cycle;request=cycle;published=0;
end
if(mv)begin
 if(request<0 || cycle-request>=192 || published)$fatal(1,"late/duplicate sample");
 if(^pcm===1'bx)$fatal(1,"unknown PCM");
 if(cycle-request<lat_min)lat_min=cycle-request;
 if(cycle-request>lat_max)lat_max=cycle-request;
 if(last_pub>=0 && cycle-last_pub!=512)$fatal(1,"publication jitter");
 last_pub=cycle;published=1;expected_frame=pcm;pending=1;
end
if(dut.tx.divider==7 && dut.tx.bit_index==63 && request>=0)begin
 if(!pending)$fatal(1,"frame had no fresh PCM");
 #1;if(dut.tx.frame_sample!==expected_frame)$fatal(1,"I2S latched wrong generation");pending=0;frames=frames+1;
end
if(und!=0 || dut.batch_overrun || dut.ram_phase_fault || dut.ram_envelope_fault)$fatal(1,"audio scheduler overrun");
end
task waitframes;input integer n;integer j;begin for(j=0;j<n;j=j+1)begin @(negedge clk);while(!mv)@(negedge clk);end end endtask
integer f,k;reg[31:0]rng=32'hcafe9876;
initial begin
 $timeformat(-9,0,"",0);
 repeat(8)@(negedge clk);rst=1;
 for(f=0;f<600000;f=f+1)begin
  waitframes(1);
  if(f==256 || f==299999)if(gates!==~128'd0)$fatal(1,"long held voice lost");
  if(f>=300000 && f%1024==0)begin
   k=(f-300000)/1024;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   testmode=k%7==0;chord=k%5!=0;piano=k%3==2;expr=k%3==1?4'b1111:4'b1110;
   raw={rng,rng^32'h55aa1234};pv=k%11==0?0:255;
   mask=~(128'd1<<(k%128));bypass=k%5==0;extras=k%4;fx[13:10]=k%16;
   modes={8{(k%3==0?2'd0:k%3==1?2'd1:2'd2)}};gain=k%17;mapped=k%2;
   adsr=k%4==0?{1'b1,15'd64,15'd12000,15'd32,15'd128}:61'd0;
  end
  if(f%48047==0)begin $display("PROGRESS frames=%0d time_ns=%0t",f,$time);$fflush();end
 end
 raw=0;testmode=0;pv=255;waitframes(16);
 if(gates!=0)$fatal(1,"final release gates stuck");
 $display("PASS continuous audio engine: %0d I2S frames, no reset, 128 held voices through age saturation, randomized instruments/FX/custom ADSR/pitch/map/gain/ADC-valid changes; fixed publication latency %0d/%0d; no underrun, duplicate or stale I2S frame; simulated_ns=%0t",frames,lat_min,lat_max,$time);$finish;
end
initial begin #20000000000;$fatal(1,"endurance timeout");end
endmodule
