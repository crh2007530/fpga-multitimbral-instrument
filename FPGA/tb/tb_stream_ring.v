`timescale 1ns/1ps
module tb_stream_ring;
reg clk=0;always #5 clk=~clk;reg rst=0,start=0,stop=0,sv=0;
reg signed[15:0]pcm=0;wire valid,packet,recording,busy;wire[7:0]data;wire[31:0]drop;
reg[4:0]phase=0;wire ready=phase==0;always @(posedge clk)phase<=phase==29?0:phase+1'b1;
pcm_uart_stream #(.ADDR_BITS(7)) dut(clk,rst,start,stop,sv,pcm,1'b0,valid,data,ready,packet,recording,drop,busy);
integer pos=0,length=0,seq=0,received=0,flags=0;reg[7:0]sum=0;
always @(posedge clk)if(rst && valid && ready)begin
 if(pos==0 && data!=8'ha5)$fatal(1,"sync1");
 if(pos==1 && data!=8'h5a)$fatal(1,"sync2");
 if(pos==2 && data!=(seq&255))$fatal(1,"seq low");
 if(pos==3 && data!=(seq>>8))$fatal(1,"seq high");
 if(pos==4)length=data;
 if(pos==5)flags=data;
 if(pos>=6 && pos<=9 && data!=0)$fatal(1,"drop header");
 if(pos>=10 && pos<10+length)begin
 if(data!=(received&255))$fatal(1,"FIFO wrap corrupt sample %d got %d",received,data);
 received=received+1;
 end
 if(pos>=2)sum=sum+data;
 if(pos==10+length && pos>=10)begin
 if(sum!=0)$fatal(1,"checksum");pos=0;sum=0;seq=seq+1;
 end else pos=pos+1;
end
integer n,j;
initial begin
repeat(4)@(negedge clk);rst=1;start=1;@(negedge clk);start=0;
for(n=0;n<5000;n=n+1)begin
 for(j=0;j<6;j=j+1)begin
 @(negedge clk);sv=1;pcm=((n%256)-128)*256;
 @(negedge clk);sv=0;repeat(4)@(negedge clk);
 end
end
@(negedge clk);stop=1;@(negedge clk);stop=0;
wait(!busy);@(negedge clk);
if(received!=5000 || drop!=0 || flags!=1 || seq!=79)$fatal(1,"drain count");
$display("PASS 5000 distinct PCM bytes, 39 FIFO wraps, UART-budget backpressure, full/partial/end/checksum, no drop");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
