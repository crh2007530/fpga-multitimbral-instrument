`timescale 1ns/1ps
module tb_128_engine;
reg clk=0;always #20.325 clk=~clk;
reg rst=0,testmode=1,chord=0,piano=0,bypass=0;reg[3:0]expr=0;
reg[127:0]mask=~128'd0;reg[63:0]raw=0;reg[7:0]pv=255;
reg[60:0]adsr=0;reg[32:0]fx=33'h104108110;
wire cv,mv,bc,lr,di,xs;wire signed[15:0]pcm;wire[7:0]held;wire[127:0]gates;wire[15:0]und;
pcm_pressure_poly32 #(.VOICES(128),.WARMUP_FRAMES(8),.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1),.SEND_FX(1)) dut(
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
if(und!=0 || dut.batch_overrun)$fatal(1,"audio scheduler overrun");
end
task waitframes;input integer n;integer j;begin for(j=0;j<n;j=j+1)begin @(negedge clk);while(!mv)@(negedge clk);end end endtask
integer i,f,j;reg[31:0]rng=32'hcafe1234;
initial begin
repeat(8)@(negedge clk);rst=1;
waitframes(2200);if(gates!==~128'd0)$fatal(1,"not all128 gates active");
f=$fopen("checks/128_all_pcm.txt","w");
for(j=0;j<4096;j=j+1)begin waitframes(1);$fdisplay(f,"%d",pcm);end
$fclose(f);
// Every independent mask bit, including the 64/127 boundaries.
for(i=0;i<128;i=i+1)begin
mask=~(128'd1<<i);waitframes(2);
if(gates!==mask)$fatal(1,"independent off failed voice=%d",i);
mask=~128'd0;waitframes(2);if(gates!==mask)$fatal(1,"independent on failed");
end
// Long enough for released diagnostic envelope to reach zero.
mask[100]=0;waitframes(2400);
f=$fopen("checks/128_off100_pcm.txt","w");
for(j=0;j<4096;j=j+1)begin waitframes(1);$fdisplay(f,"%d",pcm);end
$fclose(f);
testmode=0;chord=1;raw={8{8'd96}};waitframes(8);
for(i=0;i<3;i=i+1)begin
piano=i==2;expr=i==1?4'b1111:4'b1110;
for(j=0;j<128;j=j+1)begin
rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};raw={rng,rng^32'h55aa1234};bypass=j%7==0;fx[13:10]=j%16;
waitframes(2);
end
end
adsr={1'b1,15'd64,15'd12000,15'd32,15'd128};waitframes(32);
raw=0;waitframes(8);if(gates!=0)$fatal(1,"release gates stuck");
$display("PASS 128 engine: all voices,128 independent off/on masks,3 timbres,FX presets/bypass,custom ADSR,release; %0d I2S frames; publication latency min/max %0d/%0d cycles; no underruns, jitter, X, or stale I2S frame",frames,lat_min,lat_max);$finish;
end
initial begin #500000000;$fatal(1,"timeout");end
endmodule
