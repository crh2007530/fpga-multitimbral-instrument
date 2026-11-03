`timescale 1ns/1ps
`include "tb/reference_send_fx.v"
module tb_v28_equivalence;
reg clk=0;always #5 clk=~clk;reg rst=0,valid=0,bypass=0,testmode=0;
reg signed[15:0] pcm=0;reg[32:0]cfg={2'd0,2'd0,5'd8,3'd4,2'd0,5'd8,2'd1,2'd1,5'd8,5'd16};reg[2:0]en=0;
wire ov;wire signed[15:0]out;integer n,count=0,expected=0,verify=0,energy=0;integer file;
audio_send_fx dut(clk,rst,valid,pcm,cfg,en,bypass,testmode,ov,out);
wire rov;wire signed[15:0] reference_out;reg signed[15:0] reference_sample;integer eq_count=0;
reference_send_fx ref_dut(clk,rst,valid,pcm,cfg,en,bypass,testmode,rov,reference_out);
always @(posedge clk)begin #1;
 if(rst && rov)reference_sample=reference_out;
 if(rst && ov)begin
 if(out!==reference_sample)$fatal(1,"shared multiplier changed sample %d: %d vs %d",eq_count,out,reference_sample);
 eq_count=eq_count+1;
 end
if(rst && ov)begin
 count=count+1;if(^out===1'bx)$fatal(1,"unknown output");
 if(verify && out!==expected)$fatal(1,"dry/test path mismatch %d %d",out,expected);
 if(out!=0)energy=energy+1;
 if(file)$fwrite(file,"%d\n",out);
end end
task sample;input integer value;begin
 @(negedge clk);pcm=value;expected=value;valid=1;@(negedge clk);valid=0;repeat(14)@(negedge clk);
end endtask
initial begin file=0;repeat(3)@(negedge clk);rst=1;verify=1;
for(n=0;n<600;n=n+1)sample((n*97)%20000-10000);
verify=0;en=7;for(n=0;n<3000;n=n+1)sample(0);
energy=0;file=$fopen("checks/v28_all_fx_impulse.txt","w");sample(12000);for(n=0;n<24000;n=n+1)sample(0);$fclose(file);file=0;
if(energy<100)$fatal(1,"wet sends have no tail %d",energy);
testmode=1;verify=1;for(n=0;n<400;n=n+1)sample(n*31-6000);
sample(0);testmode=0;for(n=0;n<10000;n=n+1)sample(0);
verify=0;bypass=1;for(n=0;n<300;n=n+1)sample(0);
verify=1;for(n=0;n<100;n=n+1)sample(3000-n*13);
verify=0;bypass=0;
// All extremes and live shape changes must remain initialized and finite.
for(n=0;n<4000;n=n+1)begin
 if(n%500==0)begin cfg[13:10]=n%3*5;cfg[23:19]={3'd6,2'd2};cfg[32:29]=4'ha;end
 sample(n%97<48?12000:-12000);
end
if(count!=42402)$display("sample count=%d",count);
$display("PASS bit-exact shared multiplier equivalence samples=%d across bypass, test, effects and live preset changes",eq_count);$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule

