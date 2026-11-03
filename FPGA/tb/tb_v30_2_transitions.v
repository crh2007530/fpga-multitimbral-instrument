`timescale 1ns/1ps
`include "tb/video_labels_v30_reference.v"
module tb_v30_2_transitions;
reg clk=0;always #5 clk=~clk;
reg rst_n=0;reg[127:0]game=0;reg[10:0]x=0;reg[9:0]y=0;
reg hi=0,vi=0,di=0,user_envelope=0,mixer_wv=0;
reg[23:0]rgb_in=0;reg[21:0]pitch_status=0;reg[63:0]mixer_data=0;reg signed[8:0]mixer_wave=0;
wire h0,v0,d0,h1,v1,d1;wire[23:0]c0,c1;
video_labels dut(game,clk,rst_n,x,y,hi,vi,di,rgb_in,h0,v0,d0,c0,user_envelope,pitch_status,mixer_data,mixer_wave,mixer_wv,24'd0);
video_labels_v30_reference refdut(game,clk,rst_n,x,y,hi,vi,di,rgb_in,h1,v1,d1,c1,user_envelope,pitch_status,mixer_data,mixer_wave,mixer_wv);
integer n,seed=32'h46328a,ncomp=0;reg[31:0]r;
always @(posedge clk)begin #1;if(rst_n)begin
 if(dut.normal1!==refdut.normal1)$fatal(1,"stage2 mismatch n=%d x=%d y=%d got=%h expected=%h desc=%h active=%b char=%h rom=%h suffix=%h use=%b",n,x,y,dut.normal1,refdut.normal1,dut.mix_descriptor0,dut.mix_active1,dut.mix_char1,dut.mix_lookup.rom_q,dut.mix_lookup.suffix_q,dut.mix_lookup.use_suffix_q);
 if({h0,v0,d0,c0}!=={h1,v1,d1,c1})$fatal(1,"RGB/sync mismatch n=%d",n);
 ncomp=ncomp+1;
end end
initial begin
 repeat(4)@(negedge clk);rst_n=1;
 for(n=0;n<20000;n=n+1)begin
  @(negedge clk);
  r=$random(seed);x=r%1650;r=$random(seed);y=r%750;
  game={$random(seed),$random(seed),$random(seed),$random(seed)};
  r=$random(seed);pitch_status={4'd8,r[17:0]};
  if(n%2==0)pitch_status[21:18]=n%8;
  mixer_data={$random(seed),$random(seed)};
  rgb_in=$random(seed);hi=n[0];vi=n[1];di=n[2];user_envelope=n[3];
  mixer_wave=$random(seed);mixer_wv=n[4];
  if(n==10000)rst_n=0;if(n==10003)rst_n=1;
 end
 repeat(8)@(negedge clk);
 $display("PASS cycle-exact descriptor stage/RGB/sync through randomized mode, reset, blanking, effects, pitch and mixer transitions: %d",ncomp);$finish;
end
endmodule

