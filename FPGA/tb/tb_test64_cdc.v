`timescale 1ns/1ps
module tb_test64_cdc;
reg sc=0,pc=0;always #10 sc=~sc;always #7 pc=~pc;
reg rst=0;reg[127:0]game=128'hc0000000000000000000000000000000;
reg[63:0]mask=~64'd0;reg[5:0]sel=0;
wire hs,vs,de;wire[7:0]r,g,b;
video_dashboard #(.CUSTOM_CHART(1)) dut(game,pc,rst,sc,rst,1'b0,1'b0,10'd0,24'd0,24'd0,1'b0,16'd0,8'd0,8'd0,hs,vs,de,r,g,b,256'd0,1'b0,mask,sel,1'b0,1'b0,40'd0,80'd0,64'd0,61'd0,1'b0,9'd0,8'd0,1'b0,22'd0,64'd0,24'd0);
integer i,j;reg[254:0]old;
task commit;begin @(negedge pc);dut.x=1648;dut.y=749;repeat(8)@(negedge pc);end endtask
initial begin
repeat(5)@(negedge sc);rst=1;
for(i=0;i<64;i=i+1)begin
 old=dut.snapshot;@(negedge sc);mask=~(64'd1<<i);sel=i;
 repeat(80)@(negedge sc);
 if(dut.snapshot!==old)$fatal(1,"mid-frame UI tear");
 commit;
 if(dut.snapshot[254:191]!==mask || dut.snapshot[190:185]!==sel || !dut.test64)$fatal(1,"mask/selection snapshot %d",i);
end
for(i=0;i<256;i=i+1)for(j=0;j<4;j=j+1)begin
 @(negedge pc);dut.x=128+i*4+j;#1;
 if(dut.fft_read_bin!==i)$fatal(1,"4x FFT zoom address");
end
game=0;repeat(80)@(negedge sc);commit;
if(dut.test64)$fatal(1,"test page stuck");
$display("PASS 64 individual mute/selection atomic snapshots, all1024 zoom pixels map to correct real FFT bins, return to performance");$finish;
end
endmodule
