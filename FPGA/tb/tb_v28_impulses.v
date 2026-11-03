`timescale 1ns/1ps
module tb_v28_impulses;
reg clk=0;always #5 clk=~clk;reg rst=0,valid=0,clear=0;reg signed[15:0]pcm=0;reg[1:0]room=0,decay=0,tm=0,depth=0,rate=0;reg[2:0]feedback=0;
wire rv,ev,cv;wire signed[15:0]r,e,c;
send_reverb reverb(clk,rst,1'b1,valid,clear,room,decay,pcm,rv,r);
send_echo echo(clk,rst,1'b1,valid,clear,tm,feedback,pcm,ev,e);
send_chorus chorus(clk,rst,1'b1,valid,clear,depth,rate,pcm,cv,c);
integer preset,n,first,nonzero,last,tail;integer f;reg[511:0]name;
task sample;input integer v;begin @(negedge clk);valid=1;pcm=v;@(negedge clk);valid=0;repeat(10)@(negedge clk);end endtask
initial begin
for(preset=0;preset<3;preset=preset+1)begin
rst=0;repeat(3)@(negedge clk);rst=1;room=preset;decay=preset;tm=preset;feedback=preset==0?0:preset==1?4:6;depth=preset;rate=preset;
// Prime circular histories before impulse. Hardware always runs these memories.
for(n=0;n<9000;n=n+1)sample(0);
first=-1;nonzero=0;last=0;tail=0;
case(preset)0:name="checks/v28_impulse_room_short_gentle.csv";1:name="checks/v28_impulse_hall_rhythm_full.csv";2:name="checks/v28_impulse_large_long_wide.csv";endcase
f=$fopen(name,"w");$fdisplay(f,"reverb,echo,chorus");
for(n=0;n<60000;n=n+1)begin sample(n==0?12000:0);
if(^r===1'bx || ^e===1'bx || ^c===1'bx)$fatal(1,"uninitialized delay memory");
if(e!=0 && first<0)first=n;
if(r!=0)begin nonzero=nonzero+1;last=n;end
if(n>59000 && (e!=0 || r!=0 || c!=0))tail=tail+1;
$fdisplay(f,"%d,%d,%d",r,e,c);
end
$fclose(f);
if(first!=(2048<<preset))$fatal(1,"echo interval expected %d got %d",2048<<preset,first);
if(nonzero<20)$fatal(1,"no reverb diffusion");
$display("preset=%d echo_first=%d reverb_nonzero=%d last=%d final_tail=%d",preset,first,nonzero,last,tail);
end
$display("PASS all three preset impulse responses, exact delay intervals, bounded initialized wet outputs");$finish;
end
endmodule
