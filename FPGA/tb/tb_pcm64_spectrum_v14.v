`timescale 1ns/1ps
module tb_pcm64_spectrum_v14;
 reg clk=0;always #5 clk=~clk;reg rst=0;wire valid;wire signed[15:0] pcm;wire[63:0] held;wire[15:0] underruns;
 pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.WARMUP_FRAMES(1),.CUSTOM_MAP(1),.MULTIFX(1)) dut(
 .extra_fx(2'b11),.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(64'd0),.voice_modes(16'd0),.chord_mode(1'b0),.test_mode(1'b1),.test32(1'b1),
 .expression_config(4'd0),.test_mask(4'hf),.mask32(~64'd0),.held32(held),.monitor_valid(valid),.monitor_pcm(pcm),.underruns(underruns),.map_enabled(1'b1),.keymap(56'd0));
 integer samples=0,fd,last=0,cycle=0;
 always @(posedge clk)begin cycle=cycle+1;#1;if(rst && valid)begin
  samples=samples+1;if(samples>1 && cycle-last!=512)$fatal(1,"sample period");last=cycle;
  if(samples%1024==0)begin $display("PCM64 samples=%d",samples);$fflush();end
  if(samples>256)begin if(held!==~64'd0 || dut.env_active!==~64'd0)$fatal(1,"not all64 active");$fdisplay(fd,"%d",pcm);end
  if(samples==2304)begin $fclose(fd);if(underruns!=0)$fatal(1,"underruns");$display("PASS 2048 actual synthesized PCM samples, 64 active independent diagnostic voices, 512-clock cadence; spectral analysis required separately");$finish;end
 end end
 initial begin fd=$fopen("checks/pcm64_actual.txt","w");repeat(4)@(negedge clk);rst=1;end
 initial begin #40000000;$fatal(1,"timeout");end
endmodule

