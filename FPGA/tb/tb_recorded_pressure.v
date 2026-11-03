`timescale 1ns/1ps
// 66 idle capture (599 rows), then 99 single-pad capture (1308 rows).
// Rows replay every 1.6 us to check gate decisions, not physical timing/audio.
module tb_recorded_pressure;
 reg clk=0;always #10 clk=~clk;
 reg [63:0] raw=0;
 reg [71:0] samples[0:1906];
 tri1 a,b,c,d,scl,sda;
 pressure_poly8_top top(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),
 .adc1_scl(c),.adc1_sda(d),.oled_scl(scl),.oled_sda(sda),.ttp_sdo(1'b1));
 integer i;
 initial begin
  $readmemh("tb/recorded_pressure.hex",samples);
  force top.raw=raw;force top.raw_valid=8'hff;
  #2000000;
  for(i=0;i<1907;i=i+1) begin
   @(negedge clk);raw=samples[i][63:0];repeat(80) @(negedge clk);
   if(top.held_audio!==samples[i][71:64] || top.pressure_held!==samples[i][71:64] ||
      top.logger.pressed!==samples[i][71:64] || top.display_status.keys[7:0]!==samples[i][71:64])
    $fatal(1,"recorded pressure row %0d mismatch",i);
  end
  $display("PASS RECORDED INPUT: 1907 recorded snapshots match independent Schmitt reference; audio gate/OLED input/UART input agree. 66 idle has no triggers. 99 Z2 onset contains a real zero sample and can retrigger; stable holds remain continuous. Accelerated replay is not hardware/audio evidence.");
  $finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
