`timescale 1ns/1ps
module tb_mapped_expression_v14;
 reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,g=0,v=0;reg signed[4:0] lfo=0;
 reg[55:0] map=0;reg[15:0] modes=0;reg[1023:0] targets=0;
 wire va,vb,ba,bb,oa,ob;wire[4:0] ia,ib;wire[31:0] a,b;
 shared_pitch_engine #(.CUSTOM_MAP(1)) mapped(clk,rst,ce,g,v,1024'd0,lfo,va,ia,a,ba,oa,1'b1,map,modes);
 shared_pitch_engine reference(clk,rst,ce,g,v,targets,lfo,vb,ib,b,bb,ob,1'b0,56'd0,16'd0);
 reg[31:0] rom[0:127];integer trial,i,n,cycles,count=0;
 always @(negedge clk)if(rst)begin
  if(va!==vb || ba!==bb || oa!==ob)$fatal(1,"mapping changed schedule");
  if(va)begin if(ia!==ib || a!==b)$fatal(1,"mapped expression mismatch");count=count+1;end
 end
 initial begin
  $readmemh("assets/midi_inc_128.hex",rom);repeat(4)@(posedge clk);#1;rst=1;
  for(trial=0;trial<512;trial=trial+1)begin
   g=trial%3!=0;v=trial%5!=0;lfo=trial%32;
   for(i=0;i<8;i=i+1)begin map[i*7+:7]=(trial*7+i*13)%128;modes[i*2+:2]=(trial+i)%3;end
   for(i=0;i<32;i=i+1)begin
    n=map[(i%8)*7+:7];case(i/8)1:n=n+4;2:n=n+7;3:n=n+12;endcase
    case(modes[(i%8)*2+:2])1:n=n-12;2:n=n+12;endcase
    if(n<0)n=0;if(n>127)n=127;targets[i*32+:32]=rom[n];
   end
   ce=1;@(posedge clk);#1;ce=0;cycles=0;
   while(ba || va)begin @(posedge clk);#1;cycles=cycles+1;if(cycles>40)$fatal(1,"deadline");end
  end
  if(count!=16384)$fatal(1,"missing outputs");$display("PASS 16384 mapped glide/vibrato results exactly match legacy target math; all signed LFO values and unchanged batch schedule");$finish;
 end
endmodule
