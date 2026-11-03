`timescale 1ns/1ps
// Block spectrum, 2048 contiguous PCM samples, followed by computation.
// Samples during busy are deliberately skipped and counted. This block never
// back-pressures audio. FFT is scaled 1/N; input has 8 fractional guard bits.
// Rectangular window; complex outputs in natural order, positive bins 0..1023.
module fft2048(input wire clk,rst_n,sample_valid,
 input wire signed [15:0] sample_pcm,
 output wire busy,output reg bin_valid,output reg [9:0] bin_index,
 output reg signed [23:0] bin_real,bin_imag,
 output reg frame_done,output reg [31:0] skipped_samples);
 reg [47:0] mem[0:2047];
 reg [31:0] twiddle[0:1023];
 initial $readmemh("assets/twiddle2048.hex",twiddle);
 reg [3:0] state;
 reg [10:0] capture_index,base,j,halfsize,read_addr,write_addr;
 reg [10:0] step;reg [9:0] twaddr;
 reg [47:0] read_q,write_data;
 reg write_en;
 reg signed [23:0] ar,ai,br,bi;
 reg signed [15:0] wr,wi;
 reg signed [39:0] p0,p1,p2,p3;
 reg signed [40:0] tr,ti;
 wire [21:0] twproduct=j*step;
 function [10:0] reverse11;input [10:0] x;integer n;
 begin for(n=0;n<11;n=n+1)reverse11[n]=x[10-n];end endfunction
 assign busy=state!=0;
 // Separate synchronous read/write template, no RAM reset.
 always @(posedge clk)begin
  read_q<=mem[read_addr];
  if(write_en)mem[write_addr]<=write_data;
 end
 wire signed [41:0] sumr=($signed(ar)+ (tr>>>15));
 wire signed [41:0] sumi=($signed(ai)+ (ti>>>15));
 wire signed [41:0] diffr=($signed(ar)- (tr>>>15));
 wire signed [41:0] diffi=($signed(ai)- (ti>>>15));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  state<=0;capture_index<=0;base<=0;j<=0;halfsize<=1;step<=1024;
  read_addr<=0;write_addr<=0;write_data<=0;write_en<=0;twaddr<=0;
  ar<=0;ai<=0;br<=0;bi<=0;wr<=0;wi<=0;p0<=0;p1<=0;p2<=0;p3<=0;tr<=0;ti<=0;
  bin_valid<=0;bin_index<=0;bin_real<=0;bin_imag<=0;frame_done<=0;skipped_samples<=0;
 end else begin
  write_en<=0;bin_valid<=0;frame_done<=0;
  if(busy && sample_valid && skipped_samples!=32'hffffffff)skipped_samples<=skipped_samples+1'b1;
  case(state)
   0:if(sample_valid)begin
    write_en<=1;write_addr<=reverse11(capture_index);write_data<={sample_pcm,8'b0,24'b0};
    capture_index<=capture_index+1'b1;
    if(capture_index==2047)begin base<=0;j<=0;halfsize<=1;step<=1024;state<=1;end
   end
   1:begin read_addr<=base+j;twaddr<=twproduct[9:0];state<=2;end
   2:begin read_addr<=base+j+halfsize;{wr,wi}<=twiddle[twaddr];state<=3;end
   3:begin {ar,ai}<=read_q;state<=4;end
   4:begin {br,bi}<=read_q;state<=5;end
   5:begin p0<=br*wr;p1<=bi*wi;p2<=br*wi;p3<=bi*wr;state<=6;end
   6:begin tr<=$signed(p0)-$signed(p1);ti<=$signed(p2)+$signed(p3);state<=7;end
   7:begin write_en<=1;write_addr<=base+j;write_data<={sumr[24:1],sumi[24:1]};state<=8;end
   8:begin write_en<=1;write_addr<=base+j+halfsize;write_data<={diffr[24:1],diffi[24:1]};state<=9;end
   9:begin
    if(j+1<halfsize)begin j<=j+1'b1;state<=1;end
    else if({1'b0,base}+({1'b0,halfsize}<<1)<2048)begin base<=base+(halfsize<<1);j<=0;state<=1;end
    else if(halfsize<1024)begin halfsize<=halfsize<<1;step<=step>>1;base<=0;j<=0;state<=1;end
    else begin bin_index<=0;read_addr<=0;state<=10;end
   end
   10:state<=11;
   11:begin {bin_real,bin_imag}<=read_q;bin_valid<=1;state<=12;end
   12:if(bin_index==1023)begin frame_done<=1;state<=0;end
      else begin bin_index<=bin_index+1'b1;read_addr<=bin_index+1'b1;state<=10;end
  endcase
 end
endmodule
