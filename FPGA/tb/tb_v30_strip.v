`timescale 1ns/1ps
`include "tb/ws2812_monitor.v"
`include "tb/ws2812_joint_v28_reference.v"
module tb_v30_strip;
reg clk=0;always #10 clk=~clk;reg rst=0,active=0,practice=0;reg[2:0]ev=0;reg[7:0]p=0,mask=0;reg[5:0]gest=0;wire out,refout;wire[719:0]pixels;wire[31:0]frames;
ws2812_joint_driver #(.TRAINER(1),.GAME_FX(1)) dut(.practice_mode(practice),.clk(clk),.rst_n(rst),.guide_active(active),.guide_running(1'b1),.guide_done(1'b0),.guide_wait(1'b0),.guide_beat(1'b0),.guide_target(8'd1),.guide_next(8'd2),.guide_pressed(8'd0),.guide_misses(8'd0),.guide_wrong(8'd0),.p1(p),.p2(p),.p3(p),.p4(p),.p5(p),.p6(p),.p7(p),.p8(p),.events(gest),.prox(p),.led_event(ev),.led_mask(mask),.dout(out));
ws2812_joint_reference #(.TRAINER(1)) old(.clk(clk),.rst_n(rst),.guide_active(1'b0),.guide_running(1'b1),.guide_done(1'b0),.guide_wait(1'b0),.guide_beat(1'b0),.guide_target(8'd0),.guide_next(8'd0),.guide_pressed(8'd0),.guide_misses(8'd0),.guide_wrong(8'd0),.p1(p),.p2(p),.p3(p),.p4(p),.p5(p),.p6(p),.p7(p),.p8(p),.events(gest),.prox(p),.dout(refout));
ws2812_monitor mon(out,pixels,frames);reg compare=1;integer j;
always @(negedge clk)if(rst && compare && out!==refout)$fatal(1,"normal strip changed");
initial begin repeat(4)@(negedge clk);rst=1;p=80;gest=6'b010001;
wait(frames==2);@(negedge clk);p=160;gest=6'b101000;wait(frames==4);
compare=0;@(negedge clk);active=1;ev=4;@(negedge clk);ev=0;
wait(frames==6);#1;for(j=0;j<30;j=j+1)if(pixels[j*24+:24]!==24'h004000)$fatal(1,"red wire pixel %d",j);
// Freeze animation tick to check the actual serialized origin, not only its pixel evaluator.
force dut.game.fx.divider=0;
@(negedge clk);ev=1;mask=4;@(negedge clk);ev=0;mask=0;
wait(frames==8);#1;
for(j=0;j<30;j=j+1)if(pixels[j*24+:24] !== (j==7?24'h401040:24'h000008))$fatal(1,"wave origin wire pixel %d",j);
release dut.game.fx.divider;
@(negedge clk);active=0;wait(frames==10);#1;
if(pixels[18*24+:24]!==24'h28a000 || pixels[21*24+:24]!==24'h0028a0)$fatal(1,"normal orange purple restore");
if(pixels[26*24+:24]!==24'ha0a0a0)$fatal(1,"gesture proximity restore");
@(negedge clk);active=1;practice=1;wait(frames==12);#1;
if(pixels[0+:24]!==24'h000040 || pixels[3*24+:24]!==24'h080808 || pixels[4*24+:24]!==0)$fatal(1,"practice regional wire");
$display("PASS actual WS2812 pulse decode, all 30 error pixels, Z3 wave origin, practice target/next regional lights, normal bit-identical, pressure/gesture restore");$finish;
end
initial begin #20000000;$fatal(1,"timeout");end
endmodule
