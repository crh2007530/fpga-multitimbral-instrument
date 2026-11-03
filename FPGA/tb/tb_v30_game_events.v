`timescale 1ns/1ps
module tb_v30_game_events;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,rv=0,rt=0;reg[7:0] rk=0,pressed=0,keys=0;reg frame=0;
 wire active,running,done;wire[127:0] data;
 rhythm_game #(.CLOCK_HZ(1000)) dut(.clk(clk),.rst_n(rst),.remote_valid(rv),.remote_toggle(rt),.remote_keys(rk),.local_inhibit(1'b0),
 .frame_valid(frame),.test_mode(1'b0),.keys(keys),.pressed(pressed),.active(active),.running(running),.done(done),.game_data(data));
 task command;input[7:0] key;begin @(negedge clk);rk=key;rv=1;@(negedge clk);rv=0;rk=0;end endtask
 task restart;begin command(8'h20);command(8'h10);end endtask
 task hit_at;input integer t;input[7:0] mask;begin
 wait(dut.time_ms==t);@(negedge clk);pressed=mask;@(negedge clk);pressed=0;
 end endtask
 integer i,total,freeze;
 initial begin
 repeat(3)@(negedge clk);rst=1;
 // Local two-frame debounce + long touch7 entry.
 frame=1;keys=8'h40;repeat(1005)@(negedge clk);keys=0;repeat(5)@(negedge clk);frame=0;
 if(!active || running)$fatal(1,"local entry");
 command(8'h10);wait(dut.time_ms==2000);@(negedge clk);pressed=1;
 repeat(4)@(negedge clk);
 if(dut.position!=1 || dut.target!=1 || dut.light_target!=1 || dut.hits!=1)$fatal(1,"successful held note feedback lost on advance");
 repeat(50)@(negedge clk);
 if(dut.light_target!=1 || dut.hits!=1)$fatal(1,"held note re-scored or feedback lost");
 pressed=0;repeat(2)@(negedge clk);
 if(dut.light_target!=1)$fatal(1,"released feedback retained");
 pressed=4;repeat(2)@(negedge clk);
 if(dut.light_target[2] || dut.wrong!=1)$fatal(1,"wrong note received correct feedback");
 pressed=0;restart;
 hit_at(1950,1); // inclusive early 50 ms
 if(dut.led_event!=1 || dut.led_mask!=1 || dut.perfect!=1 || dut.points!=1000)$fatal(1,"early50");
 restart;hit_at(1949,1);if(dut.led_event!=2 || dut.good!=1)$fatal(1,"early51");
 restart;hit_at(1880,1);if(dut.good!=1)$fatal(1,"early120");
 restart;hit_at(1879,1);if(dut.led_event!=4 || dut.hits!=0 || dut.wrong!=1)$fatal(1,"early121");
 wait(dut.time_ms==2123);if(dut.misses!=1)$fatal(1,"miss");
 restart;hit_at(2050,1);if(dut.perfect!=1)$fatal(1,"late50");
 restart;hit_at(2051,1);if(dut.good!=1)$fatal(1,"late51");
 restart;hit_at(2120,1);if(dut.good!=1)$fatal(1,"late120");
 restart;hit_at(2121,1);if(dut.hits!=0 || dut.misses!=1)$fatal(1,"late121");
 restart;wait(dut.time_ms==1000);command(8'h10);freeze=dut.time_ms;
 pressed=1;repeat(200)@(negedge clk);
 if(dut.time_ms!=freeze || dut.hits!=0 || dut.wrong!=0)$fatal(1,"pause");
 command(8'h10);repeat(5)@(negedge clk);if(dut.hits!=0)$fatal(1,"held resume");pressed=0;
 restart;
 // Current built-in Twinkle: 42 attacks over 48 beats.
 for(i=0;i<42;i=i+1)hit_at(2000+dut.chart_beat(i)*500,dut.chart(i));
 repeat(3)@(negedge clk);
 if(!done || running || dut.perfect!=42 || dut.points!=42000 || dut.max_combo!=42 || dut.misses!=0)$fatal(1,"full chart %d %d %d",dut.perfect,dut.points,dut.max_combo);
 restart;wait(done);if(dut.misses!=42 || dut.points!=0)$fatal(1,"all misses");
 command(8'h80);if(active || running)$fatal(1,"exit");
 @(negedge clk);rt=1;@(negedge clk);rt=0;if(!active)$fatal(1,"remote entry");
 $display("PASS rhythm: held-success LED feedback until release, wrong note rejection, local entry, +/-50/120ms boundaries, no held scoring, pause/resume, 42 perfect Twinkle notes, 42 misses, reset/exit/remote");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
