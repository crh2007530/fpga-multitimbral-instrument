`timescale 1ns/1ps
module tb_guitar_strum_engine;
reg clk=0;always #20.325 clk=~clk;
reg rst=0,testmode=1,chord=0,piano=0,bypass=0;reg[3:0]expr=0;
reg[127:0]mask=~128'd0;reg[63:0]raw=0;reg[7:0]pv=255;
reg[60:0]adsr=0;reg[32:0]fx=33'h104108110;
wire cv,mv,bc,lr,di,xs;wire signed[15:0]pcm;wire[7:0]held;wire[127:0]gates;wire[15:0]und;
pcm_pressure_poly32 #(.RAM_ENV(1),.RAM_PHASE(1),.VOICES(128),.WARMUP_FRAMES(8),.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1),.SEND_FX(1)) dut(
 .clk(clk),.rst_n(rst),.pressure_valid(pv),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(chord),.test_mode(testmode),.test32(1'b1),.expression_config(expr),.test_mask(4'hf),.mask32(mask),
 .control_tick(cv),.monitor_valid(mv),.monitor_pcm(pcm),.held(held),.held32(gates),.bclk(bc),.lrclk(lr),.din(di),.xsmt(xs),.underruns(und),.map_enabled(1'b0),.keymap(56'd0),.extra_fx(2'b11),.epiano_mode(piano),.adsr_config(adsr),.master_volume(5'd16),.send_config(fx),.send_bypass(bypass));
integer cycle=0,request=-1,published=0,last_req=-1,last_pub=-1,lat_min=999,lat_max=0,frames=0;
reg signed[15:0]expected_frame;reg pending=0;
always @(posedge clk)if(!rst)begin request=-1;last_req=-1;last_pub=-1;pending=0;published=0;end else begin
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
wire ref_mv;wire signed[15:0]ref_pcm;
pcm_pressure_poly32 #(.AUTO_STRUM(0),.RAM_ENV(1),.RAM_PHASE(1),.VOICES(128),.WARMUP_FRAMES(8),.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1),.SEND_FX(1)) reference(
 .clk(clk),.rst_n(rst),.pressure_valid(pv),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(chord),.test_mode(testmode),.test32(1'b1),.expression_config(expr),.test_mask(4'hf),.mask32(mask),
 .control_tick(),.monitor_valid(ref_mv),.monitor_pcm(ref_pcm),.held(),.held32(),.bclk(),.lrclk(),.din(),.xsmt(),.underruns(),.map_enabled(1'b0),.keymap(56'd0),.extra_fx(2'b11),.epiano_mode(piano),.adsr_config(adsr),.master_volume(5'd16),.send_config(fx),.send_bypass(bypass));

reg compare=1;integer compared=0;integer fd,fr,f,j;
always @(negedge clk)if(rst && compare && mv)begin
 if(!ref_mv || pcm!==ref_pcm)$fatal(1,"unaffected mode differs from baseline");compared=compared+1;
end
function[127:0] expected_gates;input integer stage;integer n;begin
expected_gates=0;for(n=0;n<128;n=n+1)if(n%8==0 && (n/8)%4<=stage)expected_gates[n]=1;
end endfunction

initial begin
 $timeformat(-9,0,"",0);
 repeat(8)@(negedge clk);rst=1;
 waitframes(64);if(gates!==~128'd0)$fatal(1,"diagnostic128 altered");
 for(j=0;j<128;j=j+1)begin mask=~(128'd1<<j);waitframes(2);if(gates!==mask)$fatal(1,"mask altered");end
 mask=~128'd0;waitframes(8);testmode=0;chord=1;raw={8{8'd96}};expr=0;waitframes(128);
 piano=1;waitframes(128);compare=0;
 // Restart both models identically for a genuine dry PCM before/after comparison.
 rst=0;raw=0;piano=0;expr=1;bypass=1;adsr=0;
 repeat(8)@(negedge clk);rst=1;waitframes(32);
 raw=96;
 fd=$fopen("checks/strum_pcm.txt","w");fr=$fopen("checks/simultaneous_pcm.txt","w");
 for(f=0;f<2304;f=f+1)begin
  waitframes(1);$fdisplay(fd,"%0d",pcm);$fdisplay(fr,"%0d",ref_pcm);
  if(f==100 && gates!==expected_gates(0))$fatal(1,"root stage mismatch");
  if(f==700 && gates!==expected_gates(1))$fatal(1,"third stage mismatch");
  if(f==1300 && gates!==expected_gates(2))$fatal(1,"fifth stage mismatch");
  if(f==1900 && gates!==expected_gates(3))$fatal(1,"octave stage mismatch");
 end
 // Four short played chords with identical pressure and fixed master gain.
 for(f=2304;f<96094;f=f+1)begin
  if(f%24000==15000)raw=0;
  if(f%24000==0)raw=96;
  waitframes(1);$fdisplay(fd,"%0d",pcm);$fdisplay(fr,"%0d",ref_pcm);
 end
 $fclose(fd);$fclose(fr);
 raw=0;waitframes(8);if(gates!=0)$fatal(1,"release stuck");
 raw=96;waitframes(100);raw=0;waitframes(2000);if(gates!=0)$fatal(1,"ghost delayed note");
 raw=96;waitframes(100);pv=0;waitframes(600);if(gates!=0)$fatal(1,"ADC disconnect failed to release");
 raw=0;pv=255;waitframes(8);
 adsr={1'b1,15'd64,15'd12000,15'd32,15'd128};raw=96;waitframes(1900);
 if(gates!==expected_gates(3))$fatal(1,"custom ADSR chord scheduling");
 raw=0;waitframes(32);if(gates!=0)$fatal(1,"custom ADSR release gates");
 raw=96;waitframes(100);rst=0;raw=0;repeat(8)@(negedge clk);rst=1;waitframes(32);
 if(gates!=0)$fatal(1,"reset stuck");
 $display("PASS guitar strum engine: 128 diagnostic masks and %0d unaffected PCM samples equal baseline; production576-frame stages; pressure retrigger, early release,ADC loss,custom ADSR,mid-sweep reset; fixed latency %0d/%0d; no underruns/duplicates/stale I2S",compared,lat_min,lat_max);$finish;
end
initial begin #5000000000;$fatal(1,"timeout");end
endmodule
