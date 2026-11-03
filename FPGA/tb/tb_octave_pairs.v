`timescale 1ns/1ps
module tb_octave_pairs;
 reg clk=0;always #5 clk=~clk;reg rst=0,testing=0;reg[63:0] mask=64'hffffffffffffffff;
 wire[63:0] held;wire[15:0] under;
 pcm_pressure_poly32 #(.EXPRESSION(1),.WARMUP_FRAMES(1)) dut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(64'h6060606060606060),.voice_modes(16'h5555),.chord_mode(1'b1),.test_mode(testing),.test32(1'b1),.expression_config(4'h7),.test_mask(4'hf),.mask32(mask),.held32(held),.underruns(under));
 genvar v;generate for(v=32;v<64;v=v+1)begin:checks
 always @(negedge clk)if(rst)begin
  if(!testing && dut.notes[v].expressive_inc!==(dut.pitch_bus[(v-32)*32+:32]>>1))$fatal(1,"octave ratio %d",v);
  if(testing && dut.notes[v].expressive_inc!==dut.test_inc(v))$fatal(1,"test override %d",v);
 end
 end endgenerate
 integer i,j;
 initial begin repeat(3)@(negedge clk);rst=1;repeat(20000)@(negedge clk);
 testing=1;repeat(2000)@(negedge clk);
 for(i=0;i<64;i=i+1)for(j=0;j<i;j=j+1)if(dut.test_inc(i)==dut.test_inc(j))$fatal(1,"duplicate test pitch");
 if(held!==64'hffffffffffffffff)$fatal(1,"all64 gates");
 mask[63]=0;repeat(8)@(negedge clk);
 if(held[63] || !held[31])$fatal(1,"octave gate independence");
 mask[63]=1;repeat(8)@(negedge clk);if(!held[63])$fatal(1,"restore upper gate");
 if(under)$fatal(1,"underrun");
 $display("PASS octave-pair expression ratio, 64 distinct independent test pitches, independent upper/lower gates, no underrun");$finish;
 end
endmodule
