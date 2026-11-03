`include "tb/reference_shared_voice_bank_64.v"
`timescale 1ns/1ps
module tb_four_lane_bank;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,guitar=0,piano=0,diag=0;
`ifdef NATIVE_DPB
GSR GSR(.GSRI(rst));
`endif
reg[1279:0]addr=0;reg[2047:0]env=0,forcev=0,inc=0;reg[127:0]gate=0;
wire[2047:0]out128;wire[1023:0]out0,out1;wire v128,v0,v1;
shared_voice_bank #(.PAIR_STATE_RAM(1),.COUNTER_SCHED(1),.VOICES(128),.GROUP(64),.THIRD_TIMBRE(1),.SUM_ONLY(1)) dut(clk,rst,ce,guitar,addr,forcev,env,out128,v128,piano,diag,inc,gate);
reference_shared_voice_bank_64 #(.VOICES(64),.GROUP(32),.THIRD_TIMBRE(1),.SUM_ONLY(1)) ref0(clk,rst,ce,guitar,addr[639:0],forcev[1023:0],env[1023:0],out0,v0,piano,diag,inc[1023:0],gate[63:0]);
reference_shared_voice_bank_64 #(.VOICES(64),.GROUP(32),.THIRD_TIMBRE(1),.SUM_ONLY(1)) ref1(clk,rst,ce,guitar,addr[1279:640],forcev[2047:1024],env[2047:1024],out1,v1,piano,diag,inc[2047:1024],gate[127:64]);
genvar rp;
generate for(rp=0;rp<2;rp=rp+2)begin:collision_check
always @(posedge clk)if(rst)begin
 if(dut.instruments.state_ren[rp] && dut.instruments.state_ren[rp+1])$fatal(1,"read collision");
 if(dut.instruments.state_wen[rp] && dut.instruments.state_wen[rp+1])$fatal(1,"write collision");
end
end endgenerate
integer f,i,age;reg[31:0]rng=32'h12345678;reg signed[22:0]expected;
initial begin
repeat(4)@(negedge clk);rst=1;
for(f=0;f<512;f=f+1)begin
guitar=f%4==1;piano=f%4==2;diag=f%4==3;
for(i=0;i<128;i=i+1)begin
rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
addr[i*10+:10]=rng[9:0];env[i*16+:16]={1'b0,rng[30:16]};forcev[i*16+:16]={1'b0,rng[14:0]};inc[i*16+:16]=rng[31:16];gate[i]=rng[0];
end
ce=1;@(negedge clk);ce=0;age=1;
while(!v128 && age<190)begin
 @(negedge clk);age=age+1;
 if(v0)begin
  if(!v1)$fatal(1,"reference lane mismatch");
  expected=$signed(out0[21:0])+$signed(out1[21:0]);
 end
end
if(age!=140 || !v128)$fatal(1,"128 bank deadline age=%d",age);
if($signed(out128[22:0])!==expected)$fatal(1,"sum mismatch frame=%d actual=%d expected=%d",f,$signed(out128[22:0]),expected);
if(|out128[2047:23])$fatal(1,"packed result upper bits");
repeat(4)@(negedge clk);
end
$display("PASS 512 frames / 65536 voice updates; 128 bank exact sum equivalence against two 64 banks; four timbre/diagnostic settings; 140-cycle publication");$finish;
end
endmodule
