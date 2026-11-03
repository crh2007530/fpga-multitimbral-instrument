`timescale 1ns/1ps
module tb_shared_envelopes;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,diag=1,slow=0;reg[127:0]onv=0,offv=0;
`ifdef NATIVE_DPB
GSR GSR(.GSRI(rst));
`endif
wire[2047:0]levels,reference;wire[127:0]active,refactive;wire fault;
shared_envelope_bank dut(clk,rst,ce,onv,offv,diag,slow,levels,active,fault);
genvar g;generate for(g=0;g<128;g=g+1)begin:r
 instrument_env #(.THIRD_TIMBRE(1)) env(clk,rst,ce,onv[g],offv[g],1'b0,diag,reference[g*16+:16],refactive[g],slow);
end endgenerate
integer f,i;reg[31:0]rng=32'h19283746;reg[2047:0]expected;reg[127:0]expected_active;
task pulse;begin @(negedge clk);onv=0;offv=0;end endtask
task frame;begin
 repeat(4)@(negedge clk);ce=1;@(negedge clk);ce=0;
 repeat(3)@(negedge clk);expected=reference;expected_active=refactive;
 repeat(68)@(negedge clk);
 if(levels!==expected || active!==expected_active)begin
  for(i=0;i<128;i=i+1)if(levels[i*16+:16]!==expected[i*16+:16])$display("voice=%0d actual=%0d expected=%0d",i,levels[i*16+:16],expected[i*16+:16]);
  $fatal(1,"envelope mismatch frame %0d",f);
 end
 if(fault)$fatal(1,"scheduler/aperture fault");
end endtask
initial begin
 repeat(5)@(negedge clk);rst=1;
 onv=~128'd0;pulse;
 for(f=0;f<2500;f=f+1)frame;
 offv=~128'd0;pulse;
 for(f=2500;f<4800;f=f+1)frame;
 if(active!=0 || levels!=0)$fatal(1,"diagnostic release did not finish");
 for(f=4800;f<5312;f=f+1)begin
  diag=f%3==0;slow=f%2;
  for(i=0;i<128;i=i+1)begin
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};onv[i]=rng[3:0]==0;offv[i]=rng[3:0]==1;
  end
  pulse;
  if(f%7==0)begin offv=~128'd0;pulse;end
  frame;
 end
 $display("PASS 5312 frames x128 envelopes =679936 exact snapshot comparisons; full diagnostic ADSR/release, musical/slow release, retrigger and ordered on/off events");$finish;
end
endmodule
