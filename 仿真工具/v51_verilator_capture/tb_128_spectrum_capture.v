`timescale 1ns/1ps
module tb_128_spectrum_capture;
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
integer i,fd;
task capture;input integer n;begin
 for(i=0;i<n;i=i+1)begin waitframes(1);$fdisplay(fd,"%0d",$signed(pcm));end
end endtask
initial begin
 repeat(8)@(negedge clk);rst=1;
 waitframes(256);
 fd=$fopen("checks/spectrum128_all.txt","w");capture(4096);$fclose(fd);
 $display("PROGRESS 4096 actual RTL samples captured, all128 gates active");$fflush();
 mask=~((128'd1<<0)|(128'd1<<63)|(128'd1<<64)|(128'd1<<127));
 // Fixed diagnostic envelope releases before collecting the second FFT window.
 waitframes(512);
 fd=$fopen("checks/spectrum128_muted_1_64_65_128.txt","w");capture(4096);$fclose(fd);
 if(gates!==mask)$fatal(1,"independent gate mismatch");
 $display("PASS RTL audio capture: 4096 all-on samples plus4096 samples after four independent mutes; no underrun, unknown PCM or I2S stale frame; latency=%0d/%0d",lat_min,lat_max);$finish;
end
initial begin #500000000;$fatal(1,"timeout");end
endmodule
