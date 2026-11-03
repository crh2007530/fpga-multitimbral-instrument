`timescale 1ns/1ps
module tb_exp4_lights;
reg clk=0;always #10 clk=~clk;
reg rst=0;reg [7:0] p1=64,p2=96;reg [5:0] events=0;
wire dout;
reg active=1,running=1,done=0,wait_mode=0,beat=1;reg[7:0] target=1,nextkey=2,pressed=0,misses=0,wrong=0;
ws2812_joint_driver #(.TRAINER(1)) dut(.guide_active(active),.guide_running(running),.guide_done(done),.guide_wait(wait_mode),.guide_beat(beat),.guide_target(target),.guide_next(nextkey),.guide_pressed(pressed),.guide_misses(misses),.guide_wrong(wrong),.clk(clk),.rst_n(rst),.p1(p1),.p2(p2),.p3(8'd0),.p4(8'd0),.p5(8'd0),.p6(8'd0),.p7(8'd0),.p8(8'd0),.events(events),.prox(8'd32),.dout(dout));
reg [23:0] decoded[0:29];reg [23:0] word;integer led,bitn,ticks,round;
task readframe;
begin
 wait(dut.state==2);@(negedge clk);
 for(led=0;led<30;led=led+1)begin
  word=0;
  for(bitn=0;bitn<24;bitn=bitn+1)begin
   @(posedge dout);ticks=0;while(dout)begin @(negedge clk);if(dout)ticks=ticks+1;end
   if(ticks!=20 && ticks!=40)$fatal(1,"WS2812 high pulse %d",ticks);
   word={word[22:0],ticks==40};
  end
  decoded[led]=word;
 end
end endtask
initial begin
 repeat(4)@(negedge clk);rst=1;
 readframe();if(decoded[0]!==24'h000040||decoded[1]!==24'h000040||decoded[3]!==24'h080808||decoded[4]!==0||decoded[24]!==24'h404040)$fatal(1,"target preview beat");
 @(negedge clk);pressed=5;beat=0;misses=1;wrong=1;
 readframe();if(decoded[0]!==24'h400000||decoded[6]!==24'h004000||decoded[24]!==0||decoded[28]!==24'h004000||decoded[29]!==24'h004000)$fatal(1,"correct wrong feedback");
 @(negedge clk);running=0;done=1;wait_mode=1;
 readframe();if(decoded[25]!==24'h204000||decoded[26]!==24'h200020||decoded[27]!==24'h400000)$fatal(1,"pause wait done");
 @(negedge clk);active=0;
 readframe();if(decoded[0]!==24'h004000||decoded[3]!==24'h600000||decoded[26]!==24'h202020)$fatal(1,"normal restored");
 $display("PASS trainer physical LED: blue target, next preview, green correct, red wrong, beat/pause/wait/done/miss, normal restore; 30 GRB words, 20/40-cycle pulses, pressure persists across gestures, independent release, near/far indicators");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
