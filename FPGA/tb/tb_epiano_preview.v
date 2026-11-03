`timescale 1ns/1ps
module tb_epiano_preview;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,ce=0,on=0,off=0,flute=0,piano=0;
 wire[15:0] level;wire active,valid;reg[31:0]phase=0;
 wire[127:0] samples;wire[79:0]addresses={70'd0,phase[31:22]};
 instrument_env #(.THIRD_TIMBRE(1)) env(clk,rst,ce,on,off,flute,1'b0,level,active,piano);
 shared_voice_bank #(.VOICES(8),.GROUP(8),.THIRD_TIMBRE(1)) bank(.increments({112'd0,16'd600}),.gates({7'd0,active}),.diagnostic_mode(1'b0),.clk(clk),.rst_n(rst),.sample_ce(ce),.sine_mode(flute),.epiano_mode(piano),.addresses(addresses),.forces({112'd0,16'd28672}),.envelopes({112'd0,level}),.samples(samples),.valid(valid));
 integer f,n,mode;reg[255:0]name;
 initial begin
 for(mode=0;mode<3;mode=mode+1)begin
 rst=0;ce=0;on=0;off=0;phase=0;flute=mode==1;piano=mode==2;
 repeat(4)@(negedge clk);rst=1;
 case(mode)0:name="checks/preview_pluck.txt";1:name="checks/preview_flute.txt";2:name="checks/preview_epiano.txt";endcase
 f=$fopen(name,"w");
 for(n=0;n<57656;n=n+1)begin
 @(negedge clk);on=(n==0);off=(n==28828);
 @(negedge clk);on=0;off=0;ce=1;
 @(negedge clk);ce=0;
 wait(valid);@(negedge clk);
 if(^samples[15:0]===1'bx)$fatal(1,"unknown preview sample");
 $fdisplay(f,"%0d",$signed(samples[15:0]));
 repeat(4)@(negedge clk);phase=phase+32'd39332563;
 end
 $fclose(f);if(active)$fatal(1,"preview release stuck");
 end
 $display("PASS actual envelope + shared waveform/gain RTL renders three 1.2-second mono notes (same 440Hz/pressure)");$finish;
 end
endmodule

