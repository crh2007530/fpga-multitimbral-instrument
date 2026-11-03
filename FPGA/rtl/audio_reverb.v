`timescale 1ns/1ps
// Two parallel feedback combs followed by a Schroeder all-pass diffuser.
// Direct sound is retained. No asynchronous clearing of block RAM.
module audio_reverb(input clk,rst_n,enable,input_valid,
 input signed[15:0] input_pcm,output reg output_valid,output reg signed[15:0] output_pcm);
 reg signed[15:0] c1[0:2047],c2[0:2047],ap[0:127];
 reg[10:0] p1,p2;reg[6:0] pa;reg[11:0] filled;
 reg previous,en1,en2,v1,v2;reg signed[15:0] dry1,dry2,q1,q2,qa,wet2;
 reg valid1,valid2,validap;reg[10:0] a1,a2;reg[6:0] aa;
 function signed[15:0] sat;input signed[19:0] v;begin
 if(v>32767)sat=32767;else if(v< -32768)sat=-32768;else sat=v[15:0];end endfunction
 // Deadband only in feedback memories prevents fixed-point one-LSB limit cycles.
 function signed[15:0] store;input signed[19:0] v;begin
 store=(v> -4 && v<4) ? 16'sd0:sat(v);end endfunction
 wire signed[19:0] r1=valid1 ? {{4{q1[15]}},q1}:20'sd0;
 wire signed[19:0] r2=valid2 ? {{4{q2[15]}},q2}:20'sd0;
 wire signed[19:0] av=validap ? {{4{qa[15]}},qa}:20'sd0;
 wire signed[19:0] dry={{4{dry1[15]}},dry1};
 wire signed[19:0] wet=(r1+r2)>>>2;
 wire signed[19:0] diffuse=av-(wet>>>1);
 always @(posedge clk)begin
 if(input_valid)begin q1<=c1[p1];q2<=c2[p2];qa<=ap[pa];end
 if(v1)begin
 c1[a1]<=en1 ? store((dry>>>1)+(r1-(r1>>>2))):16'sd0;
 c2[a2]<=en1 ? store((dry>>>1)+(r2-(r2>>>2))):16'sd0;
 ap[aa]<=en1 ? store(wet+(diffuse>>>1)):16'sd0;
 end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin p1<=0;p2<=0;pa<=0;filled<=0;previous<=0;en1<=0;en2<=0;v1<=0;v2<=0;dry1<=0;dry2<=0;wet2<=0;valid1<=0;valid2<=0;validap<=0;a1<=0;a2<=0;aa<=0;output_valid<=0;output_pcm<=0;end
 else begin
 v1<=input_valid;v2<=v1;output_valid<=v2;
 if(input_valid)begin
 dry1<=input_pcm;en1<=enable;previous<=enable;a1<=p1;a2<=p2;aa<=pa;
 p1<=p1==11'd1498 ? 11'd0:p1+11'd1;p2<=p2==11'd1876 ? 11'd0:p2+11'd1;pa<=pa==7'd112 ? 7'd0:pa+7'd1;
 valid1<=enable && previous && filled>=1499;
 valid2<=enable && previous && filled>=1877;
 validap<=enable && previous && filled>=113;
 if(!enable || !previous)filled<=enable ? 1:0;else if(filled<1877)filled<=filled+1'b1;
 end
 if(v1)begin dry2<=dry1;en2<=en1;wet2<=sat(diffuse);end
 if(v2)output_pcm<=en2 ? sat($signed({{4{dry2[15]}},dry2})+($signed({{4{wet2[15]}},wet2})>>>1)):dry2;
 end
endmodule
