`timescale 1ns/1ps
module tb_mode_labels_v13;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0] g=0;reg[10:0] x=128;reg[9:0] y=16;
wire ho,vo,doo;wire[23:0] rgb;
video_labels dut(g,clk,rst,x,y,1'b0,1'b0,1'b1,24'd0,ho,vo,doo,rgb,1'b0,22'd0,64'd0,9'd0,1'b0,24'd0);
reg[511:0] expected;integer mode,i;
initial begin repeat(3)@(negedge clk);rst=1;
for(mode=0;mode<4;mode=mode+1)begin
 g=0;case(mode)
0:expected=dut.T0;
1:begin g[121]=1;expected=dut.T0F;end
2:begin g[127]=1;expected=dut.T04;end
3:begin g[127]=1;g[126]=1;expected=dut.T064;end
endcase
for(i=0;i<64;i=i+1)begin @(negedge clk);x=128+i*16;y=16;#1;
if(!dut.text_on || dut.letter!==expected[(63-i)*8+:8])$fatal(1,"mode title char %0d/%0d",mode,i);end
end
g[127]=1;expected=dut.T3TEST;
for(i=0;i<64;i=i+1)begin @(negedge clk);x=128+i*8;y=616;#1;if(dut.letter!==expected[(63-i)*8+:8])$fatal(1,"test instruction char");end
$display("PASS 320 label characters: PLAY PLUCK/FLUTE, TEST4/64, T8 exit and pad bypass warning");$finish;
end
endmodule
