`timescale 1ns/1ps
module tb_pcm_uart_stream;
reg clk=0;always #5 clk=~clk;reg rst=0,start=0,stop=0,sv=0,pause=0,ready=1;
reg signed[15:0]pcm=0;wire valid,active,recording;wire[7:0]data;wire[31:0]drop;
pcm_uart_stream #(.ADDR_BITS(7)) dut(clk,rst,start,stop,sv,pcm,pause,valid,data,ready,active,recording,drop,);
integer output_file,n,j,bytes=0;reg[7:0]capture[0:2047];
always @(posedge clk)if(rst && valid && ready)begin capture[bytes]=data;bytes=bytes+1;end
task sample;input signed[15:0]v;begin @(negedge clk);sv=1;pcm=v;@(negedge clk);sv=0;repeat(4)@(negedge clk);end endtask
task packet_check;input integer at,len;reg[7:0]sum;integer k;begin
if(capture[at]!=8'ha5 || capture[at+1]!=8'h5a || capture[at+4]!=len)$fatal(1,"header");
sum=0;for(k=at+2;k<at+11+len;k=k+1)sum=sum+capture[k];if(sum!=0)$fatal(1,"checksum");end endtask
initial begin
repeat(3)@(negedge clk);rst=1;start=1;@(negedge clk);start=0;
for(n=0;n<70;n=n+1)for(j=0;j<6;j=j+1)sample(n==0?-32768:n==1?32767:0);
@(negedge clk);stop=1;@(negedge clk);stop=0;repeat(200)@(negedge clk);
packet_check(0,64);packet_check(75,6);
if(capture[10]!=0 || capture[11]!=255 || capture[12]!=128 || capture[80]!=1 || drop!=0 || recording)$fatal(1,"PCM/end");
output_file=$fopen("checks/stream_fixture.hex","w");for(n=0;n<bytes;n=n+1)$fdisplay(output_file,"%02x",capture[n]);$fclose(output_file);
// Stall consumer until FIFO fills: overflow must be explicit, never hidden.
ready=0;start=1;@(negedge clk);start=0;
for(n=0;n<140;n=n+1)for(j=0;j<6;j=j+1)sample(0);
if(drop!=12)$fatal(1,"overflow counter %d",drop);
$display("PASS continuous PCM full/partial/end packets, signed extrema, checksum, exact overflow counter");$finish;
end
endmodule
