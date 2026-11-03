`timescale 1ns/1ps
`include "tb/video_labels_v30_reference.v"
module tb_v30_1_label_regression;
reg clk=0;always #5 clk=~clk;
reg rst_n=0;reg[127:0]game=0;reg[10:0]x=0;reg[9:0]y=0;
reg hi=0,vi=0,di=1,user_envelope=0,mixer_wv=0;
reg[23:0]rgb_in=24'h123456;reg[21:0]pitch_status=0;reg[63:0]mixer_data=0;reg signed[8:0]mixer_wave=0;
wire h0,v0,d0,h1,v1,d1;wire[23:0]c0,c1;
video_labels dut(game,clk,rst_n,x,y,hi,vi,di,rgb_in,h0,v0,d0,c0,user_envelope,pitch_status,mixer_data,mixer_wave,mixer_wv,24'd0);
video_labels_v30_reference refdut(game,clk,rst_n,x,y,hi,vi,di,rgb_in,h1,v1,d1,c1,user_envelope,pitch_status,mixer_data,mixer_wave,mixer_wv);
integer mode,xx,yy,n=0;
always @(posedge clk)begin #1;if(rst_n)begin
 if({h0,v0,d0,c0}!=={h1,v1,d1,c1})$fatal(1,"RGB mismatch x=%d y=%d",x,y);
 if(dut.text_on!==refdut.text_on)$fatal(1,"visibility mismatch");
 if(dut.text_on && {dut.row,dut.col,dut.letter,dut.text_color}!=={refdut.row,refdut.col,refdut.letter,refdut.text_color})$fatal(1,"glyph mismatch mode=%d x=%d y=%d",mode,x,y);
 n=n+1;
end end
initial begin
repeat(4)@(negedge clk);rst_n=1;
for(mode=0;mode<16;mode=mode+1)begin
 game=0;game[100]=mode[0];game[104]=mode[1];game[31]=mode[2];game[32]=mode[3];
 game[124:117]=mode*17;game[116:110]=mode*7;user_envelope=mode[0];pitch_status=mode*12345;
 if(mode==12)game[30]=1;
 if(mode==13)game[127]=1;
 if(mode==14)begin game[127]=1;game[126]=1;end
 mixer_data=mode==15?64'h0000000200000000:0;
 for(yy=0;yy<720;yy=yy+4)for(xx=0;xx<1280;xx=xx+(mode==0?1:16))begin
  @(negedge clk);x=xx;y=yy;hi=xx[0];vi=yy[0];
 end
end
repeat(8)@(negedge clk);
$display("PASS V30.1 mode0 every x, other 15 states every character; y step4; pixel/glyph equivalence, %d samples",n);$finish;
end
endmodule

