`timescale 1ns/1ps
// Three independent wet sends from the SAME synth sample; dry mixed exactly once.
// Parameter changes fade wet gains down before resetting history validity. No RAM clear.
module audio_send_fx(input clk,rst_n,input_valid,input signed[15:0] input_pcm,
 input[32:0] config_data,input[2:0] enables,input bypass,test_mode,
 output reg output_valid,output reg signed[15:0] output_pcm);
 reg[32:0] shape;
 wire shape_change=shape[13:10]!=config_data[13:10] || shape[23:19]!=config_data[23:19] || shape[32:29]!=config_data[32:29];
 reg clear;
 reg[8:0] dg,rg,eg,cg;
 function[8:0] level;input[4:0] n;begin level=n>=16?9'd256:{n,4'd0};end endfunction
 function[8:0] slew;input[8:0] a,b;begin slew=a<b?a+1'b1:a>b?a-1'b1:a;end endfunction
 wire[8:0] rt=(!enables[0] || bypass || test_mode || shape_change)?9'd0:level(config_data[9:5]);
 wire[8:0] et=(!enables[1] || bypass || test_mode || shape_change)?9'd0:level(config_data[18:14]);
 wire[8:0] ct=(!enables[2] || bypass || test_mode || shape_change)?9'd0:level(config_data[28:24]);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin shape<=0;clear<=0;dg<=256;rg<=0;eg<=0;cg<=0;end
 else begin
 if(input_valid)begin
 clear<=0;
 dg<=slew(dg,level(config_data[4:0]));rg<=slew(rg,rt);eg<=slew(eg,et);cg<=slew(cg,ct);
 if(shape_change && rg==0 && eg==0 && cg==0)begin shape<=config_data;clear<=1;end
 end
 end
 wire signed[15:0] rw,ew,cw;wire rv,ev,cv;
 send_reverb reverb(clk,rst_n,!test_mode,input_valid,clear,shape[13:12],shape[11:10],input_pcm,rv,rw);
 send_echo echo(.clk(clk),.rst_n(rst_n),.enable(!test_mode),.input_valid(input_valid),.clear(clear),.time_sel(shape[20:19]),.feedback_gain(shape[23:21]),.input_pcm(input_pcm),.output_valid(ev),.output_pcm(ew));
 send_chorus chorus(clk,rst_n,!test_mode,input_valid,clear,shape[30:29],shape[32:31],input_pcm,cv,cw);
 // One shared gain multiplier, four products scheduled within the 512-clock frame.
 reg[8:0] pipe;reg signed[15:0] dry;
 reg[8:0] gd,gr,ge,gc;
 reg signed[15:0] mul_sample;reg[8:0] mul_gain;
 reg signed[25:0] product;
 reg signed[27:0] accumulator;
 wire signed[27:0] final_sum=accumulator+$signed({{2{product[25]}},product});
 wire signed[27:0] scaled=final_sum>>>8;
 always @* begin
 mul_sample=dry;mul_gain=gd;
 if(pipe[4])begin mul_sample=rw;mul_gain=gr;end
 if(pipe[5])begin mul_sample=ew;mul_gain=ge;end
 if(pipe[6])begin mul_sample=cw;mul_gain=gc;end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin pipe<=0;dry<=0;gd<=256;gr<=0;ge<=0;gc<=0;product<=0;accumulator<=0;output_valid<=0;output_pcm<=0;end
 else begin
 pipe<={pipe[7:0],input_valid};output_valid<=pipe[7];
 if(input_valid)begin dry<=input_pcm;gd<=test_mode?9'd256:dg;gr<=test_mode?9'd0:rg;ge<=test_mode?9'd0:eg;gc<=test_mode?9'd0:cg;end
 if(|pipe[6:3])product<=mul_sample*$signed({1'b0,mul_gain});
 if(pipe[4])accumulator<=$signed({{2{product[25]}},product});
 else if(pipe[5] || pipe[6])accumulator<=accumulator+$signed({{2{product[25]}},product});
 if(pipe[7])output_pcm<=scaled>32767?16'sh7fff:scaled< -32768?16'sh8000:scaled[15:0];
 end
endmodule
