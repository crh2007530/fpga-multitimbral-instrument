`timescale 1ns/1ps
`include "tb/ws2812_monitor.v"
`include "tb/reference_ws2812.v"
module tb_v21_leds;
reg clk=0;always #10 clk=~clk;reg rst=0,guide=0;
reg[7:0]pressure=0,prox=0,target=0,pressed=0,next=0;reg[5:0]events=0;
wire dout,oldout;wire[719:0]pixels,oldpixels;wire[31:0]frames,oldframes;
ws2812_joint_driver #(.TRAINER(1)) dut(guide,1'b1,1'b0,1'b0,1'b1,target,next,pressed,8'd2,8'd3,clk,rst,
pressure,pressure,pressure,pressure,pressure,pressure,pressure,pressure,events,prox,1'b0,3'd0,8'd0,dout);
reference_ws2812_joint_driver #(.TRAINER(1)) refdut(guide,1'b1,1'b0,1'b0,1'b1,target,next,pressed,8'd2,8'd3,clk,rst,
pressure,pressure,pressure,pressure,pressure,pressure,pressure,pressure,events,prox,oldout);
ws2812_monitor mon(dout,pixels,frames),refmon(oldout,oldpixels,oldframes);
integer i,j,f;reg[7:0]bri;
task settle;begin f=frames;wait(frames>=f+3 && oldframes>=f+3);#1;end endtask
initial begin
 #100;rst=1;
 for(j=0;j<4;j=j+1)begin
 pressure=j==0?0:j==1?10:j==2?80:255;events=6'b010101;prox=pressure;
 settle();bri=pressure>10?pressure:0;
 for(i=0;i<30;i=i+1)begin
  if(i<18 || i>=24)begin if(pixels[i*24+:24]!==oldpixels[i*24+:24])$fatal(1,"unchanged light %d",i);end
  else if(i<21)begin if(pixels[i*24+:24]!=={(bri>>2),bri,8'd0})$fatal(1,"orange %d",i);end
  else if(pixels[i*24+:24]!=={8'd0,(bri>>2),bri})$fatal(1,"purple %d",i);
 end
 end
 guide=1;target=8'h81;pressed=8'hc1;next=8'h20;settle();
 if(pixels!==oldpixels)$fatal(1,"teaching/gesture override changed");
 guide=0;events=6'b101010;settle();
 if(pixels[719:576]!==oldpixels[719:576])$fatal(1,"gesture changed");
 $display("PASS actual WS2812 wire decode: 30 pixels, orange 19-21 / purple 22-24, brightness/deadzone, other24 pixels and all teaching behavior identical to V20");$finish;
end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
