`timescale 1ns/1ps
module tb_stream_spectrum;
 parameter integer HOP=512,WINDOW=1,PERIOD=1040;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,sample_valid=0;reg signed[15:0] sample_pcm=0;
 wire busy,bin_valid,frame_done;wire[9:0] bin_index;
 wire signed[23:0] bin_real,bin_imag;wire[31:0] frame_count,missed_windows;
 stream_spectrum2048 #(.HOP(HOP),.WINDOW(WINDOW)) dut(.*);
 reg[15:0] inputs[0:8191];
 integer n,c,fd,cycle=0,last_start=0,accepted=0,bin_count=0,done_count=0,requests=0,first_index;
 initial begin
  fd=$fopen("checks/stream_trace.txt","w");$readmemh("stream_input.hex",inputs);
  repeat(5)@(negedge clk);rst_n=1;
  for(n=0;n<8192;n=n+1)begin
   sample_valid=1;sample_pcm=inputs[n];@(negedge clk);sample_valid=0;
   // Bounded timing jitter exercises concurrent ring writes and reads.
   repeat(PERIOD-1+(n%7)-3)@(negedge clk);
  end
  wait(!busy);repeat(10)@(negedge clk);
  if(bin_count!=accepted*1024 || done_count!=accepted || frame_count!=accepted)$fatal(1,"frame accounting");
  if(missed_windows!=requests-accepted)$fatal(1,"overload counter accounting");
  if(dut.core_skipped!=0)$fatal(1,"wrapper lost samples feeding FFT");
  if(HOP>=128 && missed_windows!=0)$fatal(1,"unexpected overload");
  if(HOP==64 && missed_windows==0)$fatal(1,"expected overload not detected");
  $fdisplay(fd,"END %0d %0d %0d",accepted,missed_windows,cycle);
  $fclose(fd);
  $display("PASS stream HOP=%0d WINDOW=%0d accepted=%0d missed=%0d bin_count=%0d",HOP,WINDOW,accepted,missed_windows,bin_count);$finish;
 end
 always @(posedge clk)begin
  cycle=cycle+1;
  if(rst_n)begin
   if(dut.request)begin
    requests=requests+1;
    if(!busy)begin
     first_index=n-2047;last_start=cycle;accepted=accepted+1;
     $fdisplay(fd,"START %0d %0d",first_index,cycle);
    end
   end
   if(bin_valid)begin
    if(bin_index!==bin_count%1024)$fatal(1,"bin order");
    $fdisplay(fd,"BIN %0d %h %h",bin_index,bin_real,bin_imag);bin_count=bin_count+1;
   end
   if(frame_done)begin
    done_count=done_count+1;
    if(cycle-last_start>108000)$fatal(1,"compute budget");
    $fdisplay(fd,"DONE %0d",cycle-last_start);
   end
  end
 end
 initial begin #150000000;$fatal(1,"stream timeout");end
endmodule
