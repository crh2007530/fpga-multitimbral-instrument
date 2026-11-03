`timescale 1ns/1ps
module tb_multifx_v15;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,valid=0;reg[1:0] mode=0;reg signed[15:0] pcm=0;
 wire rv,ov;wire signed[15:0] rp,op;
 audio_reverb reverb(clk,rst,mode[0],valid,pcm,rv,rp);
 audio_chorus chorus(clk,rst,mode[1],rv,rp,ov,op);
 reg[19:0] inputs[0:139999];reg[15:0] expected[0:139999];integer i,j,seen=0;
reg start=0;wire recording,ready;wire[15:0] count;wire[7:0] rd;reg[7:0] expected_clip[0:32767];
pcm_clip_recorder recorder(clk,rst,start,1'b0,ov,op,recording,ready,count,15'd0,rd);
 always @(negedge clk)if(rst && ov)begin
 if(op!==expected[seen])$fatal(1,"sample %0d actual=%0d expected=%0d",seen,$signed(op),$signed(expected[seen]));seen=seen+1;
 end
 initial begin
 $readmemh("fx_clip_expected.hex",expected_clip);$readmemh("fx_input.hex",inputs);$readmemh("fx_expected.hex",expected);
 repeat(4)@(negedge clk);rst=1;start=1;@(negedge clk);start=0;
 for(i=0;i<140000;i=i+1)begin
 @(negedge clk);mode=inputs[i][17:16];pcm=inputs[i][15:0];valid=1;
 @(negedge clk);valid=0;repeat(14)@(negedge clk);
 if(seen!=i+1)$fatal(1,"missing/duplicate output");
 end
 if(!ready || count!=32768)$fatal(1,"effect recording capacity");
for(j=0;j<32768;j=j+1)if(recorder.memory[j]!==expected_clip[j])$fatal(1,"effect recording byte %0d",j);
$display("PASS 32768 recorded bytes from actual reverb/chorus output match independent reference");
$display("PASS 140000 exact reverb+fractional chorus samples: impulse decay, signed saturation, bypass, re-enable history masking and multiple LFO cycles and exact silent tail");$finish;
 end
endmodule
