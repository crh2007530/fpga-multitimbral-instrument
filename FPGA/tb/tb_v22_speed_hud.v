`timescale 1ns/1ps
module tb_v22_speed_hud;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0]s=0;reg[10:0]x=320;reg[9:0]y=112;
wire on;wire[3:0]r,c;wire[7:0]letter;
video_game_text dut(clk,rst,x,y,s,on,r,c,letter);
integer d,i,id;reg[7:0]rom[0:2047];initial $readmemh("assets/game_text.hex",rom);
initial begin repeat(3)@(negedge clk);rst=1;
for(d=0;d<4;d=d+1)begin
s[103:102]=d%3;s[104]=d==3;id=d==0?0:d==1?1:d==2?30:31;
for(i=0;i<24;i=i+1)begin x=320+i*16;repeat(4)@(negedge clk);if(!on || letter!==rom[id*64+i])$fatal(1,"speed HUD d=%d char=%d",d,i);end
end
s[104]=0;s[120]=0;s[101]=0;x=32;y=16;repeat(4)@(negedge clk);if(letter!=rom[27*64])$fatal(1,"Twinkle title");
s[104]=1;repeat(4)@(negedge clk);if(letter!=rom[31*64])$fatal(1,"uploaded chart mislabeled");
$display("PASS all speed labels, selection help, Twinkle title and custom-chart title");$finish;end
endmodule
