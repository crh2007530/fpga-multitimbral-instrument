`timescale 1ns/1ps
module tb_review_independence;
reg clk=0;always #5 clk=~clk;
reg rst=0,checking=0;
// Speed up sample-counted state comparison only; not an audio timing test.
reg [3:0] sample_div=0;
always @(posedge clk) sample_div<=sample_div+1'b1;
wire fast_ce=(sample_div==15);
initial begin force dut.sample_ce=fast_ce;force reference.sample_ce=fast_ce;end
reg [63:0] raw={8{8'd64}};
reg [7:0] valid=255;
reg [1:0] mode=0;
integer target=-1,checks=0,k;
wire [7:0] held;
pcm_pressure_poly8 #(.WARMUP_FRAMES(8),.DYNAMIC_PITCH(1)) dut(.clk(clk),.rst_n(rst),.pressure_valid(valid),.pressure_raw(raw),.pitch_mode(mode),.held(held));
pcm_pressure_poly8 #(.WARMUP_FRAMES(8),.DYNAMIC_PITCH(1)) reference(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw({8{8'd64}}),.pitch_mode(2'd0));
genvar c;
generate for(c=0;c<8;c=c+1) begin: compare
always @(negedge clk) if(checking && c!=target) begin
 if(dut.notes[c].note.pcm!==reference.notes[c].note.pcm ||
    dut.notes[c].note.env.level!==reference.notes[c].note.env.level ||
    dut.notes[c].note.env.state!==reference.notes[c].note.env.state ||
    dut.notes[c].note.sine.phase_acc!==reference.notes[c].note.sine.phase_acc ||
    dut.notes[c].note.force_hold!==reference.notes[c].note.force_hold ||
    dut.notes[c].note.held!==reference.notes[c].note.held)
 $fatal(1,"unmodified voice %0d affected by voice %0d",c,target);
end
end endgenerate
task samples;
input integer count;
integer i;
begin for(i=0;i<count;i=i+1) begin @(posedge dut.sample_ce);@(negedge clk); end end
endtask
initial begin
 for(k=0;k<8;k=k+1) begin
  checking=0;rst=0;raw={8{8'd64}};valid=255;target=k;
  repeat(5) @(negedge clk);rst=1;samples(2400);checking=1;
  raw[k*8+:8]=192;samples(64);
  if(held!==255) $fatal(1,"gain caused release");
  raw[k*8+:8]=0;samples(2400);
  if(held!==(255^(1<<k))) $fatal(1,"release mask");
  raw[k*8+:8]=128;samples(300);
  if(held!==255) $fatal(1,"retrigger mask");
  checks=checks+1;
 end
 checking=0;raw=0;samples(4200);
 if(dut.mixed_pcm!==0 || held!==0 || dut.underruns!==0) $fatal(1,"final silence/underrun");
 $display("PASS independence: each of 8 voices gain/release/retrigger leaves other 7 PCM, phase, ADSR, force and held bit-identical to reference; final silence and no underrun");
 $finish;
end
initial begin #300000000;$fatal(1,"timeout");end
endmodule
