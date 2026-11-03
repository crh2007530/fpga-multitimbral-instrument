`timescale 1ns/1ps
module tb_video_serializer_start #(parameter integer RESET_DELAY_NS=0);
reg serial=0,pixel=0,ready=0,gsri=0;
always #1.348315 serial=~serial;
always #6.741575 pixel=~pixel;
GSR GSR(.GSRI(gsri));
wire gated,rst_n,q,oser_rst_n;
assign #(RESET_DELAY_NS) oser_rst_n=rst_n;reg[9:0] word=10'b1101010010;
video_serializer_start dut(pixel,ready,serial,rst_n,gated);
OSER10 ser(.Q(q),.D0(word[0]),.D1(word[1]),.D2(word[2]),.D3(word[3]),.D4(word[4]),
.D5(word[5]),.D6(word[6]),.D7(word[7]),.D8(word[8]),.D9(word[9]),.PCLK(pixel),.FCLK(gated),.RESET(~oser_rst_n));
real release_time,last_edge;integer edges=0,cycles=0,test,bitcount=0;
reg[9:0] shift=0;reg checking=0;integer word_matches=0;
always @(posedge rst_n)begin
 if(gated!==0)$fatal(1,"FCLK not stopped at reset release");
 release_time=$realtime;edges=0;
end
always @(posedge gated)if(rst_n)begin
 if(edges==0 && $realtime-release_time<100.0)$fatal(1,"Recovery guard too short %f",$realtime-release_time);
 edges=edges+1;
end
always @(gated)if(gsri && ready && rst_n)begin
 if(last_edge!=0 && edges>2 && $realtime-last_edge<1.34)$fatal(1,"Runt gated pulse");
 last_edge=$realtime;
end
// Every ten serialized bits must contain one full word (allow fixed rotation).
// Check recurrence and content; this validates OSER primitive/gate startup,
// not encrypted TMDS encoding or a monitor's electrical tolerance.
reg[9:0] previous;integer r;reg rotation_ok;
always @(posedge gated or negedge gated)begin
 #0.001;
 if(checking)begin
 shift={q,shift[9:1]};bitcount=bitcount+1;
 if(bitcount==10)begin
 bitcount=0;rotation_ok=0;
 for(r=0;r<10;r=r+1)if(shift==((word>>r)|(word<<(10-r))))rotation_ok=1;
 if(!rotation_ok)$fatal(1,"OSER corrupted word %b",shift);
 if(word_matches>0 && shift!==previous)$fatal(1,"OSER word alignment drift");
 previous=shift;word_matches=word_matches+1;
 end
 end
end
initial begin
 release_time=0;last_edge=0;
 #20;gsri=1;
 for(test=0;test<30;test=test+1)begin
 ready=0;checking=0;last_edge=0;
 #(20.125+test*0.317);ready=1;
 #600;
 word_matches=0;bitcount=0;checking=1;
 #1400;
 checking=0;if(word_matches<80)$fatal(1,"Missing serialized words");
 cycles=cycles+word_matches;
 end
 // 20ns CEN route + four 2.697ns synchronizer cycles < 31ns; allow 40ns.
 ready=0;#40;if(gated!==0 || rst_n!==0)$fatal(1,"Failed shutdown");
 $display("PASS reset_route_delay=%0dns; 30 asynchronous restart phases, %0d OSER10 words, >100ns recovery guard, no runt pulses, stable word alignment",RESET_DELAY_NS,cycles);$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule


