`timescale 1ns/1ps
// Two parallel feedback combs followed by a Schroeder all-pass diffuser.
// Wet-only return. Same delay memory capacity as V28. No asynchronous RAM clearing.
module send_reverb_v29_reference(input clk,rst_n,enable,input_valid,input clear,input[1:0] room,decay,
 input signed[15:0] input_pcm,output reg output_valid,output reg signed[15:0] output_pcm);
 reg signed[15:0] c1[0:2047],c2[0:2047],ap[0:127];
 reg[10:0] p1,p2;reg[6:0] pa;reg[11:0] filled;
 reg signed[19:0] low1,low2;
 reg previous,en1,en2,v1,v2;reg signed[15:0] dry1,dry2,q1,q2,qa,wet2;
 reg valid1,valid2,validap;reg[10:0] a1,a2;reg[6:0] aa;
 function signed[15:0] sat;input signed[19:0] v;begin
 if(v>32767)sat=32767;else if(v< -32768)sat=-32768;else sat=v[15:0];end endfunction
 // Deadband only in feedback memories prevents fixed-point sub-32-LSB limit cycles at the strongest feedback.
 function signed[15:0] store;input signed[19:0] v;begin
 store=(v> -32 && v<32) ? 16'sd0:sat(v);end endfunction
 // Symmetric truncation avoids accumulating signed right-shift DC bias.
 function signed[19:0] shr;input signed[19:0] v;input integer n;begin
 shr=v<0?-((-v)>>>n):(v>>>n);end endfunction
 wire signed[19:0] r1=valid1 ? {{4{q1[15]}},q1}:20'sd0;
 wire signed[19:0] r2=valid2 ? {{4{q2[15]}},q2}:20'sd0;
 wire signed[19:0] av=validap ? {{4{qa[15]}},qa}:20'sd0;
 wire signed[19:0] dry={{4{dry1[15]}},dry1};
 wire[10:0] len1=room==0?11'd389:room==1?11'd1091:11'd1499;
 wire[10:0] len2=room==0?11'd521:room==1?11'd1499:11'd1877;
 // Room stays bright; Hall and Large progressively damp the feedback tail.
 wire signed[19:0] damp1=room==0?r1:room==1?shr(r1+low1,1):shr(r1+(low1<<<1)+low1,2);
 wire signed[19:0] damp2=room==0?r2:room==1?shr(r2+low2,1):shr(r2+(low2<<<1)+low2,2);
 wire signed[19:0] fb1=decay==0?shr(damp1,1):decay==1?damp1-shr(damp1,3):damp1-shr(damp1,5);
 wire signed[19:0] fb2=decay==0?shr(damp2,1):decay==1?damp2-shr(damp2,3):damp2-shr(damp2,5);
 wire signed[19:0] injection=room==0?shr(dry,1):room==1?shr(dry,2):shr(dry,3);
 wire signed[19:0] wet=room==0?shr(r1+r2,1):(r1+r2);
 wire signed[19:0] ap_feedback=room==2?wet-shr(wet,2):shr(wet,1);
 wire signed[19:0] diffuse=av-ap_feedback;
 wire signed[19:0] ap_write=wet+(room==2?diffuse-shr(diffuse,2):shr(diffuse,1));
 always @(posedge clk)begin
 if(input_valid)begin q1<=c1[p1];q2<=c2[p2];qa<=ap[pa];end
 if(v1)begin
 c1[a1]<=en1 ? store(injection+fb1):16'sd0;
 c2[a2]<=en1 ? store(injection+fb2):16'sd0;
 ap[aa]<=en1 ? store(ap_write):16'sd0;
 end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin low1<=0;low2<=0;p1<=0;p2<=0;pa<=0;filled<=0;previous<=0;en1<=0;en2<=0;v1<=0;v2<=0;dry1<=0;dry2<=0;wet2<=0;valid1<=0;valid2<=0;validap<=0;a1<=0;a2<=0;aa<=0;output_valid<=0;output_pcm<=0;end
 else begin
 v1<=input_valid;v2<=v1;output_valid<=v2;
 if(input_valid)begin
 dry1<=input_pcm;en1<=enable;previous<=enable;a1<=p1;a2<=p2;aa<=pa;
 p1<=p1>=len1-1'b1 ? 11'd0:p1+11'd1;p2<=p2>=len2-1'b1 ? 11'd0:p2+11'd1;pa<=pa==7'd112 ? 7'd0:pa+7'd1;
 valid1<=enable && !clear && previous && filled>={1'b0,len1};
 valid2<=enable && !clear && previous && filled>={1'b0,len2};
 validap<=enable && !clear && previous && filled>=113;
 if(clear)filled<=0;else if(!enable || !previous)filled<=enable ? 1:0;else if(filled<1877)filled<=filled+1'b1;
 end
 if(v1)begin low1<=en1 && !clear?damp1:20'sd0;low2<=en1 && !clear?damp2:20'sd0;dry2<=dry1;en2<=en1;wet2<=sat(diffuse);end
 if(v2)output_pcm<=en2 && !clear ? wet2:16'sd0;
 end
endmodule

