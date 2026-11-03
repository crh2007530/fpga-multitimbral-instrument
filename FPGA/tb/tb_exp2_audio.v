`timescale 1ns/1ps
module tb_exp2_audio;
reg clk=0;always #5 clk=~clk;reg rst=0;
reg [3:0] config_bits=0;reg fft=0;reg [63:0] raw=64'h6060606060606060;
pcm_pressure_poly32 #(.WARMUP_FRAMES(1),.EXPRESSION(1)) dut(
 .clk(clk),.rst_n(rst),.expression_config(config_bits),.pressure_valid(8'hff),.pressure_raw(raw),
 .voice_modes(16'd0),.chord_mode(1'b1),.test_mode(fft),.test32(1'b1),.test_mask(4'hf),.mask32(32'hffffffff));
pcm_pressure_poly32 #(.WARMUP_FRAMES(1)) ref32(
 .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.voice_modes(16'd0),
 .chord_mode(1'b1),.test_mode(fft),.test32(1'b1),.test_mask(4'hf),.mask32(32'hffffffff));
reg [3:0] div=0;always @(posedge clk)div<=div+1'b1;
wire ce=div==15;
initial begin force dut.sample_ce=ce;force ref32.sample_ce=ce;end
reg signed [15:0] reference_sample;reg ref_pending=0,bypass_pending=0;integer capture=0,fd,n,seen=0;
always @(negedge clk)if(rst)begin
 if(dut.mixed_valid)begin
   reference_sample=dut.mixed_pcm;ref_pending=1;bypass_pending=(config_bits==0 || fft);
   if(capture==1 && dut.mixed_pcm!==ref32.mixed_pcm)$fatal(1,"baseline changed");
 end
 if(dut.fx_valid)begin
   if(bypass_pending && ref_pending && dut.fx_pcm!==reference_sample)
     $fatal(1,"dry/test bypass is not sample-identical");
   if(capture!=0)$fdisplay(fd,"%0d,%0d",capture,$signed(dut.fx_pcm));
   if(^dut.fx_pcm===1'bx)$fatal(1,"uninitialized audio leaked");
   ref_pending=0;seen=seen+1;
 end
end
task samples;input integer count;integer j;
begin for(j=0;j<count;j=j+1)begin @(posedge ce);@(negedge clk);end end endtask
initial begin
 fd=$fopen("checks/exp2_audio.txt","w");repeat(4)@(negedge clk);rst=1;
 samples(5000);capture=1;samples(8192);capture=0;
 config_bits=1;samples(1000);capture=2;samples(8192);capture=0;
 config_bits=15;samples(12000);capture=3;samples(8192);capture=0;
 // Test mode must bypass all stored performance effects, even with echo history.
 fft=1;samples(1000);capture=4;samples(8192);capture=0;
 if(dut.held32!==32'hffffffff)$fatal(1,"32 voices lost");
 fft=0;config_bits=0;raw=0;samples(5000);
 if(dut.fx_pcm!==0)$fatal(1,"release/bypass silence");
 $fclose(fd);$display("PASS EXP2 32-voice integrated audio: baseline and FFT bit-identical, two timbres, combined effects, no X audio, release silence; four 8192-sample captures");$finish;
end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
