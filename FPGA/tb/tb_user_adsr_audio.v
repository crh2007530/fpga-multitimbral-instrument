`timescale 1ns/1ps
module tb_user_adsr_audio;
reg clk=0;always #5 clk=~clk;reg rst=0;integer cycles=0,age=100,frames=0;wire[15:0]under;reg[7:0]pressure_valid=255;reg[63:0]pressure_raw=~64'd0;integer sounding=0;
pcm_pressure_poly32 #(.EXPRESSION(1),.INSTRUMENTS(1),.THIRD_TIMBRE(1),.WARMUP_FRAMES(1),.USER_ADSR(1)) dut(.adsr_config({1'b1,15'd2000,15'd18000,15'd1000,15'd8000}),.epiano_mode(1'b1),.clk(clk),.rst_n(rst),.pressure_valid(pressure_valid),.pressure_raw(pressure_raw),.voice_modes(16'd0),.chord_mode(1'b1),.test_mode(1'b0),.test32(1'b1),.test_mask(4'hf),.expression_config(4'hf),.mask32(64'hffffffffffffffff),.underruns(under));
always @(posedge clk)if(rst)begin
 cycles=cycles+1;if(dut.sample_ce)begin age=0;frames=frames+1;end else age=age+1;
 if(dut.monitor_valid && age>95)$fatal(1,"sample pipeline missed pre-latch budget");
 if(dut.monitor_valid && dut.monitor_pcm!=0)sounding=sounding+1;
 if(frames==90)pressure_raw=0;
 if(frames==160)begin
 if(dut.held32!=0 || dut.custom_active!=0 || dut.played_envelopes!=0)$fatal(1,"custom release failed");
 if(sounding<10)$fatal(1,"custom audio silent");
 end
 if(frames==60 && dut.held32!==64'hffffffffffffffff)$fatal(1,"all64 not active");
 if(frames==200)begin if(under!=0)$fatal(1,"I2S underrun");$display("PASS user ADSR actual 64-voice piano/all-effects audio, nonzero PCM, release to silence, deadline and zero underruns");$finish;end
end
initial begin #40;rst=1;#2000000;$fatal(1,"timeout");end
endmodule


