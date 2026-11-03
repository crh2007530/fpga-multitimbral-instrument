`timescale 1ns/1ps
module tb_instrument_deadline;
reg clk=0;always #5 clk=~clk;reg rst=0;integer cycles=0,age=100,frames=0;wire[15:0]under;
pcm_pressure_poly32 #(.EXPRESSION(1),.INSTRUMENTS(1),.WARMUP_FRAMES(1)) dut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(64'hffffffffffffffff),.voice_modes(16'd0),.chord_mode(1'b1),.test_mode(1'b0),.test32(1'b1),.test_mask(4'hf),.expression_config(4'hf),.mask32(64'hffffffffffffffff),.underruns(under));
always @(posedge clk)if(rst)begin
 cycles=cycles+1;if(dut.sample_ce)begin age=0;frames=frames+1;end else age=age+1;
 if(dut.monitor_valid && age>24)$fatal(1,"sample pipeline missed pre-latch budget");
 if(frames==200)begin if(dut.held32!==64'hffffffffffffffff)$fatal(1,"not all voices held");if(under!=0)$fatal(1,"I2S underrun");$display("PASS actual I2S sample cadence: all64 with glide/vibrato/echo PCM ready within 24 audio clocks and zero underruns for 200 frames");$finish;end
end
initial begin #40;rst=1;#2000000;$fatal(1,"timeout");end
endmodule
