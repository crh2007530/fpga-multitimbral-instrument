`timescale 1ns/1ps
module tb_controls;
reg clk=0;always #5 clk=~clk;
reg rst=0,valid=0;reg [7:0] keys=0;
wire [15:0] modes;wire [3:0] selected,mask;wire test_mode;wire [1:0] mode;
performance_controls dut(clk,rst,valid,1'b0,1'b0,8'd0,keys,modes,selected,test_mode,mask,mode,,,,,,);
task frame;input [7:0] k;begin @(negedge clk);keys=k;valid=1;@(negedge clk);valid=0;end endtask
task key;input [7:0] k;begin frame(0);frame(0);frame(k);frame(k);end endtask
integer i;
initial begin
 repeat(3)@(negedge clk);rst=1;
 if(selected!==8||modes!==0||test_mode!==0)$fatal(1,"startup");
 frame(1);if(modes!==0)$fatal(1,"unfiltered press");frame(0);frame(0);
 key(1);if(modes!==16'h5555)$fatal(1,"global low");
 key(2);key(8);if(selected!==0)$fatal(1,"first target");
 repeat(8)frame(8);if(selected!==0)$fatal(1,"held auto repeat");
 key(4);if(modes!==2)$fatal(1,"independent high");
 key(8);key(1);if(modes!==6)$fatal(1,"Z2 low Z1 preserved");
 key(3);if(modes!==6)$fatal(1,"ambiguous keys accepted");
 key(128);if(modes!==0||selected!==8)$fatal(1,"restore");
 key(16);if(!test_mode||mask!==15||selected!==0)$fatal(1,"FFT enter");
 key(4);if(modes!==0)$fatal(1,"FFT changed pitch");
 for(i=0;i<4;i=i+1)begin
  key(32);if(mask!==(15^(1<<i)))$fatal(1,"mute");
  key(64);if(mask!==15)$fatal(1,"restore test all");key(8);
 end
 if(selected!==0)$fatal(1,"FFT target wraps");
 key(16);if(test_mode)$fatal(1,"exit FFT");
 for(i=0;i<8;i=i+1)begin if(selected!==i)$fatal(1,"target %d",i);key(8);end
 key(64);if(selected!==8)$fatal(1,"ALL");
 $display("PASS controls: debounce, release re-arm, held-no-repeat, ambiguous reject, eight independent targets, ALL, FFT fixed pitch/mute/restore/exit");$finish;
end
endmodule
