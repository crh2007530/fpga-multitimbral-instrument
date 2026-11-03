`timescale 1ns/1ps
module tb_v24_logo;
reg clk=0;always #5 clk=~clk;
reg rst=0,game=1,testmode=0;reg[10:0]x=0;reg[9:0]y=0;wire[23:0]rgb;wire h,v,d;
video_brand_title dut(clk,rst,clk,rst,1'b0,9'd0,8'd0,1'b0,game,testmode,x,y,1'b0,1'b0,1'b1,24'h123456,h,v,d,rgb);
task pixel;input integer px,py;begin @(negedge clk);x=px;y=py;repeat(6)@(negedge clk);end endtask
integer i,j,fg=0,bg=0;reg[23:0]expected;
initial begin repeat(3)@(negedge clk);rst=1;
for(j=0;j<48;j=j+1)for(i=0;i<192;i=i+1)begin
 pixel(i+16,j+8);expected=dut.logo[j*256+i]?24'h69dfff:24'h123456;
 if(rgb!==expected)$fatal(1,"game logo transparency %d %d",i,j);
 if(dut.logo[j*256+i])fg=fg+1;else bg=bg+1;
end
if(fg==0 || bg==0)$fatal(1,"empty mask");
game=0;pixel(16,8);expected=dut.logo[0]?24'h005184:24'hffffff;
if(rgb!==expected)$fatal(1,"white page logo changed");
testmode=1;pixel(40,20);if(rgb!==24'h123456)$fatal(1,"test page overwritten");
$display("PASS 9216 logo pixels: cyan foreground transparent background; white/test pages preserved");$finish;end
endmodule
