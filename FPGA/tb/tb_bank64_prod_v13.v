`timescale 1ns/1ps
module tb_bank64_prod_v13;
 reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,sine=0;
 reg[639:0] addr=0;reg[1023:0] forcebus=0,envbus=0;wire[1023:0] samples;wire valid;
 reg signed[15:0] bright[0:1023],sinrom[0:1023],expected[0:63];
 reg[31:0] rng=32'h8123fedc,gain;reg signed[63:0] product;
 integer i,n,age;
 shared_voice_bank #(.VOICES(64),.GROUP(8)) dut(.diagnostic_mode(1'b0),.clk(clk),.rst_n(rst),.sample_ce(ce),.sine_mode(sine),.addresses(addr),.forces(forcebus),.envelopes(envbus),.samples(samples),.valid(valid));
 initial begin
 $readmemh("assets/bright_1024_16.hex",bright);$readmemh("assets/sine_1024_16.hex",sinrom);
 repeat(3)@(negedge clk);rst=1;
 for(n=0;n<1000;n=n+1)begin
  @(negedge clk);sine=n%2;
  for(i=0;i<64;i=i+1)begin
   rng=(rng<<1)^(rng[31]?32'h04c11db7:0);addr[i*10+:10]=rng[9:0];
   forcebus[i*16+:16]={1'b0,rng[30:16]};envbus[i*16+:16]={1'b0,rng[15:1]};
   gain=forcebus[i*16+:16]*envbus[i*16+:16];
   product=$signed(sine?sinrom[addr[i*10+:10]]:bright[addr[i*10+:10]]);
   product=product*$signed({1'b0,gain[30:15]});expected[i]=product>>>17;
  end
  ce=1;@(negedge clk);ce=0;age=1;
  while(!valid && age<24)begin @(negedge clk);age=age+1;end
  if(!valid || age!=13)$fatal(1,"bank publication %d",age);
  for(i=0;i<64;i=i+1)if(samples[i*16+:16]!==expected[i])$fatal(1,"bank lane mismatch frame %d voice %d",n,i);
  repeat(8)@(negedge clk);
 end
 $display("PASS 64000 randomized bank samples: 64 lane isolation, both waveforms, signed gain and fixed 13-cycle publication");$finish;
 end
endmodule
