`timescale 1ns/1ps
module tb_pcm64_mute_v16;
 reg clk=0;always #5 clk=~clk;reg rst=0;wire valid;wire signed[15:0] pcm;wire[63:0] held;wire[15:0] underruns;
 reg[6:0]fast_div=0;wire fast_ce=fast_div==0;always @(posedge clk)fast_div<=fast_div+1'b1;
 initial force dut.sample_ce=fast_ce;
 reg[63:0]mask=~64'd0;
 pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.WARMUP_FRAMES(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1)) dut(
 .epiano_mode(1'b0),.extra_fx(2'b11),.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(64'd0),.voice_modes(16'd0),.chord_mode(1'b0),.test_mode(1'b1),.test32(1'b1),
 .expression_config(4'd0),.test_mask(4'hf),.mask32(mask),.held32(held),.monitor_valid(valid),.monitor_pcm(pcm),.underruns(underruns),.map_enabled(1'b1),.keymap(56'd0));
 reg[15:0] expected_all[0:2047],expected_muted[0:2047];
 initial begin $readmemh("checks/pcm64_expected_all.hex",expected_all);$readmemh("checks/pcm64_expected_muted.hex",expected_muted);end
 integer samples=0,fd,last=0,cycle=0;
 always @(posedge clk)begin cycle=cycle+1;#1;if(rst && valid)begin
  samples=samples+1;if(samples>1 && cycle-last!=128)$fatal(1,"sample period");last=cycle;
  if(samples%1024==0)begin $display("PCM64 samples=%d",samples);$fflush();end
  if((samples>3072 && samples<=5120) || samples>7680)begin if(held!==mask || dut.env_active!==mask)$fatal(1,"not all64 active");$fdisplay(fd,"%d",pcm);end
  if(samples>3072 && samples<=5120 && pcm!==expected_all[samples-3073])$fatal(1,"PCM differs from approved preoptimization reference %d",samples);
  if(samples>7680 && pcm!==expected_muted[samples-7681])$fatal(1,"muted PCM differs from approved reference %d",samples);
  if(samples==5120)begin $fclose(fd);mask[31]=0;fd=$fopen("checks/pcm64_muted.txt","w");end
  if(samples==9728)begin $fclose(fd);if(underruns!=0 || dut.batch_overrun)$fatal(1,"underruns");$display("PASS bit-exact against approved preoptimization PCM reference: 2048 all-on and 2048 voice32-muted actual PCM samples, 64 active independent diagnostic voices, accelerated128-clock spectral schedule (I2S separately verified at512); spectral analysis required separately");$finish;end
 end end
 initial begin fd=$fopen("checks/pcm64_actual.txt","w");repeat(4)@(negedge clk);rst=1;end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule





