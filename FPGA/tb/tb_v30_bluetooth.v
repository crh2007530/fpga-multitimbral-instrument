`timescale 1ns/1ps
module tb_v30_bluetooth;
reg clk=0;always #10 clk=~clk;
reg practice=0;wire ps;integer starts=0;
reg rst=0,rx=1,test_mode=0,active=0,running=0,done=0;
wire tx,kv,toggle,vv;wire[7:0] km;wire[5:0]fx;wire[1:0]vs;
bluetooth_control #(.CLOCK_HZ(320000),.BAUD(10000),.PRACTICE(1)) dut(clk,rst,rx,test_mode,active,running,done,tx,kv,km,toggle,fx,vv,vs,,1'b0,8'd0,1'b0,,,,,,practice,ps);
integer keys=0,toggles=0,effects=0,visuals=0,nreply=0;reg[7:0] replies[0:99];
wire[7:0]rd;wire rv,re;
bt_uart_rx #(.CLOCK_HZ(320000),.BAUD(10000)) monitor(clk,rst,tx,rd,rv,re);
always @(posedge clk)begin
 if(ps)starts=starts+1;if(kv)keys=keys+1;if(toggle)toggles=toggles+1;if(fx!=0)effects=effects+1;if(vv)visuals=visuals+1;
 if(rv)begin replies[nreply]=rd;nreply=nreply+1;end
 if(re)$fatal(1,"bad reply UART");
end
task byte_send;input[7:0]v;input integer cycles;integer j;begin
 @(negedge clk);rx=0;repeat(cycles)@(negedge clk);
 for(j=0;j<8;j=j+1)begin rx=v[j];repeat(cycles)@(negedge clk);end
 rx=1;repeat(cycles)@(negedge clk);
end endtask
task cmd;input[7:0]v;begin byte_send("@",32);byte_send(v,32);byte_send(10,32);repeat(400)@(negedge clk);end endtask
task reply_check;input[7:0]v;begin if(nreply==0 || replies[nreply-1]!=v)$fatal(1,"reply expected %c got %c",v,replies[nreply-1]);end endtask
integer n;
initial begin
 repeat(5)@(negedge clk);rst=1;repeat(10)@(negedge clk);
 // Raw module status, embedded numbers and command letters must not actuate.
 byte_send("+",32);byte_send("T",32);byte_send("1",32);byte_send(13,32);byte_send(10,32);
 repeat(400)@(negedge clk);if(keys||toggles||nreply)$fatal(1,"unframed text accepted");
 cmd("1");reply_check("K");if(keys!=1 || km!=1)$fatal(1,"key1");
 cmd("1");if(keys!=2)$fatal(1,"repeated remote key suppressed");
 cmd("T");reply_check("K");if(toggles!=1)$fatal(1,"toggle");
 cmd("A");cmd("B");cmd("C");cmd("D");if(effects!=4)$fatal(1,"effects");
 cmd("W");cmd("S");cmd("X");cmd("R");if(visuals!=4||vs!=3)$fatal(1,"visuals");
 cmd("?");reply_check("N");test_mode=1;cmd("?");reply_check("F");
 cmd("T");reply_check("I");cmd("A");reply_check("I");cmd("1");reply_check("I");
 test_mode=0;active=1;cmd("?");reply_check("P");running=1;
 cmd("?");reply_check("R");cmd("2");reply_check("I");cmd("7");reply_check("I");
 cmd("W");reply_check("I");done=1;cmd("?");reply_check("D");active=0;running=0;done=0;
 n=keys;cmd("z");reply_check("E");
 byte_send("@",32);byte_send("1",32);byte_send("2",32);byte_send(10,32);repeat(400)@(negedge clk);reply_check("E");
 if(keys!=n)$fatal(1,"overlong/invalid command applied");
 // CRLF creates exactly one response/action, no duplicate from LF.
 n=nreply;byte_send("@",32);byte_send("8",32);byte_send(13,32);byte_send(10,32);repeat(400)@(negedge clk);
 if(nreply!=n+1 || keys!=3)$fatal(1,"CRLF");
 // Incomplete frame expires; short start glitch and sustained break recover.
 byte_send("@",32);byte_send("1",32);repeat(80010)@(negedge clk);byte_send(10,32);
 @(negedge clk);rx=0;repeat(5)@(negedge clk);rx=1;repeat(400)@(negedge clk);
 rx=0;repeat(800)@(negedge clk);rx=1;repeat(400)@(negedge clk);
 if(keys!=3)$fatal(1,"noise/timeout acted");
 // +/-3.125 percent baud mismatch is tolerated with valid 8N1 frames.
 byte_send("@",31);byte_send("2",31);byte_send(10,31);repeat(400)@(negedge clk);reply_check("K");
 byte_send("@",33);byte_send("3",33);byte_send(10,33);repeat(400)@(negedge clk);reply_check("K");
 if(keys!=5)$fatal(1,"baud tolerance/recovery");
 // Consecutive frames at wire speed: one-byte replies cannot overrun.
 n=nreply;repeat(10)begin byte_send("@",32);byte_send("4",32);byte_send(10,32);end
 repeat(400)@(negedge clk);if(keys!=15 || nreply!=n+10)$fatal(1,"burst loss");
 cmd("L");reply_check("K");if(starts!=1)$fatal(1,"practice command pulse");
 practice=1;active=1;cmd("?");reply_check("H");running=1;cmd("?");reply_check("J");done=1;cmd("?");reply_check("O");
 cmd("L");reply_check("I");if(starts!=1)$fatal(1,"duplicate practice entry");
 active=0;test_mode=1;cmd("L");reply_check("I");
 $display("PASS Bluetooth UART wire-level: framing, all commands, mode guards, replies, CRLF, timeout, break/glitch, baud tolerance, burst");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
