`timescale 1ns/1ps
module tb_phase_audio_equivalence;
reg clk=0;always #20.325 clk=~clk;
reg rst=0,testmode=1,chord=0,piano=0,bypass=0;reg[3:0]expr=0;
reg[127:0]mask=~128'd0;reg[63:0]raw=0;reg[7:0]pv=255;
reg[60:0]adsr=0;reg[32:0]fx=33'h104108110;
wire cv,mv,bc,lr,di,xs;wire signed[15:0]pcm;wire[7:0]held;wire[127:0]gates;wire[15:0]und;
pcm_pressure_poly32 #(.RAM_ENV(1),.RAM_PHASE(1),.VOICES(128),.WARMUP_FRAMES(8),.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1),.SEND_FX(1)) dut(
 .clk(clk),.rst_n(rst),.pressure_valid(pv),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(chord),.test_mode(testmode),.test32(1'b1),.expression_config(expr),.test_mask(4'hf),.mask32(mask),
 .control_tick(cv),.monitor_valid(mv),.monitor_pcm(pcm),.held(held),.held32(gates),.bclk(bc),.lrclk(lr),.din(di),.xsmt(xs),.underruns(und),.map_enabled(1'b0),.keymap(56'd0),.extra_fx(2'b11),.epiano_mode(piano),.adsr_config(adsr),.master_volume(5'd16),.send_config(fx),.send_bypass(bypass));
wire rcv,rmv,rbc,rlr,rdi,rxs; wire signed[15:0]rpcm; wire[7:0]rheld;wire[127:0]rgates;wire[15:0]rund;
pcm_pressure_poly32 #(.RAM_PHASE(0),.VOICES(128),.WARMUP_FRAMES(8),.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1),.SEND_FX(1)) reference(
 .clk(clk),.rst_n(rst),.pressure_valid(pv),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(chord),.test_mode(testmode),.test32(1'b1),.expression_config(expr),.test_mask(4'hf),.mask32(mask),
 .control_tick(rcv),.monitor_valid(rmv),.monitor_pcm(rpcm),.held(rheld),.held32(rgates),.bclk(rbc),.lrclk(rlr),.din(rdi),.xsmt(rxs),.underruns(rund),.map_enabled(1'b0),.keymap(56'd0),.extra_fx(2'b11),.epiano_mode(piano),.adsr_config(adsr),.master_volume(5'd16),.send_config(fx),.send_bypass(bypass));

integer checked=0,refs=0; reg signed[15:0] expected;
always @(posedge clk) if(rst) begin
 if(rmv)begin expected=rpcm;refs=refs+1;end
 if(mv)begin
  if(refs!=checked+1)$fatal(1,"generation mismatch");
  if(pcm!==expected)$fatal(1,"PCM differs frame=%0d ram=%0d reference=%0d",checked,pcm,expected);
  checked=checked+1;
 end
 if(und || rund || dut.ram_phase_fault || dut.ram_envelope_fault)$fatal(1,"schedule error");
end
task frames;input integer n;integer j;begin
 for(j=0;j<n;j=j+1)begin @(negedge clk);while(!mv)@(negedge clk);end
end endtask
integer k;
initial begin
 repeat(8)@(negedge clk);rst=1;
 frames(32);
 testmode=0;chord=1;raw={8{8'd96}};
 for(k=0;k<3;k=k+1)begin
  piano=k==2;expr=k==1?4'b1111:4'b1110;
  frames(24);raw=0;frames(4);raw={8{8'd120}};
 end
 frames(8);
 $display("PASS %0d output samples bit-exact against original register-phase engine; diagnostic,3 timbres,note release/retrigger,FX",checked);$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
