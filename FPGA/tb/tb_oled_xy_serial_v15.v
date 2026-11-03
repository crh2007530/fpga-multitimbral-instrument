`timescale 1ns/1ps
module tb_oled_xy_serial_v15;
reg clk=0;always #5 clk=~clk;
reg rst=0;wire sda;pullup(sda);
oled_status #(.EXTENDED(1),.EXPANSION(1),.EXPRESSION(1),.WAVEFORM(1),.TRAINER(1),.POWERUP_MS(100)) dut(
 .clk(clk),.rst_n(rst),.trainer_status(40'd0),.trainer_target(8'd0),.trainer_next(8'd0),
 .visual_mode(2'd2),.spectrum_bars(75'd0),.wave_points(320'd0),.expression_config(4'd0),
 .octave(2'd0),.keys(11'd0),.history(112'd0),.history_valid(4'd0),.event_count(16'd0),
 .sda(sda),.voice_modes(16'd0),.selected(4'd0),.test_mask(4'd0),.test_mode(1'b0),
 .chord_mode(1'b0),.test32(1'b0),.selected_test(6'd0),.mask32(64'd0));
reg[319:0] points;reg[7:0] expected;
integer scenario,page,x,i,cycles,checked=0,seed=13579;
initial begin
 repeat(4)@(negedge clk);rst=1;
 for(scenario=0;scenario<12;scenario=scenario+1)begin
  for(i=0;i<64;i=i+1)begin
   case(scenario)
    0:points[i*5+:5]=16;
    1:points[i*5+:5]=i;
    2:points[i*5+:5]=i%2?31:0;
    default:points[i*5+:5]=$random(seed);
   endcase
  end
  for(page=4;page<8;page=page+1)for(x=0;x<128;x=x+1)begin
   expected=0;
   for(i=0;i<60;i=i+1)
    if(x/4==points[i*5+:5] && points[(i+4)*5+:5]/8==page-4)
     expected[points[(i+4)*5+:5]%8]=1;
   @(negedge clk);
   dut.frame_wave=points;dut.frame_history=0;dut.frame_history[69:68]=2;
   dut.page=page;dut.byte_index=x+2;dut.segment=2;dut.state=10;
   cycles=0;
   @(negedge clk);
   while(dut.state!=4)begin
    @(negedge clk);cycles=cycles+1;
    if(cycles>70)$fatal(1,"OLED byte deadline");
   end
   if(dut.tx_data!==expected)$fatal(1,"XY mismatch scenario=%0d page=%0d x=%0d got=%h expected=%h",scenario,page,x,dut.tx_data,expected);
   if(dut.frame_wave!==points)$fatal(1,"source waveform not restored");
   checked=checked+1;
  end
 end
 $display("PASS OLED XY serial raster: %0d actual transmitted bytes equal original 60-point raster, silence/ramp/extremes/random, <=70 preparation clocks, source buffer restored",checked);
 $finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
