`timescale 1ns/1ps
module tb_v21_gain;
reg clk=0,rst=0;reg signed[15:0]sample=0;reg[4:0]level=16;
wire signed[15:0]pcm;integer i,j,expected,base;
pcm_pressure_poly32 #(.MASTER_VOLUME(1)) dut(.clk(clk),.rst_n(rst),.master_volume(level),.monitor_pcm(pcm));
initial begin
 force dut.xsmt=1;force dut.fx_pcm=sample;
 for(i=0;i<=16;i=i+1)begin level=i;
 for(j=-32768;j<=32767;j=j+257)begin
  sample=j;#1;base=j*2;if(base>32767)base=32767;if(base< -32768)base=-32768;
  expected=(base*i)>>>4;
  if(pcm!==expected[15:0])$fatal(1,"gain %d sample %d result %d expected %d",i,j,pcm,expected);
 end
 end
 sample=-32768;level=31;#1;if(pcm!==16'sh8000)$fatal(1,"clamp");
 sample=32767;level=16;#1;if(pcm!==16'sh7fff)$fatal(1,"positive clip");
 sample=-1;level=0;#1;if(pcm!==0)$fatal(1,"mute");
 $display("PASS 17 gain levels across signed range, unity preserves V20 saturation, negative sign, no overflow, exact mute");$finish;
end
endmodule
