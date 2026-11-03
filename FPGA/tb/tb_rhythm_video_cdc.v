`timescale 1ns/1ps
module tb_rhythm_video_cdc;
 reg pc=0,sc=0;always #7 pc=~pc;always #10 sc=~sc;
 reg rst=0;reg[127:0] state=0;reg[7:0] pressed=0;
 wire hs,vs,de;wire[7:0] r,g,b;
 video_dashboard dut(state,pc,rst,sc,rst,1'b0,1'b0,10'd0,24'sd0,24'sd0,1'b0,16'sd0,pressed,8'd0,hs,vs,de,r,g,b,256'd0,1'b0,64'hffffffffffffffff,6'd0,1'b0,1'b0,40'd0,80'd0,64'd0,61'd0,1'b0,9'd0,8'd0,1'b0,22'd0,64'd0,24'd0);
 task next_frame;begin
 // Skip inactive raster time only; release before the real frame boundary.
 @(negedge pc);dut.x=1648;dut.y=749;
 repeat(8)@(negedge pc);
 end endtask
 initial begin
 repeat(4)@(negedge sc);rst=1;repeat(40)@(negedge sc);
 state[30]=1;state[15:0]=1234;state[51:36]=4321;pressed=8'h55;
 repeat(40)@(negedge sc);
 if(dut.snapshot!=0)$fatal(1,"midframe state tore");
 next_frame;
 if(dut.game!==state || dut.snapshot[7:0]!=8'h55)$fatal(1,"coherent frame commit");
 state[15:0]=5678;pressed=8'haa;repeat(40)@(negedge sc);
 if(dut.game[15:0]!=1234 || dut.snapshot[7:0]!=8'h55)$fatal(1,"midframe changed");
 next_frame;
 if(dut.game[15:0]!=5678 || dut.snapshot[7:0]!=8'haa)$fatal(1,"next frame missing");
 state=0;repeat(40)@(negedge sc);next_frame;
 if(dut.game_active)$fatal(1,"return to visual page");
 $display("PASS rhythm HDMI: 144-bit bundled CDC snapshot atomic at frame boundary, enter/update/exit");$finish;
 end
endmodule
