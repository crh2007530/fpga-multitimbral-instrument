`timescale 1ns/1ps
module tb_v23_title;
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
 reg[7:0] title_ram[0:511];integer writes=0,off,n,writes_before;
 always @(posedge clk)if(dut.title_write)begin title_ram[dut.title_address]=dut.title_data;writes=writes+1;end
 initial begin
 vectors=$fopen("checks/v23_title_responses.txt","w");repeat(4)@(negedge clk);rst=1;
 request("N",0,3,0,0);status(3);
 request("U",1,2,1,0);status(0);
 request("V",2,5,{16'd500,8'd1,16'd0},0);status(0);
 for(off=0;off<512;off=off+30)begin
  n=(512-off>30)?30:512-off;data=0;data[15:0]=off;
  for(j=0;j<n;j=j+1)data[(j+2)*8+:8]=(off+j)^8'ha5;
  if(off==0)begin
   request("N",3,n+2,data,1);status(5);if(writes!=0)$fatal(1,"bad CRC wrote title");
   game=1;request("N",4,n+2,data,0);status(2);game=0;
  end
  request("N",5+off/30,n+2,data,0);status(0);writes_before=writes;
  request("N",5+off/30,n+2,data,0);status(0);
  if(writes!=writes_before)$fatal(1,"retry wrote twice");
  if(dut.title_valid)$fatal(1,"title exposed before chart commit");
 end
 if(writes!=512 || dut.title_cursor!=512)$fatal(1,"title length");
 for(i=0;i<512;i=i+1)if(title_ram[i]!==((i^8'ha5)&255))$fatal(1,"title byte %d",i);
 request("N",40,3,{8'd1,16'd512},0);status(4);
 request("Z",41,0,0,0);status(0);if(!dut.title_valid)$fatal(1,"full title not committed");
 request("U",42,2,1,0);status(0);if(dut.title_valid)$fatal(1,"stale title");
 request("V",43,5,{16'd250,8'd2,16'd0},0);status(0);
 request("N",44,3,{8'd1,16'd1},0);status(4);
 request("Z",45,0,0,0);status(0);if(dut.title_valid)$fatal(1,"legacy client inherits title");
 request("D",46,0,0,0);status(0);
 $fclose(vectors);$display("PASS title CRC/busy/range/retry, 512 bytes exact, atomic publish, old-client fallback, reset");$finish;
 end

 initial begin #100000000;$fatal(1,"timeout");end
endmodule
