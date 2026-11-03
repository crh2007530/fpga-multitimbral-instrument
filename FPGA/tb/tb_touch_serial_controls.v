`timescale 1ns/1ps
module tb_touch_serial_controls;
reg clk=0;always #10 clk=~clk;
reg rst=0,sdo=1;reg [15:0] touched=0;
wire scl,valid;wire [7:0] keys;wire [1:0] unused,mode;
wire [15:0] modes;wire [3:0] selected,mask;wire fft;
integer bitnum=0,frames=0;time last_edge=0;
ttp229_pitch #(.START_CYCLES(50),.GAP_CYCLES(2000),.HALF_CYCLES(20)) scanner(clk,rst,sdo,scl,keys,valid,unused,,,);
performance_controls controls(clk,rst,valid,1'b0,1'b0,8'd0,keys,modes,selected,fft,mask,mode,,,,,,);
always @(negedge scl)if(rst)begin
 if($time-last_edge>5000)bitnum=0;
 #60;sdo=~touched[bitnum];bitnum=(bitnum+1)%16;last_edge=$time;
end
always @(posedge valid)frames=frames+1;
task key;input [15:0] k;integer n;begin touched=k;n=frames;wait(frames>=n+4);#100;end endtask
initial begin
 #200;rst=1;
 key(1);if(modes!==16'h5555)$fatal(1,"serial key1");
 key(3);key(2);if(modes!==0)$fatal(1,"serial overlap and key2");
 key(4);if(modes!==16'haaaa)$fatal(1,"serial key3");
 key(8);if(selected!==0)$fatal(1,"serial key4");
 key(8);if(selected!==0)$fatal(1,"serial held4 repeat");
 key(16);if(!fft||selected!==0||mask!==15)$fatal(1,"serial key5");
 key(48);key(32);if(mask!==14)$fatal(1,"serial overlap and key6");
 key(64);if(mask!==15)$fatal(1,"serial key7");
 key(128);if(fft||selected!==8||modes!==0)$fatal(1,"serial key8");
 $display("PASS physical SDO model through serial scanner and controls: keys1-8, overlap recovery, rollover, held no-repeat, FFT mute/all/exit");$finish;
end
initial begin #5000000;$fatal(1,"serial timeout");end
endmodule
