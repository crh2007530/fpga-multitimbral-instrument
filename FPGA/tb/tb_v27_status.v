`timescale 1ns/1ps
module tb_v27_status;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0]s=0;reg[21:0]pitch=0;reg[10:0]x=64;reg[9:0]y=640;
video_labels dut(s,clk,rst,x,y,1'b0,1'b0,1'b1,24'd0,,,,,1'b0,pitch,64'd0,9'd0,1'b0,24'd0);
integer page,celln,st,idx;reg[511:0] expected;
initial begin repeat(3)@(negedge clk);rst=1;
for(page=0;page<2;page=page+1)begin
s=0;s[30]=page;
for(celln=0;celln<5;celln=celln+1)begin
for(st=0;st<4;st=st+1)begin
s[127]=st==3;s[117]=st==2;s[118]=st==1;s[119]=st==1;s[122]=st==1;s[123]=st==1;s[124]=st==1;
y=(page || st==3)?704:640;repeat(2)@(negedge clk);
expected=st==3?dut.S_TEST:st==2 && (celln==0 || celln==1 || celln==3)?dut.S_HOLD:st==1?dut.S_ON:dut.S_OFF;
for(idx=0;idx<4;idx=idx+1)begin
x=64+celln*192+idx*16;#1;
if(dut.letter!==expected[(63-idx)*8+:8])$fatal(1,"state text mismatch page=%d cell=%d state=%d char=%d",page,celln,st,idx);
end end end end
s=0;x=128;y=96;
pitch={4'd8,16'h5555,2'd0};#1;if(dut.pitch_word!==dut.P_LOW)$fatal(1,"low octave label");
pitch={4'd8,16'h0000,2'd0};#1;if(dut.pitch_word!==dut.P_MID)$fatal(1,"middle octave label");
pitch={4'd8,16'haaaa,2'd0};#1;if(dut.pitch_word!==dut.P_HIGH)$fatal(1,"high octave label");
pitch={4'd8,16'h0001,2'd0};#1;if(dut.pitch_word!==dut.P_MIX)$fatal(1,"mixed octave label");
pitch={4'd0,16'h0001,2'd0};#1;if(dut.pitch_word!==dut.P_LOW)$fatal(1,"individual octave label");
s[30]=1;x=320;y=152;#1;if(dut.row!=0)$fatal(1,"game pitch first glyph row");y=167;#1;if(dut.row!=15)$fatal(1,"game pitch last glyph row");if(dut.pitch_word!==dut.P_CHART)$fatal(1,"game must not claim octave controls");
s=0;pitch=22'd1;x=512;y=688;#1;if(dut.letter!==dut.P_MANUAL[511:504])$fatal(1,"manual bypass label");
pitch=22'd2;#1;if(dut.letter!==dut.P_NEAR[511:504])$fatal(1,"near bypass label");
$display("PASS both pages all effect words OFF/ON/BYPASS/TEST; low/middle/high/mixed/per-key/chart pitch and bypass source");$finish;end
endmodule
