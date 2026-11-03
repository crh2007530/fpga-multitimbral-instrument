`timescale 1ns/1ps
module tb_v21_panel;
reg clk=0;always #10 clk=~clk;reg rst=0,a=1,b=1,key=0;
wire[4:0]vol;wire[6:0]pct;wire click;integer clicks=0,i;
panel_controls #(.FILTER_CYCLES(3),.BUTTON_CYCLES(8)) dut(clk,rst,a,b,key,vol,pct,click);
reg test_mode=0,rv=0,rt=0;reg[7:0]rk=0;wire active,running;
rhythm_game #(.CLOCK_HZ(50000),.PHYSICAL_CONTROL(1)) game(.clk(clk),.rst_n(rst),
 .panel_click(click),.remote_valid(rv),.remote_toggle(rt),.remote_keys(rk),.local_inhibit(1'b0),
 .frame_valid(1'b0),.keys(8'd0),.pressed(8'd0),.test_mode(test_mode),.active(active),.running(running));
always @(posedge clk)if(click)clicks=clicks+1;
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task press;begin key=0;ticks(30);key=1;ticks(30);end endtask
task rotate(input integer reverse);begin
 {a,b}=reverse?2'b10:2'b01;ticks(15);{a,b}=0;ticks(15);
 {a,b}=reverse?2'b01:2'b10;ticks(15);{a,b}=3;ticks(15);
end endtask
initial begin
 ticks(4);rst=1;ticks(60);if(clicks || active || vol!=16)$fatal(1,"boot held key");
 key=1;ticks(30);
 key=0;ticks(2);key=1;ticks(30);if(clicks)$fatal(1,"bounce");
 press();if(!active || !running || clicks!=1)$fatal(1,"enter/start");
 key=0;ticks(50);if(running || clicks!=2)$fatal(1,"pause/long hold");
 key=1;ticks(2);key=0;ticks(50);if(clicks!=2)$fatal(1,"release bounce");
 key=1;ticks(30);press();if(!running || clicks!=3)$fatal(1,"resume");
 key=0;wait(click);rt=1;rv=1;rk=8'h10;@(negedge clk);rt=0;rv=0;key=1;ticks(30);
 if(!active || running)$fatal(1,"collision");
 for(i=0;i<20;i=i+1)rotate(0);
 if(vol!=0 || pct!=0)$fatal(1,"volume low clamp %d",vol);
 for(i=0;i<20;i=i+1)rotate(1);
 if(vol!=16 || pct!=100)$fatal(1,"volume high clamp %d",vol);
 test_mode=1;press();if(running)$fatal(1,"button altered test mode");
 $display("PASS panel: boot-held/release/press bounce, single hold event, enter start pause resume, remote collision, volume clamps, test-mode isolation");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
