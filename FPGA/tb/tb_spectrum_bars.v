`timescale 1ns/1ps
module tb_spectrum_bars;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,d=0;reg[9:0] idx=0;reg signed[23:0] re=0,im=0;
 wire[74:0] bars;wire updated;reg[74:0] expected;
 integer n,k,band,lev,mag,frame;reg[31:0] rng=32'h123abc98;
 spectrum2048_bars dut(.clk(clk),.rst_n(rst),.sample_valid(1'b0),.sample_pcm(16'd0),.bars(bars),.updated(updated));
 initial begin
  force dut.bv=v;force dut.done=d;force dut.bin=idx;force dut.re=re;force dut.im=im;
  repeat(5)@(negedge clk);rst=1;
  for(frame=0;frame<20;frame=frame+1)begin
   expected=0;
   for(n=0;n<1024;n=n+1)begin
    @(negedge clk);v=1;idx=n;rng=(rng<<1)^(rng[31]?32'h04c11db7:0);re=$signed(rng[23:0]);im=$signed(rng[31:8]);
    if(n<2)band=0;else if(n<3)band=1;else if(n<4)band=2;else if(n<6)band=3;
    else if(n<9)band=4;else if(n<13)band=5;else if(n<19)band=6;else if(n<28)band=7;
    else if(n<42)band=8;else if(n<63)band=9;else if(n<94)band=10;else if(n<140)band=11;
    else if(n<210)band=12;else if(n<315)band=13;else band=14;
    mag=(re<0?-re:re)+(im<0?-im:im);lev=0;
    for(k=8;k<24;k=k+1)if((mag>>k)&1)lev=(k-7)*2-1;
    if(mag>=16777216)lev=31;
    if(n!=0 && lev>expected[band*5+:5])expected[band*5+:5]=lev;
   end
   @(negedge clk);v=0;d=1;@(negedge clk);d=0;
   wait(updated);@(negedge clk);if(bars!==expected)$fatal(1,"bars differ");
  end
  $display("PASS 20 full-spectrum frames, DC exclusion, all band boundaries, atomic last-bin publication");$finish;
 end
endmodule
