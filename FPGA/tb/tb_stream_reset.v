`timescale 1ns/1ps
module tb_stream_reset;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,sample_valid=0;reg signed[15:0] sample_pcm=0;
 wire busy,bin_valid,frame_done;wire[9:0] bin_index;wire signed[23:0] bin_real,bin_imag;
 wire[31:0] frame_count,missed_windows;
 stream_spectrum2048 dut(.*);
 integer trial,n,delay_cycles,checked=0,frame_bins=0;reg verify_zero=0;
 always @(posedge clk)if(rst_n && verify_zero && bin_valid)begin
  if({bin_real,bin_imag}!==48'd0 || bin_index!==frame_bins%1024)$fatal(1,"stale frame survived reset");
  checked=checked+1;frame_bins=frame_bins+1;
 end
 task feed;input integer nonzero;begin
  for(n=0;n<2048;n=n+1)begin
   @(negedge clk);sample_valid=1;sample_pcm=nonzero?(n*37+123):0;
   @(negedge clk);sample_valid=0;repeat(2)@(negedge clk);
  end
 end endtask
 initial begin
  for(trial=0;trial<8;trial=trial+1)begin
   verify_zero=0;rst_n=0;repeat(3)@(negedge clk);rst_n=1;
   feed(1);
   case(trial)0:delay_cycles=0;1:delay_cycles=1;2:delay_cycles=2047;3:delay_cycles=2050;
    4:delay_cycles=2052;5:delay_cycles=50000;6:delay_cycles=105000;default:delay_cycles=106499;endcase
   repeat(delay_cycles)@(negedge clk);
   #2;rst_n=0;#3;repeat(3)@(negedge clk);rst_n=1;verify_zero=1;frame_bins=0;
   feed(0);wait(frame_done);repeat(4)@(negedge clk);
   if(frame_bins!=1024 || frame_count!=1 || missed_windows!=0 || busy)$fatal(1,"reset recovery accounting");
  end
  $display("PASS %0d zero bins after 8 asynchronous resets during loading, multiply pipeline, FFT compute and output; no stale frame publication",checked);$finish;
 end
 initial begin #30000000;$fatal(1,"timeout");end
endmodule
