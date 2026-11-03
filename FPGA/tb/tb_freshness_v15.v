`timescale 1ns/1ps
module tb_freshness_v15;
reg clk=0;always #10 clk=~clk;
wire s0,d0,s1,d1,os,od,gs,gd;pullup(s0,d0,s1,d1,os,od,gs,gd);
pressure_poly8_top dut(.clk_50m(clk),.volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(1'b1),.encoder_b(1'b1),.bt_rx(1'b1),
 .ttp_sdo(1'b1),.adc0_scl(s0),.adc0_sda(d0),.adc1_scl(s1),.adc1_sda(d1),
 .oled_scl(os),.oled_sda(od),.apds_scl(gs),.apds_sda(gd));
reg[31:0] now_us=0;reg[255:0] stamps=0;reg[7:0] seen=0;
reg[31:0] ages[0:7];reg[7:0] previous_seen=0,expected=0;
integer i,j,seed=8921;
initial begin
 force dut.time_us=now_us;force dut.stamps=stamps;force dut.seen=seen;
 for(j=0;j<8;j=j+1)ages[j]=0;
 wait(dut.rst_n);repeat(4)@(negedge clk);
 for(i=0;i<2048;i=i+1)begin
  @(negedge clk);
  now_us=$random(seed);seen=$random(seed);
  for(j=0;j<8;j=j+1)begin
   case((i+j)%4)
    0:stamps[j*32+:32]=now_us-32'd10000;
    1:stamps[j*32+:32]=now_us-32'd10001;
    2:stamps[j*32+:32]=now_us-32'd1;
    3:stamps[j*32+:32]=now_us-32'd20000;
   endcase
  end
  @(posedge clk);
  for(j=0;j<8;j=j+1)begin
   expected[j]=previous_seen[j] && ages[j]>10000;
   ages[j]=now_us-stamps[j*32+:32];
  end
  previous_seen=seen;
  #1;if(dut.stale!==expected)$fatal(1,"freshness mismatch actual=%h expected=%h",dut.stale,expected);
 end
 $display("PASS 16384 freshness decisions: threshold 10000/10001us, unseen channels, unsigned timer wrap, exact registered latency");
 $finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
