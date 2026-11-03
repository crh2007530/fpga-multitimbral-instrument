`timescale 1ns/1ps
module tb_video_xy_capture;
 reg sc=0,pc=0;always #10 sc=~sc;always #7 pc=~pc;
 reg rst=0,valid=0,frame=0;reg signed[15:0] pcm=0;
 reg[13:0] address=0;wire dot,visible;
 video_xy_capture dut(sc,rst,valid,pcm,pc,rst,frame,address,dot,visible);
 integer i,j,x,y,shift_value,peak,v,cells,round;
 integer input_samples[0:1023];
 reg expected[0:16383];reg old_ack;
 function integer coord;
 input integer val,s;
 integer scaled;
 begin scaled=val>>>s;if(scaled>63)scaled=63;if(scaled< -63)scaled=-63;coord=64+scaled;end
 endfunction
 task pulse_frame;
 begin @(negedge pc);frame=1;@(negedge pc);frame=0;end
 endtask
 initial begin
  for(round=0;round<4;round=round+1)begin
   // Reset during different lifecycle states is exercised after each round.
   rst=0;valid=0;repeat(5+round)@(negedge sc);rst=1;
   for(j=0;j<2;j=j+1)begin
    wait(dut.state==0);
    peak=0;
    for(i=0;i<1024;i=i+1)begin
     case(round)
      0:v=$rtoi(12000.0*$sin(6.28318530718*i/128.0));
      1:v=0;
      2:v=i%2==0 ? -32768 : 32767;
      3:v=(i%128)-64;
     endcase
     if(j==1)v=-v/2;
     input_samples[i]=v;
     if(v<0)begin if(-v>peak)peak=-v;end else if(v>peak)peak=v;
     @(negedge sc);pcm=v;valid=1;
    end
    @(negedge sc);valid=0;
    shift_value=0;while((peak>>shift_value)>63 || peak>(63<<shift_value))shift_value=shift_value+1;
    for(i=0;i<16384;i=i+1)expected[i]=0;
    for(i=16;i<1024;i=i+1)begin
     x=coord(input_samples[i],shift_value);
     y=127-coord(input_samples[i-16],shift_value);
     expected[y*128+x]=1;
    end
    old_ack=dut.ack;wait(dut.state==6);repeat(10)@(negedge pc);
    if(dut.ack!==old_ack)$fatal(1,"bank changed outside frame");
    pulse_frame();repeat(4)@(negedge pc);
    if(!visible || dut.ack===old_ack)$fatal(1,"publish failed");
    cells=0;
    for(i=0;i<16384;i=i+1)begin
     @(negedge pc);address=i;
     @(negedge pc);
     if(dot!==expected[i])$fatal(1,"XY bitmap mismatch round=%0d bank=%0d index=%0d got=%b expected=%b",round,j,i,dot,expected[i]);
     if(dot)cells=cells+1;
    end
    $display("PASS XY round=%0d bank=%0d peak=%0d shift=%0d cells=%0d",round,j,peak,shift_value,cells);
   end
   // Interrupt capture, clear, and render, checking visible reset on restart.
   valid=1;repeat(1100+round*5500)@(negedge sc);
  end
  $display("PASS XY: exact all-pixel oracle, silence, full-scale, small signals, bank replacement and reset recovery");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
