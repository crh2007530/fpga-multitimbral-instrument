`timescale 1ns/1ps
module tb_v28_app_fx;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,rv=0,re=0,game=0,sv=0;reg[7:0] rd=0,pressed=0;reg signed[15:0] pcm=0;
 wire tv,busy,ce,me;wire[7:0] td;wire[255:0] chart;wire[55:0] map;
 reg ready=1;integer ticks=0,fx_writes=0;
 always @(posedge clk)if(rst && dut.extra_fx_write)fx_writes=fx_writes+1;
 always @(posedge clk)begin ticks<=ticks+1;ready<=ticks%4!=0;end
 bt_extensions #(.CLOCK_HZ(10000),.CLIP_ADDR_BITS(6)) dut(clk,rst,rd,rv,re,tv,td,ready,busy,game,pressed,sv,pcm,ce,chart,me,map ,,,,,,1'b0,,,,,,,,,,,,);
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
 reg[255:0] data;integer i,j,expected_pop;
 initial begin
  vectors=$fopen("checks/v28_app_fx_responses.txt","w");repeat(4)@(negedge clk);rst=1;
  for(i=0;i<256;i=i+1)begin
 expected_pop=0;for(j=0;j<8;j=j+1)expected_pop=expected_pop+((i>>j)&1);
 if(dut.popcount(i[7:0])!==expected_pop[3:0])$fatal(1,"population count mismatch %d",i);
 end
 request("F",31,1,3,0);status(0);if(dut.extra_fx!=3 || fx_writes!=1)$fatal(1,"FX command");
  request("F",32,1,4,0);status(4);if(dut.extra_fx!=3 || fx_writes!=1)$fatal(1,"invalid FX committed");
  request("F",33,1,0,0);status(0);if(dut.extra_fx!=0 || fx_writes!=2)$fatal(1,"FX disable");
 request("F",34,1,0,0);status(0);if(fx_writes!=3)$fatal(1,"same-value explicit OFF was lost");
  request("G",1,2,0,0);status(3);
  data={32{8'h81}};request("C",2,32,data,1);status(5);if(ce)$fatal(1,"bad CRC committed");
  request("C",3,32,data,0);status(0);if(!ce || chart!=data)$fatal(1,"chart commit");
  game=1;request("C",4,32,{32{8'h40}},0);status(2);if(chart!=data)$fatal(1,"busy changed chart");game=0;
  request("C",5,32,0,0);status(4);
  request("C",25,32,{32{8'hff}},0);status(4);if(chart!=data)$fatal(1,"oversize note count committed");
  data=64'h7f7e4544403c0100;request("M",6,8,data,0);status(0);
  for(i=0;i<8;i=i+1)if(map[i*7+:7]!=data[i*8+:7])$fatal(1,"map packed wrong");
  pressed=1;request("D",7,0,0,0);status(2);pressed=0;
  request("M",8,8,64'hffffffffffffffff,0);status(4);
  // Partial frame cannot commit; parser must recover after inter-byte timeout.
  put("!");put("D");puthex(9);repeat(2600)@(negedge clk);if(busy || !me)$fatal(1,"timeout recovery");
  request("B",10,0,0,0);status(0);
  for(i=0;i<4;i=i+1)sample(-32768);
  request("B",10,0,0,0);status(0);if(dut.clip_count!=1)$fatal(1,"duplicate start erased recording");
  request("B",11,0,0,0);status(2);
  request("G",12,2,0,0);status(2);
  for(i=1;i<64;i=i+1)for(j=0;j<4;j=j+1)sample(i==1?32767:0);
  if(dut.clip_count!=64 || dut.recording || !dut.clip_ready)$fatal(1,"full clip did not stop");
  repeat(8)sample(32767);if(dut.clip_count!=64)$fatal(1,"clip wrapped");
  request("H",13,0,0,0);status(0);if(resp(3)!=64 || resp(4)!=0 || resp(5)!=8'hec || resp(6)!=8'h2e)$fatal(1,"metadata");
  request("G",14,2,0,0);status(0);
  if(resp(1)!=0 || resp(2)!=255)$fatal(1,"PCM signed extremes");
  for(i=3;i<=32;i=i+1)if(resp(i)!=128)$fatal(1,"silence not 128");
  request("G",15,2,63,0);status(0);if(used!=13 || resp(1)!=128)$fatal(1,"last partial block");
  request("G",16,2,64,0);status(4);
  request("B",17,0,0,0);status(0);sample(32767);request("S",18,0,0,0);status(0);
  request("G",19,2,0,0);status(3);
  request("D",20,0,0,0);status(0);if(me || ce)$fatal(1,"restore defaults");
  $fclose(vectors);$display("PASS v14 extension CRC, timeout, atomic chart/map, busy gates, idempotent retry, PCM signed extremes, full/partial chunks and no wrap");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
