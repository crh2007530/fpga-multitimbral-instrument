// Updated deadzone regression: inclusive ON=20, OFF=10.
`timescale 1ns/1ps
module tb_pressure_deadzone;
 reg clk=0; always #10 clk=~clk;
 reg [63:0] raw=0;
 reg [7:0] valid=255;
 tri1 a,b,c,d,scl,sda;
 pressure_poly8_top top(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),
 .adc1_scl(c),.adc1_sda(d),.oled_scl(scl),.oled_sda(sda),.ttp_sdo(1'b1));
 reg [7:0] expected=0;
 integer n,ch;
 task check;
 input [63:0] values;
 input [7:0] mask;
 begin
  @(negedge clk); raw=values;
  repeat(80) @(negedge clk);
  if(top.held_audio!==mask || top.pressure_held!==mask ||
     top.display_status.keys[7:0]!==mask || top.logger.pressed!==mask)
    $fatal(1,"gate/CDC/display/logger mismatch raw=%h expected=%h audio=%h visible=%h",raw,mask,top.held_audio,top.pressure_held);
 end endtask
 initial begin
  force top.raw=raw;force top.raw_valid=valid;
  #2000000;
  // Every idle value below 20 must stay OFF, including measured noise up to 19.
  for(n=0;n<20;n=n+1) check({8{n[7:0]}},0);
  check({8{8'd20}},255);
  for(n=19;n>10;n=n-1) check({8{n[7:0]}},255);
  check({8{8'd10}},0);
  check({8{8'd19}},0);
  check({8{8'd255}},255);
  check(0,0);
  for(ch=0;ch<8;ch=ch+1) begin
   @(negedge clk);raw[ch*8+:8]=20;expected[ch]=1;
   check(raw,expected);
  end
  for(ch=0;ch<8;ch=ch+1) begin
   @(negedge clk);raw[ch*8+:8]=11;
   check(raw,expected);
   @(negedge clk);raw[ch*8+:8]=10;expected[ch]=0;
   check(raw,expected);
   @(negedge clk);raw[ch*8+:8]=19;
   check(raw,expected);
  end
  check({8{8'd20}},255);
  @(negedge clk);valid=0;
  #11000000;
  if(top.held_audio!==0 || top.pressure_held!==0 || top.logger.pressed!==0)
   $fatal(1,"stale input did not release all visible/audio states");
  @(negedge clk);raw={8{8'd19}};valid=255;
  check({8{8'd19}},0);
  check({8{8'd20}},255);
  check(0,0);
  if(top.display_status.text_char(3,3,0,0,0,0,0)!="2" ||
     top.display_status.text_char(3,4,0,0,0,0,0)!="0") $fatal(1,"OLED threshold label");
  $display("PASS HYSTERESIS: idle 0..19 OFF, 20 ON, held 11..19 retained, 10 OFF, 255 ON, eight independent channels, ADC/audio CDC, OLED/UART gate agreement, stale release/reconnect");
  $finish;
 end
 initial begin #20000000;$fatal(1,"timeout");end
endmodule
