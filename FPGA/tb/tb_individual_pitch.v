`timescale 1ns/1ps
module tb_individual_pitch;
reg clk=0;always #5 clk=~clk;
reg rst=0,checking=0;reg [15:0] modes=0;
reg [3:0] div=0;always @(posedge clk)div<=div+1'b1;
wire ce=div==15;integer target=-1,k,j;
initial begin force dut.sample_ce=ce;force refdut.sample_ce=ce;end
pcm_pressure_poly8 #(.PER_VOICE(1),.DYNAMIC_PITCH(1)) dut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw({8{8'd96}}),.voice_modes(modes),.test_mode(1'b0),.test_mask(4'hf),.pitch_mode(2'd0));
pcm_pressure_poly8 #(.PER_VOICE(1),.DYNAMIC_PITCH(1)) refdut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw({8{8'd96}}),.voice_modes(16'd0),.test_mode(1'b0),.test_mask(4'hf),.pitch_mode(2'd0));
genvar v;
generate for(v=0;v<8;v=v+1)begin: check
 reg [31:0] phase,inc;reg sampled;
 always @(posedge clk)begin phase=dut.notes[v].note.sine.phase_acc;inc=dut.notes[v].runtime_inc;sampled=ce;end
 always @(negedge clk)if(checking)begin
  if(sampled && dut.notes[v].note.sine.phase_acc!==phase+inc)$fatal(1,"phase reset/jump %d",v);
  if(dut.notes[v].note.envelope!==refdut.notes[v].note.envelope || dut.notes[v].note.env.state!==refdut.notes[v].note.env.state || !dut.held[v])$fatal(1,"ADSR retrigger %d",v);
  if(v!=target && (dut.notes[v].note.pcm!==refdut.notes[v].note.pcm || dut.notes[v].note.sine.phase_acc!==refdut.notes[v].note.sine.phase_acc))$fatal(1,"neighbor affected %d",v);
 end
end endgenerate
initial begin
 for(k=0;k<8;k=k+1)begin
  checking=0;rst=0;modes=0;target=k;repeat(4)@(negedge clk);rst=1;
  repeat(3000)@(negedge clk);checking=1;
  for(j=1;j<=3;j=j+1)begin
   modes[k*2+:2]=j==3?0:j;
   repeat(2048)@(negedge clk);
  end
 end
 $display("PASS per-voice live pitch: all 8 targets low/high/normal, phase increments without resets, ADSR unchanged, other 7 PCM and phases bit-identical");$finish;
end
endmodule
