`timescale 1ns/1ps
`include "tb/send_reverb_v29_reference.v"
module tb_v30_reverb_equivalence;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=0,iv=0,clear=0;reg[1:0]room=0,decay=0;
reg signed[15:0]pcm=0;wire ov,rv;wire signed[15:0]out,refout;
send_reverb dut(clk,rst,en,iv,clear,room,decay,pcm,ov,out);
send_reverb_v29_reference reference(clk,rst,en,iv,clear,room,decay,pcm,rv,refout);
integer v,n,k,r,d;integer checked=0;
always @(negedge clk)if(rst)begin
 if(ov!==rv || (ov && out!==refout))$fatal(1,"sample differs %d %d",out,refout);
 if(ov)checked=checked+1;
end
initial begin
 // Exhaustive 20-bit values for every shift used by this module.
 for(n=1;n<=5;n=n+1)if(n!=4)
 for(v=-524288;v<524288;v=v+1)
 if(dut.shr(v,n)!==reference.shr(v,n))$fatal(1,"shift mismatch v=%d n=%d",v,n);
 repeat(3)@(negedge clk);rst=1;en=1;
 for(r=0;r<3;r=r+1)for(d=0;d<3;d=d+1)begin
  room=r;decay=d;
  for(k=0;k<6000;k=k+1)begin
   @(negedge clk);clear=k==0;en=k<5500;pcm=k<2500?((k*7919)%65536)-32768:0;iv=1;
   @(negedge clk);iv=0;repeat(6)@(negedge clk);
  end
 end
 repeat(10)@(negedge clk);
 if(checked!=54000)$fatal(1,"sample count %d",checked);
 $display("PASS 4194304 exhaustive shift cases and 54000 reverb samples bit-identical to approved V29 across all room/decay presets");$finish;
end
endmodule
