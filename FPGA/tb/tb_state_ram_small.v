`timescale 1ns/1ps
module tb_state_ram_small;
reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,piano=0,guitar=0,diag=0;
GSR GSR(.GSRI(rst));
reg[39:0]addresses=0;reg[63:0]forces=0,envelopes=0,steps=0;reg[3:0]gates=0;
wire[63:0]samples,reference;wire valid,rv;
shared_voice_bank #(.VOICES(4),.GROUP(4),.THIRD_TIMBRE(1)) dut(clk,rst,ce,guitar,addresses,forces,envelopes,samples,valid,piano,diag,steps,gates);
reference_voice_bank #(.VOICES(4),.GROUP(4),.THIRD_TIMBRE(1)) refdut(clk,rst,ce,guitar,addresses,forces,envelopes,reference,rv,piano,diag,steps,gates);
integer frame,i,t,seed=9217;reg[31:0] random_word;
initial begin
repeat(4)@(negedge clk);rst=1;
for(frame=0;frame<512;frame=frame+1)begin
 if(frame%257==256)begin rst=0;repeat(3)@(negedge clk);rst=1;end
 @(negedge clk);piano=frame%4==2;guitar=frame%4==1;diag=frame%4==3;
 for(i=0;i<4;i=i+1)begin
 random_word=$random(seed);addresses[i*10+:10]=random_word[9:0];steps[i*16+:16]=random_word[31:16];
 forces[i*16+:16]=random_word[14:0];envelopes[i*16+:16]=32767;
 if(frame%7==0)gates[i]=random_word[18];
 end
 ce=1;@(negedge clk);ce=0;
 for(t=0;t<100;t=t+1)begin
 @(negedge clk);if(valid!==rv)$fatal(1,"valid differs");
 if(valid && samples!==reference)$fatal(1,"state RAM samples differ frame=%d",frame);
 end
end
$display("PASS 512 continuous frames x4 voice state RAM versus register reference, all timbres/diagnostic, random gates/phase/force and 1 midstream reset using native SDPX9B");$finish;
end
endmodule
