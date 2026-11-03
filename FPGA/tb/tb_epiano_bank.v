`timescale 1ns/1ps
module tb_epiano_bank;
 reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,sine=0,piano=0,diag=0;
 reg[639:0] addr=0;reg[1023:0] forcebus=0,envbus=0;wire[1023:0] samples;wire valid;
 reg signed[15:0] bright[0:1023],sinrom[0:1023],expected[0:63];
 reg[31:0] rng=32'h8123fedc,gain;reg signed[63:0] product;
 reg signed[15:0] presets[0:2047];integer i,n,age,ri,shift;reg signed[63:0] history[0:63];
 reg[22:0] noise_ref[0:7];integer noise_signed,ex;reg signed[63:0] damped;
 shared_voice_bank #(.VOICES(64),.GROUP(8),.THIRD_TIMBRE(1)) dut(.diagnostic_mode(diag),.epiano_mode(piano),.clk(clk),.rst_n(rst),.sample_ce(ce),.sine_mode(sine),.addresses(addr),.forces(forcebus),.envelopes(envbus),.samples(samples),.valid(valid));
 initial begin
 $readmemh("assets/harmonica_1024_16.hex",bright);$readmemh("assets/sine_1024_16.hex",sinrom);
 $readmemh("assets/instruments_2048_16.hex",presets);
 for(i=0;i<8;i=i+1)noise_ref[i]=23'h5a691d^(i*23'h12345);
 for(i=0;i<64;i=i+1)history[i]=0;repeat(3)@(negedge clk);rst=1;
 for(n=0;n<1000;n=n+1)begin
  @(negedge clk);sine=(n%4)==1 || (n%4)==3;piano=(n%4)==2;diag=(n%4)==3;
  for(i=0;i<64;i=i+1)begin
   rng=(rng<<1)^(rng[31]?32'h04c11db7:0);addr[i*10+:10]=rng[9:0];
   forcebus[i*16+:16]={1'b0,rng[30:16]};envbus[i*16+:16]={1'b0,rng[15:1]};
   gain=forcebus[i*16+:16]*envbus[i*16+:16];
   ri=diag?addr[i*10+:10]:piano?1536+(addr[i*10+:10]>>1):sine?1280+(addr[i*10+:10]>>2):1024+(addr[i*10+:10]>>2);
   product=$signed(presets[ri]);
   shift=envbus[i*16+:16]>=24576?0:envbus[i*16+:16]>=16384?1:2;
   if(piano)product=history[i]+((product-history[i])>>>shift);
   history[i]=product;
   noise_signed=$signed(noise_ref[i/8][22:7]);
   ex=diag?0:piano?((envbus[i*16+:16]>30000)?(noise_signed>>>6):0):sine?((envbus[i*16+:16]<8192)?(noise_signed>>>5):(noise_signed>>>7)):(noise_signed>>>9);
   noise_ref[i/8]={noise_ref[i/8][21:0],noise_ref[i/8][22]^noise_ref[i/8][17]};
   product=product+ex;if(product>32767)product=32767;if(product< -32768)product= -32768;
   product=product*$signed({1'b0,gain[30:15]});expected[i]=product>>>(piano?16:17);
  end
  ce=1;@(negedge clk);ce=0;age=1;
  while(!valid && age<24)begin @(negedge clk);age=age+1;end
  if(!valid || age!=13)$fatal(1,"bank publication %d",age);
  for(i=0;i<64;i=i+1)if(samples[i*16+:16]!==expected[i])$fatal(1,"bank lane mismatch frame %d voice %d",n,i);
  repeat(8)@(negedge clk);
 end
 $display("PASS 64000 randomized bank samples: 64 lane isolation, independent timbres with per-voice piano damping, signed gain and fixed 13-cycle publication");$finish;
 end
endmodule

