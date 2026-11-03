`timescale 1ns/1ps
module tb_v29_piano_source;
reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,piano=0,guitar=0;
reg[3:0]on=0,off=0,gates=0;reg[31:0]phase[0:3];wire[39:0]addresses;wire[63:0]envs,samples;wire[3:0]active;
wire[63:0]steps;wire valid;
function[31:0]inc;input integer i;begin case(i)
0:inc=32'd23387021;1:inc=32'd29465800;2:inc=32'd35040938;3:inc=32'd46774041;default:inc=0;endcase end endfunction
genvar j;generate for(j=0;j<4;j=j+1)begin:notes
assign addresses[j*10+:10]=phase[j][31:22];assign steps[j*16+:16]=inc(j)>>16;
instrument_env #(.THIRD_TIMBRE(1)) env(clk,rst,ce,on[j],off[j],guitar,1'b0,envs[j*16+:16],active[j],piano);
end endgenerate
shared_voice_bank #(.VOICES(4),.GROUP(4),.THIRD_TIMBRE(1)) bank(clk,rst,ce,guitar,addresses,{4{16'd28672}},envs,samples,valid,piano,1'b0,steps,gates);
integer mode,n,i,f,total;reg[255:0]name;
initial begin
for(mode=2;mode<3;mode=mode+1)begin
rst=0;ce=0;on=0;off=0;gates=0;piano=mode==2;guitar=mode==1;
for(i=0;i<4;i=i+1)phase[i]=0;
repeat(4)@(negedge clk);rst=1;
case(mode)0:name="checks/melody_harmonica.txt";1:name="checks/melody_nylon.txt";2:name="checks/melody_piano.txt";endcase
f=$fopen(name,"w");
for(n=0;n<144141;n=n+1)begin
 @(negedge clk);on=0;off=0;
 for(i=0;i<4;i=i+1)begin
 if((i<3 && n==i*16816) || (i<3 && n==62461))begin on[i]=1;gates[i]=1;phase[i]=0;end
 if((i<3 && n==i*16816+7207) || (i<3 && n==74472))begin off[i]=1;gates[i]=0;end
 end
 @(negedge clk);on=0;off=0;ce=1;
 @(negedge clk);ce=0;wait(valid);@(negedge clk);
 total=0;for(i=0;i<4;i=i+1)begin if(^samples[i*16+:16]===1'bx)$fatal(1,"unknown melody");total=total+$signed(samples[i*16+:16]);end
 // Production non-expanded mixer /4, before Send and the common master gain.
 total=total>>>2;if(total>32767 || total< -32768)$fatal(1,"melody clipping");$fdisplay(f,"%0d",total);
 repeat(4)@(negedge clk);for(i=0;i<4;i=i+1)phase[i]=phase[i]+inc(i);
end
$fclose(f);if(active!=0)$fatal(1,"melody release stuck");
end
$display("PASS actual piano RTL source: C/E/G short notes then C-major chord, full release, no clipping or unknown samples");$finish;
end
endmodule
