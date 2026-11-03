`timescale 1ns/1ps
module tb_test64_cells;
reg[10:0]x;reg[9:0]y;reg[63:0]mask;reg[5:0]sel;wire[23:0]rgb;
reg[7:0]mag=100;reg visible=1;
video_test64 dut(x,y,mag,visible,mask,sel,rgb);
integer i;
initial begin
for(i=0;i<64;i=i+1)begin
 mask=~64'd0;sel=i;x=128+(i%16)*64+5;y=128+(i/16)*128+100;#1;
 if(rgb!==24'h16583c)$fatal(1,"active cell %d",i);
 mask[i]=0;#1;if(rgb!==24'h721f32)$fatal(1,"muted cell %d",i);
 x=128+(i%16)*64;#1;if(rgb!==24'hffdf40)$fatal(1,"selected outline");
end
x=128+4*64+25;y=128+90;mask=0;#1;if(rgb!==24'hffbb36)$fatal(1,"mask incorrectly gates real FFT");
mag=0;#1;if(rgb===24'hffbb36)$fatal(1,"fake peak when magnitude zero");
$display("PASS all64 numbered ON/OFF cells and selection border; spectrum follows measurement not command mask");$finish;
end
endmodule
