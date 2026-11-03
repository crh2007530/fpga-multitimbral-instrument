`timescale 1ns/1ps
// Continuous 4096-sample history + fast snapshot load into the proven FFT.
// Native input: 50MHz/48046.875Hz, about 1040 clocks/sample.
// A 2048-sample snapshot is loaded in 2052 clocks; the 4096-entry ring
// protects it until 2048 newer samples arrive. HOP controls overlap only.
// No backpressure to audio. An overloaded frame request is counted explicitly.
module stream_spectrum2048 #(parameter integer HOP=512,WINDOW=1)(
 input wire clk,rst_n,sample_valid,input wire signed[15:0] sample_pcm,
 output wire busy,bin_valid,output wire[9:0] bin_index,
 output wire signed[23:0] bin_real,bin_imag,output wire frame_done,
 output reg[31:0] frame_count,missed_windows);
 reg signed[15:0] history[0:4095];
 reg[15:0] window_rom[0:2047];
 initial $readmemh("assets/hann2048.hex",window_rom);
 reg[11:0] wrptr,rdptr;reg[11:0] filled;
 localparam HW=(HOP>1)?$clog2(HOP):1;
 reg[HW-1:0] hop_count;
 reg active,loading;reg[10:0] load_index;
 reg signed[15:0] sample_q;reg[15:0] coefficient_q;
 reg signed[32:0] product;
 reg[2:0] pipe;reg signed[15:0] feed_pcm;
 wire core_busy;wire[31:0] core_skipped;
 wire request=sample_valid && (filled==2047 || (filled==2048 && hop_count==HOP-1));
 assign busy=active;
 fft2048 core(.clk(clk),.rst_n(rst_n),.sample_valid(pipe[2]),.sample_pcm(feed_pcm),
  .busy(core_busy),.bin_valid(bin_valid),.bin_index(bin_index),.bin_real(bin_real),
  .bin_imag(bin_imag),.frame_done(frame_done),.skipped_samples(core_skipped));
 always @(posedge clk)begin
  if(rst_n && sample_valid)history[wrptr]<=sample_pcm;
  if(loading)begin sample_q<=history[rdptr];coefficient_q<=window_rom[load_index];end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  wrptr<=0;rdptr<=0;filled<=0;hop_count<=0;active<=0;loading<=0;load_index<=0;
  product<=0;pipe<=0;feed_pcm<=0;frame_count<=0;missed_windows<=0;
 end else begin
  pipe<={pipe[1:0],loading};
  if(pipe[0])product<=WINDOW ? $signed(sample_q)*$signed({1'b0,coefficient_q}) : $signed(sample_q)*33'sd32768;
  // Q15 -> signed PCM16. The omitted high bits are sign extension because
  // 0<=window<=32767; this is the explicit bit selection of the scaled value.
  if(pipe[1])feed_pcm<=product[30:15];
  if(sample_valid)begin
   wrptr<=wrptr+1'b1;
   if(filled<2048)filled<=filled+1'b1;
   if(filled==2047 || request)hop_count<=0;
   else if(filled==2048)hop_count<=hop_count+1'b1;
  end
  if(frame_done)begin active<=0;if(frame_count!=32'hffffffff)frame_count<=frame_count+1'b1;end
  if(request)begin
   if(active)begin if(missed_windows!=32'hffffffff)missed_windows<=missed_windows+1'b1;end
   else begin active<=1;loading<=1;rdptr<=wrptr-12'd2047;load_index<=0;end
  end
  if(loading)begin
   rdptr<=rdptr+1'b1;load_index<=load_index+1'b1;
   if(load_index==2047)loading<=0;
  end
 end
endmodule
