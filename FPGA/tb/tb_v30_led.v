`timescale 1ns/1ps
module tb_v30_led;
reg clk=0;always #5 clk=~clk;reg rst=0,a=0,run=0,done=0;reg[2:0]ev=0;reg[7:0]mask=0;reg[4:0]pixel=0;wire[23:0]rgb;
game_led_fx #(.TICK_CYCLES(4)) dut(clk,rst,a,run,done,ev,mask,pixel,rgb);
task ticks;input integer n;begin repeat(n*4)@(negedge clk);end endtask
task fire;input[2:0]code;input[7:0]m;begin @(negedge clk);ev=code;mask=m;@(negedge clk);ev=0;mask=0;end endtask
integer j;
initial begin repeat(3)@(negedge clk);rst=1;a=1;run=1;
fire(1,8'h04);pixel=7;#1;if(rgb!==24'h401040)$fatal(1,"origin");
ticks(3);pixel=4;#1;if(rgb!==24'h401040)$fatal(1,"left wave");pixel=10;#1;if(rgb!==24'h401040)$fatal(1,"right wave");
fire(1,8'h81);pixel=1;#1;if(rgb!==24'h401040)$fatal(1,"multi origin 1");pixel=22;#1;if(rgb!==24'h401040)$fatal(1,"multi origin 8");
fire(4,0);for(j=0;j<30;j=j+1)begin pixel=j;#1;if(rgb!==24'h004000)$fatal(1,"whole red");end
ticks(9);if(rgb!==24'h000008)$fatal(1,"flash gap");ticks(7);if(rgb!==24'h004000)$fatal(1,"second flash");ticks(16);if(rgb!==24'h000008)$fatal(1,"flash ends");
fire(3,0);#1;if(rgb!==24'h304000)$fatal(1,"miss yellow");
fire(2,0);#1;if(rgb[23:16]==0 || rgb[15:0]!=0)$fatal(1,"good green");
run=0;ticks(1);if(dut.flash!=0 || dut.age[0]!=63)$fatal(1,"pause clears");
done=1;ticks(102);if(rgb!==24'h300000)$fatal(1,"done settles green");a=0;ticks(1);if(rgb!==0)$fatal(1,"exit clears");
$display("PASS perfect bidirectional/multiple origins, whole-strip good/wrong/miss, two flashes, pause/exit cleanup, completion");$finish;
end
endmodule
