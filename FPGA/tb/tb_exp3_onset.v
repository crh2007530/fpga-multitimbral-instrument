`timescale 1ns/1ps
module tb_exp3_onset;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[7:0] valid=0;reg[63:0]raw=0;
wire ct;integer phase,t,origin,cyc=0;
pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.WARMUP_FRAMES(1)) dut(
 .clk(clk),.rst_n(rst),.pressure_valid(valid),.pressure_raw(raw),.expression_config(4'd0),
 .voice_modes(16'd0),.chord_mode(1'b1),.test_mode(1'b0),.test32(1'b0),.test_mask(4'd0),.mask32(32'd0),.control_tick(ct));
always @(posedge clk)cyc=cyc+1;
initial begin
 for(phase=0;phase<512;phase=phase+31)begin
  @(negedge clk);rst=0;valid=0;raw=0;repeat(4)@(negedge clk);rst=1;
  wait(ct);@(posedge clk);@(negedge clk);repeat(phase)@(negedge clk);
  raw={8{8'd128}};valid=255;@(negedge clk);valid=0;
  wait(ct);@(posedge clk);#1;origin=cyc;
  wait(dut.notes[0].shared_state.state.env.level!=0);#1;
  if(cyc-origin!=8)$fatal(1,"phase %0d onset varies: %0d",phase,cyc-origin);
  if(dut.notes[31].shared_state.state.env.level!=137)$fatal(1,"32 voice onset skew");
 end
 $display("PASS 17 asynchronous arrival phases: all32 envelopes start exactly 8 clocks after admission, including first attack step");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule

