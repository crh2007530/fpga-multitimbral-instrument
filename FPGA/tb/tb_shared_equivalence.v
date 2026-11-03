`timescale 1ns/1ps
module tb_shared_equivalence;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg[7:0] pv=0;reg[63:0] raw=0;
 reg[15:0] modes=0;reg chord=0,testmode=0,t32=0;
 reg[3:0] cfg=0,mask4=15;reg[31:0] mask=32'hffffffff,rng=32'h3928ca11;
 wire[15:0] ur,un;wire vr,vn;wire signed[15:0] pr,pn;
 wire br,lr,dr,bn,ln,dn;wire[31:0] hr,hn;
 pcm_pressure_poly32_reference #(.EXPRESSION(1),.FRAME_CONTROL(1),.WARMUP_FRAMES(1)) refcore(
 .clk(clk),.rst_n(rst),.pressure_valid(pv),.pressure_raw(raw),.voice_modes(modes),
 .chord_mode(chord),.test_mode(testmode),.test32(t32),.expression_config(cfg),.test_mask(mask4),.mask32(mask),
 .monitor_valid(vr),.monitor_pcm(pr),.held32(hr),.underruns(ur),.bclk(br),.lrclk(lr),.din(dr));
 pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.WARMUP_FRAMES(1)) dut(
 .clk(clk),.rst_n(rst),.pressure_valid(pv),.pressure_raw(raw),.voice_modes(modes),
 .chord_mode(chord),.test_mode(testmode),.test32(t32),.expression_config(cfg),.test_mask(mask4),.mask32(mask),
 .monitor_valid(vn),.monitor_pcm(pn),.held32(hn),.underruns(un),.bclk(bn),.lrclk(ln),.din(dn));
 integer cycles=0,frames=0,compared=0,j;reg signed[15:0] expected;reg pending=0;
 always @(posedge clk)begin
  #1;
  if(rst)begin
   if({br,lr,dr,hr} !== {bn,ln,dn,hn})$fatal(1,"I2S or held differs frame=%0d cycle=%0d",frames,cycles);
   if(vr)begin
    if(pending)$fatal(1,"reference queue overwrite");
    expected=pr;pending=1;
   end
   if(vn)begin
    if(!pending || pn !== expected)$fatal(1,"PCM differs frame=%0d got=%d expected=%d",frames,pn,expected);
    pending=0;compared=compared+1;
   end
   if(ur || un)$fatal(1,"underrun");
  end else pending=0;
 end
 always @(negedge clk)if(rst)begin
  cycles=cycles+1;
  rng=(rng<<1)^ (rng[31]?32'h04c11db7:0);
  pv=(cycles%83==0)?rng[7:0]:0;
  for(j=0;j<8;j=j+1)if(pv[j])raw[j*8+:8]=(frames<1000)?rng[(j%4)*8+:8]:0;
  if(dut.sample_ce)begin
   frames=frames+1;
   if(frames<1000)begin
    cfg=(frames/40)%16;chord=(frames/61)%2;
    testmode=(frames/133)%2;t32=(frames/97)%2;
    modes=rng[15:0];mask=rng;mask4=rng[3:0];
   end else begin chord=0;testmode=0;cfg=0;end
   if(frames==5200)begin
    if(hn || dut.env_active)$fatal(1,"release/stale did not clear");
    if(compared<5190)$fatal(1,"insufficient coverage");
    $display("PASS %0d exact PCM frames and every I2S bit; 32 independent states, randomized modes/masks/pressure/effects, stale and full release, zero underruns",compared);
    $finish;
   end
  end
 end
 initial begin repeat(5)@(negedge clk);rst=1;#60000000;$fatal(1,"timeout");end
endmodule
