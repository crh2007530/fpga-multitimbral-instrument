`timescale 1ns/1ps
module tb_test64_render;
reg clk=0;always #5 clk=~clk;reg rst=0;
reg[10:0]x=0;reg[9:0]y=0;reg valid=0;
reg[127:0]game=128'hc0000000000000000000000000000000;
reg[63:0]mask=~64'd0;reg[5:0]selected=0;
reg[7:0]heights[0:511];reg mode=0;
wire[10:0]xx=x-11'd128;
wire[23:0]background,rgb;wire de;wire[9:0] yy=y-128;wire[9:0] bin;test64_bin lookup({yy[8:7],xx[9:6]},bin);
video_test64 testpage(x,y,heights[{mode,bin[7:0]}],1'b1,mask,selected,background);
video_labels labels(game,clk,rst,x,y,1'b0,1'b0,valid,background,,,de,rgb,1'b0,22'd0,64'd0,9'd0,1'b0,24'd0);
integer f,i,n,lit;
initial begin
$readmemh("checks/fft64_heights.hex",heights);
repeat(4)@(negedge clk);rst=1;
for(n=0;n<2;n=n+1)begin
 mode=n;selected=n?31:0;mask=n?~(64'd1<<31):~64'd0;
 if(n==0)f=$fopen("checks/test64_all.ppm","wb");else f=$fopen("checks/test64_muted.ppm","wb");
 $fwrite(f,"P6\n1280 720\n255\n");lit=0;
 repeat(10)@(negedge clk);
 for(i=0;i<1280*720+4;i=i+1)begin
  @(negedge clk);valid=i<1280*720;x=i%1280;y=i/1280;
  @(posedge clk);#1;
  if(i>=3 && i<1280*720+3)begin
   if(^rgb===1'bx)$fatal(1,"unknown pixel");
   $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
   if(rgb==24'hffbb36)lit=lit+1;
  end
 end
 if(lit<1000)$fatal(1,"missing measured spectrum");$fclose(f);
end
$display("PASS full720p TEST64 renderer using production FFT results, all-on and channel32-muted");$finish;
end
endmodule
