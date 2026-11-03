`timescale 1ns/1ps
module tb_midi_keymap_v14;
 reg clk=0;always #5 clk=~clk;reg rst=0,start=0;reg[55:0] map=0;reg[15:0] modes=0;
 wire valid,busy,overrun;wire[4:0] index;wire[31:0] increment;
 shared_pitch_engine #(.CUSTOM_MAP(1)) dut(.clk(clk),.rst_n(rst),.sample_ce(start),.glide(1'b0),.vibrato(1'b0),
 .targets(1024'd0),.lfo(5'sd0),.valid(valid),.index(index),.increment(increment),.busy(busy),.overrun(overrun),.map_enabled(1'b1),.keymap(map),.modes(modes));
 reg[31:0] expected[0:127];integer n,i,m,t,cycles,received;
 initial begin
  $readmemh("assets/midi_inc_128.hex",expected);repeat(3)@(negedge clk);rst=1;
  for(m=0;m<3;m=m+1)for(n=0;n<128;n=n+1)begin
   for(i=0;i<8;i=i+1)begin map[i*7+:7]=(n+i)%128;modes[i*2+:2]=m;end
   start=1;@(negedge clk);start=0;cycles=0;received=0;
   // Mid-batch source changes must not leak through the coherent snapshot.
   map=~map;modes=~modes;
   while(received<32)begin
    @(negedge clk);cycles=cycles+1;if(cycles>40)$fatal(1,"batch deadline");
    if(valid)begin
     i=received;t=(n+(i%8))%128;case(i/8)1:t=t+4;2:t=t+7;3:t=t+12;endcase
     if(m==1)t=t-12;if(m==2)t=t+12;if(t<0)t=0;if(t>127)t=127;
     if(index!=i || increment!==expected[t])$fatal(1,"MIDI map n=%d mode=%d voice=%d",n,m,i);
     received=received+1;
    end
   end
   if(overrun)$fatal(1,"overrun");@(negedge clk);
  end
  $display("PASS shared MIDI pipeline: 128 notes x3 octaves x32 voices; clamps, frame-atomic snapshot despite mid-batch edits; <=40 clocks");$finish;
 end
endmodule
