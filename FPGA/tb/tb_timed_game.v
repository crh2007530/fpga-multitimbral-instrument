`timescale 1ns/1ps
module tb_timed_game;
reg clk=0;always #5 clk=~clk;reg rst=0,rv=0,rt=0;reg[7:0] rk=0,pressed=0;
wire active,running,done;wire[9:0] pos;wire signed[17:0] delta;wire[127:0] data;wire[7:0] target,hits,misses;
reg[10:0] count=1024;reg[23:0] events[0:1023];reg[39:0] masks;reg[79:0] durations;integer j;
always @*begin masks=0;durations=0;for(j=0;j<5;j=j+1)if(pos+j<count)begin masks[j*8+:8]=events[pos+j][7:0];durations[j*16+:16]=events[pos+j][23:8];end end
rhythm_game #(.CLOCK_HZ(1000),.TIMED_CHART(1)) dut(.clk(clk),.rst_n(rst),.frame_valid(1'b0),.keys(8'd0),.pressed(pressed),.test_mode(1'b0),.local_inhibit(1'b0),.remote_valid(rv),.remote_toggle(rt),.remote_keys(rk),.active(active),.running(running),.done(done),.target(target),.hits(hits),.misses(misses),.game_data(data),.timed_enabled(1'b1),.timed_count(count),.timed_masks(masks),.timed_durations(durations),.timed_ready(1'b1),.timed_position(pos),.due_delta(delta));
task command;input[7:0] key;begin @(negedge clk);rk=key;rv=1;@(negedge clk);rv=0;rk=0;end endtask
integer i,cycles=0,last_tick,expected_tick,total=0;reg[15:0] frozen;
always @(posedge clk)if(running)cycles=cycles+1;
initial begin
for(i=0;i<1024;i=i+1)events[i]={16'd20,8'd1};
events[0]={16'd250,8'd1};events[1]={16'd750,8'd0};events[2]={16'd60000,8'd3};events[3]={16'd500,8'd4};
repeat(4)@(negedge clk);rst=1;@(negedge clk);rt=1;@(negedge clk);rt=0;command(8'h10);
for(i=0;i<1024;i=i+1)begin
 wait(pos==i);wait(delta<=0);@(negedge clk);
 if(i==0)last_tick=cycles;
 else begin
 expected_tick=last_tick+events[i-1][23:8];
 if(cycles<expected_tick-1 || cycles>expected_tick+1)$fatal(1,"onset drift at %d got=%d expected=%d",i,cycles,expected_tick);
 last_tick=cycles;
 end
 if(i==3)begin command(8'h10);frozen=dut.time_ms;repeat(100)@(negedge clk);if(dut.time_ms!=frozen)$fatal(1,"pause");command(8'h10);last_tick=cycles;end
 pressed=events[i][7:0];if(pressed!=0)total=total+ (pressed==3?2:1);
 @(negedge clk);pressed=0;
 if(i!=1023)wait(pos!=i);else wait(done);
end
if(hits!=255 || misses!=0 || dut.points!=65535 || dut.max_combo!=255)$fatal(1,"saturation hits=%d missed=%d score=%d combo=%d",hits,misses,dut.points,dut.max_combo);
if(running || !done || pos!=1023)$fatal(1,"last event");
command(8'h10);if(pos!=0||done||!running)$fatal(1,"restart");
$display("PASS 1024-event game: varied 20/250/500/750/60000ms, rest, chord, 60s overflow boundary, exact onset schedule, pause/resume, score saturation, last/restart");$finish;
end
initial begin #5000000;$fatal(1,"timeout pos=%d delta=%d",pos,delta);end
endmodule
