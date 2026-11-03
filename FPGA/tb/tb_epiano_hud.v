`timescale 1ns/1ps
module tb_epiano_hud;
 reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0] game=0;reg[10:0]x=128;reg[9:0]y=16;
 video_labels dut(.game(game),.clk(clk),.rst_n(rst),.x(x),.y(y),.hi(1'b0),.vi(1'b0),.di(1'b1),.rgb_in(24'd0));
 integer i;
 initial begin repeat(3)@(negedge clk);rst=1;game[120]=1;
 for(i=0;i<64;i=i+1)begin x=128+i*16;#1;if(dut.letter!==dut.T0P[(63-i)*8+:8])$fatal(1,"piano header");end
 game[30]=1;x=32;repeat(6)@(negedge clk);
 if(dut.game_text.letter!="N")$fatal(1,"game piano heading");
 x=32+14*16;repeat(6)@(negedge clk);if(dut.game_text.letter!="E")$fatal(1,"game E.PIANO");
 game[30]=0;game[127]=1;x=128;#1;if(dut.letter!==dut.T04[511:504])$fatal(1,"test header priority");
 $display("PASS PLAY E.PIANO header, game E.PIANO ROM row, diagnostic title priority");$finish;
 end
endmodule
