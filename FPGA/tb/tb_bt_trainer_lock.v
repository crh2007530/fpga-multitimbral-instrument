`timescale 1ns/1ps
module tb_bt_trainer_lock;
reg clk=0;always #5 clk=~clk;
reg rst=0,fv=0,remote_valid=0,remote_toggle=0,lock=0;reg[7:0] keys=0,remote_keys=0;
wire active,running;
offline_trainer #(.CLOCK_HZ(32),.REMOTE(1)) dut(
 .clk(clk),.rst_n(rst),.frame_valid(fv),.test_mode(1'b0),.keys(keys),.pressed(8'd0),
 .remote_valid(remote_valid),.remote_toggle(remote_toggle),.remote_keys(remote_keys),.local_inhibit(lock),
 .active(active),.running(running));
task tick;begin @(negedge clk);end endtask
initial begin
 repeat(3)tick;rst=1;
 // Arm long7, then start a remote transaction just before the hold threshold.
 keys=64;fv=1;repeat(3)tick;fv=0;
 wait(dut.hold_count==30);tick;lock=1;
 repeat(50)tick;if(active)$fatal(1,"local long7 changed mode inside remote transaction");
 remote_toggle=1;tick;remote_toggle=0;tick;
 if(!active)$fatal(1,"remote T blocked by arbitration");
 repeat(50)tick;if(!active)$fatal(1,"held7 toggled back while locked");
 // Release the lock with touch7 still held: a remote entry consumes that hold.
 lock=0;repeat(50)tick;if(!active)$fatal(1,"held7 toggled again after remote entry");
 // Lesson timer continues through remote transactions, not paused by the lock.
 lock=1;remote_valid=1;remote_keys=16;tick;remote_valid=0;
 if(!running)$fatal(1,"remote play");repeat(90)tick;
 if(dut.count_in!=0)$fatal(1,"Bluetooth lock paused offline count-in");
 remote_toggle=1;tick;remote_toggle=0;repeat(3)tick;
 if(active || running)$fatal(1,"remote exit");
 $display("PASS remote transaction freezes local long7 only; remote entry consumes held7; offline lesson timer continues; exit remains available");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
