`timescale 1ns/1ps
// Dry + fractional modulated delay. Triangle LFO ~1.47Hz, 10..11.32ms.
// Time-multiplexed synchronous reads allow one 1024x16 block RAM.
module send_chorus(input clk,rst_n,enable,input_valid,input clear,input[1:0] depth,rate,
 input signed[15:0] input_pcm,output reg output_valid,output reg signed[15:0] output_pcm);
 reg signed[15:0] mem[0:1023];reg signed[15:0] q,older,dry;
 reg[9:0] ptr,read_b,write_a;reg[10:0] filled;
 reg[14:0] phase;reg down,previous,en,history;
 reg[7:0] fraction;reg[2:0] pipe;
 wire[16:0] excursion=depth==0?{3'd0,phase[14:1]}:depth==1?{2'd0,phase}:{1'd0,phase,1'b0};
 wire[9:0] delay_samples=10'd480+{1'd0,excursion[16:8]};
 wire[14:0] phase_step=rate==0?15'd1:rate==1?15'd2:15'd4;
 wire[9:0] read_a=ptr-delay_samples;
 wire signed[16:0] difference=$signed({older[15],older})-$signed({q[15],q});
 wire signed[25:0] product=difference*$signed({1'b0,fraction});
 wire signed[26:0] interpolated=$signed({{11{q[15]}},q})+(product>>>8);
 wire signed[27:0] mixed=$signed({{12{dry[15]}},dry})+(history?(interpolated>>>1):28'sd0);
 function signed[15:0] sat;input signed[27:0] x;begin
 if(x>32767)sat=32767;else if(x< -32768)sat=-32768;else sat=x[15:0];end endfunction
 always @(posedge clk)begin
 if(input_valid)q<=mem[read_a];else if(pipe[0])begin older<=mem[read_b];end
 if(pipe[1])mem[write_a]<=en?dry:16'sd0;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin ptr<=0;read_b<=0;write_a<=0;filled<=0;phase<=0;down<=0;previous<=0;en<=0;history<=0;fraction<=0;pipe<=0;dry<=0;output_valid<=0;output_pcm<=0;end
 else begin
 pipe<={pipe[1:0],input_valid};output_valid<=pipe[1];
 if(input_valid)begin
 dry<=input_pcm;en<=enable;previous<=enable;fraction<=excursion[7:0];
 history<=enable && !clear && previous && filled>={1'b0,delay_samples}+1'b1;
 write_a<=ptr;read_b<=read_a-1'b1;ptr<=ptr+1'b1;
 if(clear)filled<=0;else if(!enable || !previous)filled<=enable?1:0;else if(filled<1024)filled<=filled+1'b1;
 if(!down)begin if(phase>=16384-phase_step)begin phase<=16384;down<=1;end else phase<=phase+phase_step;end
 else if(phase<=phase_step)begin phase<=0;down<=0;end else phase<=phase-phase_step;
 end
 if(pipe[1])output_pcm<=en && history && !clear ? sat({interpolated[26],interpolated}):16'sd0;
 end
endmodule
