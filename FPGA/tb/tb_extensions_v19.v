`timescale 1ns/1ps
module tb_extensions_v19;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,rv=0,re=0,game=0,sv=0;reg[7:0] rd=0,pressed=0;reg signed[15:0] pcm=0;
 wire tv,busy,ce,me;wire[7:0] td;wire[255:0] chart;wire[55:0] map;
 reg ready=1;integer ticks=0;reg streaming=0;integer starts=0,stops=0;
 always @(posedge clk)begin if(dut.stream_start)starts=starts+1;if(dut.stream_stop)stops=stops+1;end
 always @(posedge clk)begin ticks<=ticks+1;ready<=ticks%4!=0;end
 bt_extensions #(.CLOCK_HZ(10000),.CLIP_ADDR_BITS(6)) dut(clk,rst,rd,rv,re,tv,td,ready,busy,game,pressed,sv,pcm,ce,chart,me,map,,,,,,streaming,,,,,,,,,,,,);
 reg[7:0] output_bytes[0:127];integer used=0;integer vectors;
 always @(posedge clk)if(tv && ready)begin output_bytes[used]=td;used=used+1;end
 function[7:0] hex;input[3:0] n;begin hex=n<10?48+n:65+n-10;end endfunction
 function[3:0] unhex;input[7:0] c;begin unhex=c<=57?c-48:c-65+10;end endfunction
 function[7:0] resp;input integer n;begin resp={unhex(output_bytes[6+2*n]),unhex(output_bytes[7+2*n])};end endfunction
 task put;input[7:0] b;begin @(negedge clk);rd=b;rv=1;@(negedge clk);rv=0;end endtask
 task puthex;input[7:0] b;begin put(hex(b[7:4]));put(hex(b[3:0]));end endtask
 task request;input[7:0] op,seq;input integer len;input[255:0] data;input bad;integer i;reg[7:0] sum;begin
  used=0;sum=op+seq+len;put("!");put(op);puthex(seq);puthex(len);
  for(i=0;i<len;i=i+1)begin puthex(data[i*8+:8]);sum=sum+data[i*8+:8];end
  puthex(-sum+bad);put(10);wait(!busy);@(negedge clk);
 end endtask
 task status;input[7:0] expected;integer i,n;reg[7:0] sum;begin
  if(output_bytes[0]!="!" || output_bytes[1]!="r" || output_bytes[used-1]!=10)$fatal(1,"response framing");
  n={unhex(output_bytes[4]),unhex(output_bytes[5])};
  sum="r"+{unhex(output_bytes[2]),unhex(output_bytes[3])}+n;
  for(i=0;i<=n;i=i+1)sum=sum+resp(i);
  if(sum!=0 || used!=9+2*n || resp(0)!=expected)$fatal(1,"response expected=%d actual=%d checksum=%d",expected,resp(0),sum);
  for(i=0;i<used;i=i+1)$fwrite(vectors,"%c",output_bytes[i]);
 end endtask
 task sample;input signed[15:0] v;begin @(negedge clk);pcm=v;sv=1;@(negedge clk);sv=0;end endtask
 reg[255:0] data;integer i,j;
 initial begin
  vectors=$fopen("checks/v19_wire_responses.txt","w");repeat(4)@(negedge clk);rst=1;
  request("P",1,1,3,0);status(0);if(dut.pluck_config!=3)$fatal(1,"P high");
  pressed=1;request("P",2,1,1,0);status(2);pressed=0;
  if(dut.pluck_config!=3)$fatal(1,"busy commit");
  request("P",3,1,1,0);status(0);if(dut.pluck_config!=1)$fatal(1,"P low");
  request("P",4,1,4,0);status(4);
  data=72'h006420000005008801;
  request("E",5,9,data,0);status(0);
  if(dut.adsr_config!={1'b1,15'd100,15'd8192,15'd5,15'd136})$fatal(1,"ADSR packing");
  request("E",6,9,72'h006420000005000001,0);status(4);
  request("E",7,9,data,1);status(5);
  game=1;request("E",8,9,data,0);status(2);game=0;
  request("J",9,0,0,0);status(0);if(starts!=1)$fatal(1,"start");
  streaming=1;request("J",9,0,0,0);status(0);if(starts!=1)$fatal(1,"duplicate restarted");
  request("J",10,0,0,0);status(2);if(starts!=1)$fatal(1,"busy restarted");
  request("K",11,0,0,0);status(0);if(stops!=1)$fatal(1,"stop");
  request("K",11,0,0,0);status(0);if(stops!=1)$fatal(1,"duplicate stop");
  $fclose(vectors);$display("PASS v19 optical polarity, ADSR packing/range/CRC/busy, continuous start/stop and idempotent retry");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
