`timescale 1ns/1ps
module tb_custom_chart_v14;
 reg clk=0;always #5 clk=~clk;reg rst=0,rv=0,rt=0;reg[7:0] rk=0,pressed=0;
 reg[255:0] chart={32{8'h81}};wire active,running,done;wire[7:0] target,next_target;wire[127:0] data;
 rhythm_game #(.CLOCK_HZ(1000),.CUSTOM_CHART(1)) dut(.clk(clk),.rst_n(rst),.remote_valid(rv),.remote_toggle(rt),.remote_keys(rk),.local_inhibit(1'b0),
 .frame_valid(1'b0),.test_mode(1'b0),.keys(8'd0),.pressed(pressed),.active(active),.running(running),.done(done),.game_data(data),.target(target),.next_target(next_target),.user_chart(chart),.chart_enabled(1'b1));
 task command;input[7:0] key;begin @(negedge clk);rk=key;rv=1;@(negedge clk);rv=0;rk=0;end endtask
 integer i;
 initial begin repeat(3)@(negedge clk);rst=1;rt=1;@(negedge clk);rt=0;command(8'h10);
  for(i=0;i<32;i=i+1)begin wait(dut.time_ms==2000+i*500);@(negedge clk);
   if(target!=8'h81 || (i==31 && next_target!=0))$fatal(1,"custom target or final next");
   pressed=8'h81;@(negedge clk);pressed=0;
  end
  repeat(3)@(negedge clk);
  if(!done || dut.perfect!=64 || dut.points!=64000 || dut.max_combo!=64 || dut.misses!=0)$fatal(1,"max supported chart scoring");
  command(8'h20);command(8'h10);wait(done);
  if(dut.misses!=64 || dut.points!=0)$fatal(1,"custom misses");
  $display("PASS custom chart max64 notes: all perfect 64000 score, 64 combo, last lookahead zero; all missed 64; no counter wrap");$finish;
 end
endmodule
