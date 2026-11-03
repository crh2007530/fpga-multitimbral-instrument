`timescale 1ns/1ps
module tb_exp1_audio;
reg clk=0;always #5 clk=~clk;reg rst=0;
reg[63:0]raw=64'h6060606060606060;reg[15:0]modes=0;reg chord=0,fft=0,fft32=0;reg[31:0]mask=32'hffffffff;
wire[7:0]held;wire[31:0]held32;
pcm_pressure_poly32 #(.WARMUP_FRAMES(1)) dut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.voice_modes(modes),.chord_mode(chord),.test_mode(fft),.test32(fft32),.test_mask(4'hf),.mask32(mask),.held(held),.held32(held32));
pcm_pressure_poly8 #(.WARMUP_FRAMES(1),.PER_VOICE(1),.DYNAMIC_PITCH(1)) reference(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.voice_modes(modes),.pitch_mode(2'd0),.test_mode(1'b0),.test_mask(4'hf));
reg[3:0]div=0;always @(posedge clk)div<=div+1'b1;wire ce=div==15;
initial begin force dut.sample_ce=ce;force reference.sample_ce=ce;end
integer n,fd;reg check_basic=1,capture=0;
always @(negedge clk)if(rst && dut.mixed_valid)begin
 if(check_basic && (dut.mixed_pcm!==reference.mixed_pcm || dut.held!==reference.held))$fatal(1,"basic PCM changed");
 if(capture)$fdisplay(fd,"%0d",$signed(dut.mixed_pcm));
end
task samples;input integer cnt;integer j;begin for(j=0;j<cnt;j=j+1)begin @(posedge ce);@(negedge clk);end end endtask
initial begin
 fd=$fopen("checks/exp1_pcm.txt","w");repeat(4)@(negedge clk);rst=1;samples(1000);
 modes=16'h4926;samples(200);raw=0;samples(4000);
 if(dut.mixed_pcm!==0)$fatal(1,"basic release silence");
 check_basic=0;modes=0;raw=64'h6060606060606060;chord=1;samples(4000);
 if(held32!==32'hffffffff)$fatal(1,"32 chord gates");
 raw[2*8+:8]=0;samples(4000);
 if(held32!==32'hfbfbfbfb)$fatal(1,"pad3 only releases its four notes");
 raw=0;samples(4000);if(dut.mixed_pcm!==0)$fatal(1,"32 release silence");
 fft=1;fft32=1;samples(5000);if(held32!==32'hffffffff)$fatal(1,"32 test gates");
 capture=1;samples(32768);capture=0;
 mask=32'hffffff7f;samples(5000);if(held32!==32'hffffff7f)$fatal(1,"test voice8 muted");
 capture=1;samples(32768);capture=0;
 mask=0;samples(5000);if(dut.mixed_pcm!==0||held32!==0)$fatal(1,"all32 muted silence");
 fft=0;chord=0;samples(5000);if(dut.mixed_pcm!==0)$fatal(1,"return basic silence");
 $fclose(fd);$display("PASS baseline PCM bit-identical, pad quartet release, 32 enabled test oscillators, individual mute and release silence; 65536 PCM samples exported");$finish;
end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
