`timescale 1ns/1ps
// 32-point rectangular-window DFT, positive bins 1..15, Fs/8 input.
// Two time-shared signed multipliers, 3 clocks per term, 1440 clocks per
// transform (<29 us at 50 MHz, below the 166 us decimated sample spacing).
// Display magnitude is |Re|+|Im| (not calibrated dB). No CPU/host transform.
module audio_spectrum(input wire clk,rst_n,sample_valid,
 input wire signed [15:0] sample_pcm,output reg [74:0] bars,output reg updated);
 reg signed [15:0] samples[0:31];
 reg signed [15:0] trig[0:31];
 initial $readmemh("assets/dft32_sin.hex",trig);
 reg [2:0] decimate;
 reg signed [18:0] average_sum;
 wire signed [18:0] average_next=average_sum+{{3{sample_pcm[15]}},sample_pcm};
 reg [4:0] write_index,index;
 reg [3:0] bin;
 reg [1:0] state;
 reg signed [15:0] value,sine,cosine;
 reg signed [31:0] product_r,product_i;
 reg signed [37:0] accum_r,accum_i;
 reg [74:0] pending_bars;
 wire [4:0] phase=index*bin;
 wire [4:0] cosine_phase=phase+5'd8;
 wire signed [37:0] total_r=accum_r+{{6{product_r[31]}},product_r};
 wire signed [37:0] total_i=accum_i+{{6{product_i[31]}},product_i};
 wire [37:0] abs_r=total_r[37] ? -total_r : total_r;
 wire [37:0] abs_i=total_i[37] ? -total_i : total_i;
 wire [38:0] magnitude={1'b0,abs_r}+{1'b0,abs_i};
 wire [4:0] height=(magnitude>>25)>31 ? 5'd31 : magnitude[29:25];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin average_sum<=0;decimate<=0;write_index<=0;index<=0;bin<=1;state<=0;
   bars<=0;pending_bars<=0;updated<=0;value<=0;sine<=0;cosine<=0;
   product_r<=0;product_i<=0;accum_r<=0;accum_i<=0;
 end else begin
   updated<=0;
   if(sample_valid)begin
     decimate<=decimate+1'b1;
     average_sum<=decimate==7 ? 19'sd0 : average_next;
     if(decimate==7 && state==0)begin
       samples[write_index]<=average_next>>>3;write_index<=write_index+1'b1;
       if(write_index==31)begin index<=0;bin<=1;accum_r<=0;accum_i<=0;state<=1;end
     end
   end
   case(state)
    1:begin value<=samples[index];sine<=trig[phase];cosine<=trig[cosine_phase];state<=2;end
    2:begin product_r<=value*cosine;product_i<=value*sine;state<=3;end
    3:begin
      if(index==31)begin
        pending_bars[(bin-1)*5+:5]<=height;
        index<=0;accum_r<=0;accum_i<=0;
        if(bin==15)begin bars<={height,pending_bars[69:0]};updated<=1;state<=0;end
        else begin bin<=bin+1'b1;state<=1;end
      end else begin accum_r<=total_r;accum_i<=total_i;index<=index+1'b1;state<=1;end
    end
   endcase
 end
endmodule
