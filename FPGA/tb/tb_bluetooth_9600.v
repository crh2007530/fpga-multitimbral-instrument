`timescale 1ns/1ps
module tb_bluetooth_9600;
reg clk=0;always #10 clk=~clk;reg rst=0,rx=1;
wire tx,kv,toggle,vv;wire[7:0]km;wire[5:0]fx;wire[1:0]vs;
bluetooth_control dut(clk,rst,rx,1'b0,1'b0,1'b0,1'b0,tx,kv,km,toggle,fx,vv,vs,,1'b0,8'd0,1'b0,,,,,,1'b0,);
integer n=0;always @(posedge clk)if(kv)n=n+1;
task send_byte;input[7:0]v;integer j;begin
 rx=0;#104166.667;
 for(j=0;j<8;j=j+1)begin rx=v[j];#104166.667;end
 rx=1;#104166.667;
end endtask
reg[7:0]result;integer i;
initial begin
 #100;rst=1;#1000;
 send_byte("@");send_byte("1");send_byte(10);
 #1500000;
 if(n!=1||km!=1)$fatal(1,"real 50MHz / 9600 command");
 send_byte("@");send_byte("?");send_byte(10);
 #1500000;
 if(n!=1 || replies!=2)$fatal(1,"query mutated controls or missing reply");
 $display("PASS physical timing: 50MHz clock, asynchronous exact 9600baud source, key accepted once and query reply independently decoded");$finish;
end
integer replies=0;
initial begin
 wait(rst);
 forever begin
  @(negedge tx);#156250;
  for(i=0;i<8;i=i+1)begin result[i]=tx;#104166.667;end
  if(tx!==1)$fatal(1,"stop bit");
  if((replies==0 && result!="K") || (replies==1 && result!="N"))$fatal(1,"real baud reply %h",result);
  replies=replies+1;
 end
end
initial begin #12000000;$fatal(1,"timeout");end
endmodule
