`timescale 1ns/1ps
module tb_timed_chart_protocol;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,rv=0,re=0,game=0,sv=0;reg[7:0] rd=0,pressed=0;reg signed[15:0] pcm=0;
 wire tv,busy,ce,me;wire[7:0] td;wire[255:0] chart;wire[55:0] map;
 reg ready=1;integer ticks=0;reg streaming=0;integer starts=0,stops=0;
 always @(posedge clk)begin if(dut.stream_start)starts=starts+1;if(dut.stream_stop)stops=stops+1;end
 always @(posedge clk)begin ticks<=ticks+1;ready<=ticks%4!=0;end
 bt_extensions #(.CLOCK_HZ(10000),.CLIP_ADDR_BITS(6),.LEGACY_CHART(0)) dut(clk,rst,rd,rv,re,tv,td,ready,busy,game,pressed,sv,pcm,ce,chart,me,map,,,,,,streaming,,,,,,,,,,,,);
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
 wire enabled,cache_ready;wire[10:0] count;wire[39:0] masks;wire[79:0] durations;reg[9:0] pos=0;
 timed_chart_store store(clk,rst,dut.chart_begin,dut.chart_count,dut.chart_write,dut.chart_address,dut.chart_event,
 dut.chart_commit,dut.chart_disable,pos,enabled,count,masks,durations,cache_ready);
 task check;input[9:0] address;input[7:0] mask;input[15:0] duration;begin
 @(negedge clk);pos=address;repeat(30)@(negedge clk);
 if(!cache_ready || masks[7:0]!==mask || durations[15:0]!==duration)$fatal(1,"cache pos=%d masks=%h dur=%d",pos,masks,durations[15:0]);end endtask
 initial begin
 vectors=$fopen("checks/v20_chart_responses.txt","w");repeat(4)@(negedge clk);rst=1;
 request("U",1,2,0,0);status(4);
 request("U",2,2,1025,0);status(4);
 request("U",3,2,1024,0);status(0);
 request("Z",4,0,0,0);status(3);if(enabled)$fatal(1,"partial enabled");
 request("V",5,5,{16'd500,8'd1,16'd1},0);status(4);
 request("V",6,5,{16'd19,8'd1,16'd0},0);status(4);
 for(i=0;i<1024;i=i+1)begin
 data=0;data[15:0]=i;data[23:16]=i;data[39:24]=i==1023?60000:20+i;
 request("V",7+i,5,data,0);status(0);
 // Repeat packet after lost ACK: cursor must not advance twice.
 if(i==10)begin request("V",7+i,5,data,0);status(0);end
 end
 request("Z",10,0,0,0);status(0);request("Z",10,0,0,0);status(0);
 if(count!=1024)$fatal(1,"1024 count");
 check(0,0,20);check(63,63,83);check(511,255,531);check(1023,255,60000);
 if(masks[39:8]!=0 || durations[79:16]!=0)$fatal(1,"end wraps");
 request("U",11,2,2,0);status(0);
 request("V",12,5,{16'd250,8'd3,16'd0},0);status(0);
 request("Z",13,0,0,0);status(3);check(0,0,20);
 // Bad second event must not partially write a block or move its cursor.
 request("V",14,8,{16'd19,8'd4,16'd500,8'd2,16'd1},0);status(4);
 request("V",15,5,{16'd500,8'd0,16'd1},1);status(5);
 request("V",16,5,{16'd500,8'd0,16'd1},0);status(0);
 game=1;request("Z",17,0,0,0);status(2);game=0;
 request("Z",18,0,0,0);status(0);check(0,3,250);check(1,0,500);
 request("D",19,0,0,0);status(0);if(enabled)$fatal(1,"disable");
 request("U",20,2,10,0);status(0);data=0;
 for(i=0;i<10;i=i+1)data[16+i*24+:24]={16'd300,8'h80};
 data[16+9*24+:24]={16'd19,8'h80};
 request("V",21,32,data,0);status(4);if(dut.upload_cursor!=0)$fatal(1,"partial invalid block commit");
 data[16+9*24+:24]={16'd60000,8'h01};
 request("V",22,32,data,0);status(0);request("V",22,32,data,0);status(0);
 request("Z",23,0,0,0);status(0);check(0,128,300);check(9,1,60000);
 data=0;for(i=0;i<32;i=i+1)data[i*8+:8]=8'd1<<(i%8);
 game=1;request("C",24,32,data,0);status(2);game=0;
 request("C",25,32,data,0);status(0);
 if(count!=32 || chart!=0 || !ce)$fatal(1,"legacy format did not use unified RAM");
 check(0,1,500);check(31,128,500);
 request("C",25,32,data,0);status(0);check(31,128,500);
 $fclose(vectors);$display("PASS timed chart 1024 events, 20/60000ms, rests, bank atomicity, retry, CRC, range, game busy, end padding");$finish;
 end

 initial begin #100000000;$fatal(1,"timeout");end
endmodule
