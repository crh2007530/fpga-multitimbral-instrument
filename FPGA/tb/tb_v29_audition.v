`timescale 1ns/1ps
module tb_v29_audition;
reg clk=0;always #5 clk=~clk;
reg rst=0,iv=0,recording=0;reg signed[15:0]pcm=0;
wire[3:0]ov;wire[63:0]out;
integer files[0:3];integer count[0:3];integer src,n,k,r,x,y;
genvar g;generate for(g=0;g<4;g=g+1)begin:fx
 localparam[1:0] ROOM=g==0?0:g-1;
 wire[32:0] cfg={2'd0,2'd0,5'd0,3'd0,2'd0,5'd0,ROOM,ROOM,5'd12,5'd12};
 audio_send_fx dut(clk,rst,iv,pcm,cfg,g==0?3'd0:3'd1,1'b0,1'b0,ov[g],out[g*16+:16]);
end endgenerate
always @(posedge clk)begin #1;
 for(k=0;k<4;k=k+1)if(rst && ov[k] && recording)begin
  if(^out[k*16+:16]===1'bx)$fatal(1,"unknown output");
  y=$signed(out[k*16+:16])*2;
  if(y>32767 || y< -32768)$fatal(1,"master clipping mode %d sample %d value %d",k,count[k],y);
  $fdisplay(files[k],"%0d",y);count[k]=count[k]+1;
 end
end
task sample;input integer value;begin
 @(negedge clk);pcm=value;iv=1;@(negedge clk);iv=0;repeat(8)@(negedge clk);
end endtask
initial begin
files[0]=$fopen("checks/v29_dry.txt","w");files[1]=$fopen("checks/v29_room.txt","w");
files[2]=$fopen("checks/v29_hall.txt","w");files[3]=$fopen("checks/v29_large.txt","w");
for(n=0;n<4;n=n+1)count[n]=0;
repeat(4)@(negedge clk);rst=1;
for(n=0;n<10000;n=n+1)sample(0);
src=$fopen("checks/melody_piano.txt","r");if(!src)$fatal(1,"missing piano");recording=1;
for(n=0;n<432422;n=n+1)begin
 x=0;if(n<144141)begin r=$fscanf(src,"%d\n",x);if(r!=1)$fatal(1,"short source");end
 sample(x);
end
recording=0;$fclose(src);
for(n=0;n<4;n=n+1)begin $fclose(files[n]);if(count[n]!=432422)$fatal(1,"sample count");end
$display("PASS four actual RTL renders, identical piano and dry/wet gain, 432422 samples each, no unknown or master clipping");$finish;
end
endmodule

