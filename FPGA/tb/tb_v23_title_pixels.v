`timescale 1ns/1ps
module tb_v23_title_pixels;
reg clk=0;always #5 clk=~clk;reg sys=0;always #7 sys=~sys;
reg rst=0,we=0,show=0;reg[8:0]addr=0;reg[7:0]data=0;reg[10:0]x=0;reg[9:0]y=100;
wire h,v,de;wire[23:0]rgb;
video_brand_title dut(clk,rst,sys,rst,we,addr,data,show,1'b1,1'b0,x,y,1'b0,1'b0,1'b1,24'h123456,h,v,de,rgb);
integer i,j;reg[7:0] pattern;reg[23:0] expected;
task pixel;input[10:0] px;input[9:0]py;begin @(negedge clk);x=px;y=py;repeat(6)@(negedge clk);end endtask
initial begin repeat(3)@(negedge clk);rst=1;
pixel(320,48);if(rgb!==24'h123456)$fatal(1,"unpublished RAM visible");
for(i=0;i<512;i=i+1)begin @(negedge sys);we=1;addr=i;data=i[0]?8'h55:8'haa;end
@(negedge sys);we=0;show=1;
for(j=0;j<16;j=j+1)for(i=0;i<256;i=i+1)begin
 pixel(320+i*2,48+j*2);
 pattern=(i/8)%2==0 ? 8'haa:8'h55;expected=pattern[7-i%8]?24'he5f4ff:24'h050918;
 if(rgb!==expected)$fatal(1,"title addressing x=%d y=%d rgb=%h",i,j,rgb);
end
pixel(832,48);if(rgb!==24'h123456)$fatal(1,"title clips outside rectangle");
pixel(464,80);if(rgb!==24'h123456)$fatal(1,"title overwrites judgment text");
show=0;pixel(320,48);if(rgb!==24'h123456)$fatal(1,"title invalid not hidden");
$display("PASS all 4096 title pixels, 2x scale, independent clocks, unpublished RAM masking and bounds");$finish;
end
endmodule
