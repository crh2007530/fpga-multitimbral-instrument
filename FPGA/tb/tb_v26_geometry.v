`timescale 1ns/1ps
module tb_v26_geometry;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg[10:0]x=0;reg[9:0]y=0;reg[127:0]s=0;reg[7:0]keys=0;
wire[23:0]rgb;
video_game_view dut(clk,rst,x,y,s,keys,8'd0,9'sd0,1'b0,1'b0,1'b0,1'b0,rgb,40'd0,1'b0,1'b0,80'd0);
integer i,j,prior,step,pos,spd;reg[10:0] lastcenter;
task tick;begin @(negedge clk);x=0;y=1;@(negedge clk);x=1;y=1;end endtask
initial begin
repeat(3)@(negedge clk);rst=1;s[30]=1;s[31]=1;keys=1;
repeat(60)tick();keys=128;repeat(8)tick();
// Pipelined preview schedule must equal the prior arithmetic after settling.
for(spd=0;spd<3;spd=spd+1)begin
 s[103:102]=spd;
 for(pos=0;pos<42;pos=pos+1)begin
  s[21:16]=pos;repeat(12)@(negedge clk);
  if(dut.base_due_q!==dut.base_due)$fatal(1,"chart pipeline mismatch position=%d speed=%d",pos,spd);
 end
end
prior=0;
for(j=160;j<608;j=j+1)begin
 @(negedge clk);x=0;y=j;@(negedge clk);x=1;@(negedge clk);x=100;
 for(i=0;i<8;i=i+1)begin
 if(dut.edge_x[i]>=dut.edge_x[i+1])$fatal(1,"crossed track edges");
 if(dut.left3[i]!==dut.edge_x[i]+11'd3 || dut.right4[i]!==dut.edge_x[i+1]-11'd4)$fatal(1,"registered bevel misalignment");
end
 if(j>160 && prior-dut.edge_x[0]>1)$fatal(1,"track edge jumps multiple pixels");
 prior=dut.edge_x[0];
end
lastcenter=0;
for(j=514;j<608;j=j+1)begin
 @(negedge clk);x=0;y=j;repeat(6)@(negedge clk);x=100;
 if(j>514)begin
 step=$signed({1'b0,dut.plane.ribbon_center})-$signed({1'b0,lastcenter});
 if(step>1 || step< -1)$fatal(1,"ribbon discontinuity %d",step);
 end
 lastcenter=dut.plane.ribbon_center;
end
keys=255;repeat(2)tick();@(negedge clk);x=608;y=560;#1;
if(dut.plane.sprite_hit || dut.plane.tail_hit)$fatal(1,"all-key aircraft should be hidden");
keys=0;repeat(20)tick();if(dut.plane.glow!=0)$fatal(1,"tail does not decay");
$display("PASS all track rows monotonic, outer edge <=1px/row, moving ribbon continuous, all-key mode, release fade");$finish;
end
endmodule
