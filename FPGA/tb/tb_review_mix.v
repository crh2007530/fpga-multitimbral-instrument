`timescale 1ns/1ps
module tb_review_mix;
reg clk=0; always #5 clk=~clk;
reg rst=0,valid=1;
reg [127:0] vector=0;
wire [15:0] underruns;
pcm_pressure_poly8 dut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(64'd0),.pitch_mode(2'd0),.underruns(underruns));
genvar c;
generate for(c=0;c<8;c=c+1) begin: inj
wire signed [15:0] value=vector[c*16+:16];
initial begin force dut.notes[c].note.pcm=value; force dut.notes[c].note.pcm_valid=valid; end
end endgenerate
integer total,expected,n,j,checks=0;
reg signed [15:0] last;
task check;
begin
 total=0;
 for(j=0;j<8;j=j+1) total=total+$signed(vector[j*16+:16]);
 expected=total>>>2;
 if(expected>32767) expected=32767;
 if(expected< -32768) expected=-32768;
 repeat(3) @(negedge clk);
 if($signed(dut.mixed_pcm)!==expected) $fatal(1,"mix got %d expected %d sum %d",$signed(dut.mixed_pcm),expected,total);
 checks=checks+1;
end
endtask
initial begin
 repeat(4) @(negedge clk);rst=1;
 vector={8{16'h7fff}};check;
 vector={8{16'h8000}};check;
 vector={4{32'h80007fff}};check;
 vector={8{16'hffff}};check;
 vector=0;check;
 for(n=0;n<2000;n=n+1) begin
  for(j=0;j<8;j=j+1) vector[j*16+:16]=$random;
  check;
 end
 last=dut.mixed_pcm;valid=0;vector=0;repeat(3) @(negedge clk);
 if(dut.mixed_pcm!==last || dut.mixed_valid!==0) $fatal(1,"invalid data updated output");
 $display("PASS review mix: %0d independent 32-bit reference vectors, positive/negative saturation, signed rounding, no wrap, invalid hold",checks);
 $finish;
end
endmodule
