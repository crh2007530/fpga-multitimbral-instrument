`timescale 1ns/1ps
module tb_output_gain_v15_2;
 reg clk=0; always #5 clk=~clk;
 reg rst=0, run_checks=0;
 reg [63:0] raw=0;
 reg [3:0] cfg=0;
 reg chord=0;
 wire bclk,lrclk,din,valid,xsmt;
 wire signed [15:0] pcm;
 wire [15:0] underruns;
 pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),
 .WARMUP_FRAMES(1),.CUSTOM_MAP(1),.MULTIFX(1)) dut(
 .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),
 .voice_modes(16'd0),.chord_mode(chord),.test_mode(1'b0),.test32(1'b0),
 .test_mask(4'hf),.mask32(~64'd0),.expression_config(cfg),
 .map_enabled(1'b1),.keymap({8{7'd69}}),.extra_fx(2'b11),
 .bclk(bclk),.lrclk(lrclk),.din(din),.xsmt(xsmt),.monitor_valid(valid),
 .monitor_pcm(pcm),.underruns(underruns));
 function signed [15:0] reference_gain;
 input signed [15:0] sample_in;
 integer value;
 begin
 value=$signed(sample_in)*2;
 if(value>32767) reference_gain=16'sh7fff;
 else if(value< -32768) reference_gain=16'sh8000;
 else reference_gain=value;
 end endfunction
 reg signed [15:0] injected;
 integer i,age=0,frames=0,observed=0,nonzero=0,clipped=0;
 integer left_words=0,right_words=0,max_age=0;
 reg [15:0] pending=0,expected_frame=0,left_word=0,right_word=0;
 reg pending_fresh=0;
 // Capture the externally observable sample publication and its frame deadline.
 always @(posedge clk) if(rst && run_checks) begin
 if(dut.sample_ce) age=0; else age=age+1;
 if(valid) begin
 if(pcm !== (xsmt ? reference_gain(dut.fx_pcm) : 16'sd0))
   $fatal(1,"real synthesis/effects gain mismatch");
 if(age>31) $fatal(1,"audio deadline missed age=%0d",age);
 if(age>max_age)max_age=age;
 pending=pcm;pending_fresh=1;observed=observed+1;
 if(pcm!=0)nonzero=nonzero+1;
 if($signed(dut.fx_pcm)>16383 || $signed(dut.fx_pcm)< -16384)clipped=clipped+1;
 end
 if(dut.tx.divider==7 && dut.tx.bit_index==63)begin
 expected_frame=pending_fresh ? pending : 16'd0;pending_fresh=0;frames=frames+1;
 end
 end
 // Decode the actual serial output, both channels and all padding bits.
 always @(posedge bclk) if(rst && run_checks)begin
 if(dut.tx.bit_index>=1 && dut.tx.bit_index<=16)begin
 if(lrclk!==0)$fatal(1,"left LRCLK");
 left_word={left_word[14:0],din};
 if(dut.tx.bit_index==16)begin
 if(left_word!==expected_frame)$fatal(1,"left I2S data mismatch");
 left_words=left_words+1;
 end
 end else if(dut.tx.bit_index>=33 && dut.tx.bit_index<=48)begin
 if(lrclk!==1)$fatal(1,"right LRCLK");
 right_word={right_word[14:0],din};
 if(dut.tx.bit_index==48)begin
 if(right_word!==expected_frame)$fatal(1,"right I2S data mismatch");
 right_words=right_words+1;
 end
 end else if(din!==0)$fatal(1,"nonzero I2S padding");
 end
 initial begin
 // Exhaustive signed input sweep through the production gain expression.
 force dut.fx_pcm=injected;
 force dut.xsmt=1'b1;
 for(i=-32768;i<=32767;i=i+1)begin
 injected=i;#1;
 if(pcm!==reference_gain(injected))$fatal(1,"exhaustive gain mismatch input=%0d",i);
 end
 force dut.xsmt=1'b0;#1;
 if(pcm!==0)$fatal(1,"mute failed");
 release dut.fx_pcm;release dut.xsmt;
 repeat(4)@(negedge clk);
 rst=1;run_checks=1;
 // Silence, single pad, 8 pads, 64 voices, both timbres and all effects.
 for(i=0;i<512;i=i+1)begin
 case(i)
 16:raw=64'h0000000000000060;
 96:raw=64'hffffffffffffffff;
 192:begin chord=1;cfg=4'hf;end
 320:cfg=4'he;
 400:raw=0;
 endcase
 repeat(512)@(negedge clk);
 end
 if(underruns!=0)$fatal(1,"I2S underruns=%0d",underruns);
 if(nonzero<100 || left_words<500 || right_words<500)$fatal(1,"insufficient audio coverage");
 $display("PASS exhaustive 65536 gain inputs, mute, actual synth/all-effects, 512 frames stereo I2S. samples=%0d nonzero=%0d clipped=%0d max_age=%0d underruns=%0d left=%0d right=%0d",observed,nonzero,clipped,max_age,underruns,left_words,right_words);
 $finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
