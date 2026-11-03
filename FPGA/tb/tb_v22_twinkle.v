`timescale 1ns/1ps
module tb_v22_twinkle;
reg clk=0;always #5 clk=~clk;reg rst=0,rv=0,rt=0,fv=0;reg[7:0] rk=0,keys=0,pressed=0;
wire active,running,done;wire[1:0] tempo;wire[7:0] target,hits,misses;wire[9:0] pos;wire signed[17:0] delta;wire[127:0] data;
rhythm_game #(.CLOCK_HZ(1000)) dut(.clk(clk),.rst_n(rst),.remote_valid(rv),.remote_toggle(rt),.remote_keys(rk),.local_inhibit(1'b0),.frame_valid(fv),.test_mode(1'b0),.keys(keys),.pressed(pressed),.active(active),.running(running),.done(done),.tempo(tempo),.target(target),.hits(hits),.misses(misses),.timed_position(pos),.due_delta(delta),.game_data(data),.timed_enabled(1'b0),.chart_enabled(1'b0));
reg[127:0] visual;wire[23:0] rgb;
always @*begin visual=data;visual[103:102]=tempo;end
video_game_view view(.clk(clk),.rst_n(rst),.x(11'd0),.y(10'd0),.state(visual),.pressed(pressed),.magnitude(8'd0),.displacement(9'd0),.wave_visible(1'b0),.fft_visible(1'b0),.xy_visible(1'b0),.xy_dot(1'b0),.rgb(rgb),.chart_preview(40'd0),.chart_enabled(1'b0),.timed_enabled(1'b0),.timed_deltas(80'd0));
task cmd;input[7:0] k;begin @(negedge clk);rv=1;rk=k;@(negedge clk);rv=0;rk=0;end endtask
task touch;input[7:0] k;begin @(negedge clk);fv=1;keys=k;repeat(4)@(negedge clk);fv=0;end endtask
reg[7:0] melody[0:41];integer d,i,beat,quarter,expected_due,fall;
initial begin
melody[0]=8'h01;
melody[1]=8'h01;
melody[2]=8'h10;
melody[3]=8'h10;
melody[4]=8'h20;
melody[5]=8'h20;
melody[6]=8'h10;
melody[7]=8'h08;
melody[8]=8'h08;
melody[9]=8'h04;
melody[10]=8'h04;
melody[11]=8'h02;
melody[12]=8'h02;
melody[13]=8'h01;
melody[14]=8'h10;
melody[15]=8'h10;
melody[16]=8'h08;
melody[17]=8'h08;
melody[18]=8'h04;
melody[19]=8'h04;
melody[20]=8'h02;
melody[21]=8'h10;
melody[22]=8'h10;
melody[23]=8'h08;
melody[24]=8'h08;
melody[25]=8'h04;
melody[26]=8'h04;
melody[27]=8'h02;
melody[28]=8'h01;
melody[29]=8'h01;
melody[30]=8'h10;
melody[31]=8'h10;
melody[32]=8'h20;
melody[33]=8'h20;
melody[34]=8'h10;
melody[35]=8'h08;
melody[36]=8'h08;
melody[37]=8'h04;
melody[38]=8'h04;
melody[39]=8'h02;
melody[40]=8'h02;
melody[41]=8'h01;
repeat(4)@(negedge clk);rst=1;@(negedge clk);rt=1;@(negedge clk);rt=0;
if(tempo!=1 || !active || running)$fatal(1,"default ready");
cmd(16);wait(delta<=0);@(negedge clk);pressed=1;@(negedge clk);pressed=0;repeat(8)@(negedge clk);
if(dut.points!=1000 || !running)$fatal(1,"pre-switch score");
touch(4);repeat(5)@(negedge clk);
if(dut.points!=0 || running || dut.time_ms!=0 || tempo!=2 || pos!=0)$fatal(1,"mid-song speed reset");
for(d=0;d<3;d=d+1)begin
touch(0);touch(1<<d);repeat(5)@(negedge clk);
if(tempo!=d || running || pos!=0 || data[100])$fatal(1,"select ready");
cmd(16);if(!running)$fatal(1,"start");
// Held selector is accepted once, and cannot reset the game continuously.
fv=1;repeat(10)@(negedge clk);fv=0;keys=0;
if(!running || dut.time_ms==0)$fatal(1,"held selection retrigger");
quarter=d==0?1000:d==1?500:250;beat=0;
for(i=0;i<42;i=i+1)begin
wait(pos==i);repeat(8)@(negedge clk);
expected_due=2000+beat*quarter;
if(dut.due!=expected_due || target!=melody[i])$fatal(1,"melody/timing d=%d note=%d due=%d expected=%d target=%h",d,i,dut.due,expected_due,target);
if(view.due1[0]!=expected_due || view.mask1[0]!=melody[i])$fatal(1,"visual chart divergence");
// Freeze clock advancement to verify actual scroll conversion at each speed.
cmd(16);repeat(8)@(negedge clk);fall=(expected_due-dut.time_ms) >>> (d==0?3:d==1?2:1);
if(view.bottom3[0]!=608-fall)$fatal(1,"scroll speed d=%d bottom=%d",d,view.bottom3[0]);cmd(16);
wait(delta<=0);@(negedge clk);pressed=melody[i];@(negedge clk);pressed=0;
if(i<41)wait(pos==i+1);else wait(done);
beat=beat+((i%7)==6?2:1);
end
if(hits!=42 || misses!=0 || dut.points!=42000 || running || beat!=48)$fatal(1,"full song result");
end
cmd(128);if(active)$fatal(1,"exit");
$display("PASS Twinkle 42 notes/48 beats at 60/120/240 BPM; touch selection, held guard, onset/visual alignment, speed, pause/resume, full scoring, exit");$finish;
end
initial begin #3000000;$fatal(1,"timeout");end
endmodule
