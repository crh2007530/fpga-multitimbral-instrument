`timescale 1ns/1ps
module tb_joint_lights;
reg clk=0;always #10 clk=~clk;
reg rst=0;reg [7:0] p1=64,p2=96;reg [5:0] events=0;
wire dout;
ws2812_joint_driver dut(.clk(clk),.rst_n(rst),.p1(p1),.p2(p2),.p3(8'd0),.p4(8'd0),.p5(8'd0),.p6(8'd0),.p7(8'd0),.p8(8'd0),.events(events),.prox(8'd32),.dout(dout));
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
 readframe();if(decoded[0]!==24'h004000||decoded[3]!==24'h600000)$fatal(1,"pressure colors");
 @(negedge clk);events=6'b010001;@(negedge clk);events=0;
 readframe();
 if(decoded[0]!==24'h004000||decoded[3]!==24'h600000||decoded[24]!==24'h004000||decoded[29]!==24'h400000)$fatal(1,"gesture cleared pressure");
 @(negedge clk);p1=0;events=6'b101000;@(negedge clk);events=0;
 readframe();
 if(decoded[0]!==0||decoded[3]!==24'h600000||decoded[28]!==24'h404000||decoded[29]!==24'h004040)$fatal(1,"release/gesture");
 $display("PASS physical LED serial decode: 30 GRB words, 20/40-cycle pulses, pressure persists across gestures, independent release, near/far indicators");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
