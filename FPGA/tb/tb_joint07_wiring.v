`timescale 1ns/1ps
// Fast wiring smoke test: real merged top, accelerated UART only.
// Inject control inputs; optical/I2C recognition is tested separately.
module tb_joint07_wiring;
 reg clk=0;always #10 clk=~clk;
 tri1 a,b,c,d,os,od,gs,gd;wire tx;
 pressure_poly8_top dut(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),
 .oled_scl(os),.oled_sda(od),.ttp_sdo(1'b1),.apds_scl(gs),.apds_sda(gd),.debug_tx(tx));
 defparam dut.logger.CLOCK_HZ=1000;
 defparam dut.logger.BAUD=100;
 reg [7:0] frame[0:159],v;integer i,j,sum;
 initial begin
  #2000000;
  force dut.raw=64'h8070605040302010;force dut.seen=255;force dut.stale=0;force dut.raw_valid=255;
  force dut.pitch_mode=2;force dut.touch_keys=4;
  force dut.u_gesture.sensor_ready=1;force dut.u_gesture.prox_valid=1;force dut.u_gesture.prox_data=123;
  repeat(80)@(negedge clk);
  force dut.u_gesture.swipe_up=1;force dut.u_gesture.near_detected=1;
  @(negedge clk);release dut.u_gesture.swipe_up;release dut.u_gesture.near_detected;
  repeat(80)@(negedge clk);
  force dut.count=1999999;@(negedge clk);release dut.count;
 end
 initial begin
  for(i=0;i<160;i=i+1)begin
   @(negedge tx);#100;
   for(j=0;j<8;j=j+1)begin #200;v[j]=tx;end
   #200;if(tx!==1)$fatal(1,"UART stop");frame[i]=v;
  end
  sum=0;for(i=0;i<158;i=i+1)sum=sum+frame[i];
  if({frame[159],frame[158]}!=(sum&65535))$fatal(1,"checksum");
  if(frame[2]!=3||frame[3]!=160||frame[10]!=254||frame[14]!=16||frame[21]!=128)$fatal(1,"pressure wiring");
  if(frame[58]!=2||frame[59]!=4||frame[60]!=1||frame[61]!=123||frame[62]!=1)$fatal(1,"touch/APDS wiring");
  if(frame[63]!=1||frame[64]!=1||frame[80]!=1||frame[108]!=17||frame[109]!=123)$fatal(1,"event queue wiring");
  $display("PASS MERGED TOP WIRING: physical UART decode, pressure raw/mask, high octave/touch3, APDS ready/proximity, simultaneous UP+NEAR timestamped event and cumulative counters");$finish;
 end
 initial begin #4000000;$fatal(1,"timeout");end
endmodule
