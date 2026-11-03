`timescale 1ns/1ps
module tb_v30_3_mixer;
reg clk=0;always #5 clk=~clk;
reg[10:0]x=0;reg[9:0]y=0;reg[63:0]data=0;reg signed[8:0]wave=0;reg valid=0;
wire[23:0] bg0,bg1,c0,c1;wire t0,t1;wire[3:0]r0,r1,col0,col1;wire[7:0]ch0,ch1;wire[21:0]desc;
video_mixer refdut(x,y,data,wave,valid,bg0,c0,t0,r0,col0,ch0);
video_mixer_desc dut(x,y,data,wave,valid,bg1,c1,t1,r1,col1,desc);
video_mixer_char lookup(clk,desc,ch1);
integer k,xx,yy,count=0;reg[7:0]expected;
initial begin
 for(k=0;k<128;k=k+1)begin
  @(negedge clk);
  data=64'h0123456789abcdef ^ (64'h0001000100010001*k);
  data[4:0]=k%32;data[9:5]=k%32;data[18:14]=k%32;data[28:24]=k%32;
  data[37:34]=k%16;data[55:49]=k;wave=k*3-192;valid=k%2;
  for(yy=0;yy<720;yy=yy+8)for(xx=0;xx<1280;xx=xx+16)begin
   @(negedge clk);x=xx;y=yy;
   #1;if({bg0,c0,t0,r0,col0}!=={bg1,c1,t1,r1,col1})$fatal(1,"layout mismatch k=%d x=%d y=%d",k,x,y);
   expected=ch0;
   @(posedge clk);#1;
   if(ch1!==expected)$fatal(1,"mixer char mismatch k=%d x=%d y=%d got=%h expected=%h desc=%h",k,x,y,ch1,expected,desc);
   count=count+1;
  end
 end
 $display("PASS mixer character/background equivalence: %d samples, all 128 volume codes, all 32 gain codes, 16 selections",count);$finish;
end
endmodule
