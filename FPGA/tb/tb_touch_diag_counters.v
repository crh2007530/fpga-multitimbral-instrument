`timescale 1ns/1ps
module tb_touch_diag_counters;
reg clk=0;always #10 clk=~clk;
reg rst=0,sdo=1;reg [15:0] touched=0;
wire scl,valid,level;wire [7:0] keys,last;wire [1:0] mode;
wire [31:0] scans;wire [15:0] full,commands,modes;wire [3:0] selected,mask;wire fft;
integer bitnum=0,frames=0;time last_edge=0;reg [31:0] before_scans;
ttp229_pitch #(.START_CYCLES(50),.GAP_CYCLES(2000),.HALF_CYCLES(20)) scanner(
 .clk(clk),.rst_n(rst),.sdo(sdo),.scl(scl),.keys(keys),.frame_valid(valid),.pitch_mode(),.scan_count(scans),.full_keys(full),.sdo_level(level));
performance_controls controls(.clk(clk),.rst_n(rst),.frame_valid(valid),.keys(keys),.modes(modes),.selected(selected),.test_mode(fft),.test_mask(mask),.selected_mode(mode),.command_count(commands),.last_command(last));
always @(negedge scl)if(rst)begin
 if($time-last_edge>5000)bitnum=0;
 #60;sdo=~touched[bitnum];bitnum=(bitnum+1)%16;last_edge=$time;
end
always @(posedge valid)frames=frames+1;
task key;input [15:0] k;integer n;begin touched=k;n=frames;wait(frames>=n+4);#100;if(full!==k||keys!==k[7:0]||scans!==frames)$fatal(1,"scan diagnostics mismatch");end endtask
task count;input [15:0] expected;input [7:0] code;begin if(commands!==expected||last!==code)$fatal(1,"command count expected %d/%h got %d/%h",expected,code,commands,last);end endtask
initial begin
 #200;rst=1;key(0);count(0,0);
 key(8);count(1,8);before_scans=scans;
 key(8);count(1,8);if(scans<=before_scans||selected!==0)$fatal(1,"stuck readout stopped scanner or repeated NEXT");
 key(0);key(8);count(2,8);if(selected!==1)$fatal(1,"NEXT repeat after release");
 key(3);count(2,8);key(4);count(3,4);
 key(16);count(4,16);key(1);count(4,16);
 key(32);count(5,32);key(64);count(6,64);key(128);count(7,128);
 key(16'h8000);count(7,128);
 $display("PASS scan/frame counters, full 16-bit readout, stuck-key scan progress, action counters/last key, ignored-mode commands, high-bit capture");$finish;
end
initial begin #5000000;$fatal(1,"diagnostic timeout");end
endmodule
