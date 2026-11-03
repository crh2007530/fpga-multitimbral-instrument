`timescale 1ns/1ps
module tb_exp3_pipeline;
reg clk=0;always #5 clk=~clk;reg rst=0;
reg[7:0] valid=0;reg[63:0] raw=0;reg[3:0] cfg=0;
wire[15:0] under;wire ct,mv;wire signed[15:0] mp;
pcm_pressure_poly32 #(.WARMUP_FRAMES(1),.EXPRESSION(1),.FRAME_CONTROL(1)) dut(
 .clk(clk),.rst_n(rst),.pressure_valid(valid),.pressure_raw(raw),
 .expression_config(cfg),.voice_modes(16'd0),.chord_mode(1'b1),.test_mode(1'b0),
 .test32(1'b0),.test_mask(4'd0),.mask32(32'd0),.underruns(under),
 .control_tick(ct),.monitor_valid(mv),.monitor_pcm(mp));
integer cycles=0,lastct=-1000,lastsample=-1000,frames=0,age=-1,first_latency=-1;
integer commit_cycle=-1;reg[7:0] prevheld=0;
always @(negedge clk)if(rst)begin
 // Deliberately vary arrival phase and all effect combinations under 32 voices.
 valid=cycles%523==0?8'hff:0;
 raw={8{8'd180}};cfg=(frames/32)%16;
end
always @(posedge clk)if(rst)begin
 cycles=cycles+1;
 if(ct)begin
  if(lastct>=0 && cycles-lastct!=512)$fatal(1,"frame cadence");
  lastct=cycles;
  if(|dut.scheduled_valid)commit_cycle=cycles;
 end
 if(dut.sample_ce)begin
  if(cycles-lastct!=8)$fatal(1,"admission to sample not 8 clocks");
  lastsample=cycles;frames=frames+1;
 end
 if(mv)begin
  if(first_latency<0)first_latency=cycles-lastsample;
  if(cycles-lastsample!=first_latency || cycles-lastsample>12)$fatal(1,"variable sample pipeline");
  if(^mp===1'bx)$fatal(1,"undefined PCM");
 end
 if(dut.held!=prevheld && dut.held==8'hff)begin
  if(cycles-commit_cycle!=1)$fatal(1,"held transition not scheduled");
 end
 prevheld=dut.held;
 if(frames==600)begin
  if(under!=0)$fatal(1,"underrun");
  if(dut.held32!==32'hffffffff)$fatal(1,"32 voices inactive");
  $display("PASS 600 actual I2S frames, 32 voices, all 16 effect combinations; admission->sample=8 clocks; sample->valid=%0d clocks; underruns=0",first_latency);$finish;
 end
end
initial begin #40;rst=1;#10000000;$fatal(1,"timeout");end
endmodule
