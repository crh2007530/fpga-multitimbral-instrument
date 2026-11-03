`timescale 1ns/1ps
module tb_stream_controls_v20;
reg clk=0;always #10 clk=~clk;reg rst=0,rx=1;
wire pending,kv,toggle;wire[5:0] fx;integer actions=0;always @(posedge clk)if(|fx || toggle || kv)actions=actions+1;wire tx;wire[7:0]rxdata,edata,sdata;wire rv,re,ev,ebusy,er,svalid,sready,packet,recording,sbusy,start,stop,mready;
wire[31:0]dropped;wire[7:0]hostdata;wire hostvalid,hosterror;
reg[10:0]sample_phase=0;reg sv=0;integer input_samples=0;
always @(posedge clk)begin
 sv<=0;
 if(rst)begin
 if(sample_phase==1040)begin sample_phase<=0;sv<=1;end else sample_phase<=sample_phase+1'b1;
 if(sv && recording)input_samples=input_samples+1;
 end
end
bt_extensions #(.LEGACY_CHART(0)) ext(.clk(clk),.rst_n(rst),.rx_data(rxdata),.rx_valid(rv),.rx_error(re),.tx_valid(ev),.tx_data(edata),.tx_ready(er),.busy(ebusy),.game_active(1'b0),.pressed(8'd0),.sample_valid(1'b0),.pcm(16'd0),.stream_start(start),.stream_stop(stop),.stream_recording(sbusy));
pcm_uart_stream stream(.clk(clk),.rst_n(rst),.start(start),.stop(stop),.sample_valid(sv),.pcm(16'sd0),.pause_new(ebusy||pending),.tx_valid(svalid),.tx_data(sdata),.tx_ready(sready),.packet_active(packet),.recording(recording),.dropped(dropped),.busy(sbusy));
assign er=mready&&!packet;assign sready=mready&&packet;
bluetooth_control #(.BAUD(115200),.FEATURES(1)) bt(.clk(clk),.rst_n(rst),.rx(rx),.tx(tx),.test_mode(1'b0),.trainer_active(1'b0),.trainer_running(1'b0),.trainer_done(1'b0),.ext_tx_valid(packet?svalid:ev),.ext_tx_data(packet?sdata:edata),.ext_busy(ebusy||packet),.ext_tx_ready(mready),.rx_data_out(rxdata),.rx_valid_out(rv),.rx_error_out(re),.command_pending(pending),.effect_events(fx),.trainer_toggle(toggle),.key_valid(kv));
bt_uart_rx #(.BAUD(115200)) receiver(clk,rst,tx,hostdata,hostvalid,hosterror);
reg[7:0]captured[0:4095];integer count=0;
always @(posedge clk)begin if(hosterror)$fatal(1,"UART framing");if(hostvalid)begin captured[count]=hostdata;count=count+1;end end
function[7:0]hex;input[3:0]v;begin hex=v<10?48+v:65+v-10;end endfunction
task put;input[7:0]v;integer i;begin
 @(negedge clk);rx=0;repeat(434)@(negedge clk);
 for(i=0;i<8;i=i+1)begin rx=v[i];repeat(434)@(negedge clk);end
 rx=1;repeat(434)@(negedge clk);
end endtask
task cmd;input[7:0]op,seq;reg[7:0]crc;begin crc=-(op+seq);put("!");put(op);put(hex(seq[7:4]));put(hex(seq[3:0]));put("0");put("0");put(hex(crc[7:4]));put(hex(crc[3:0]));put(10);end endtask
integer at,n,k,packets=0,pcmcount=0,acks=0,normalacks=0;integer vectors;reg ended=0;reg[7:0]checksum;
initial begin
repeat(4)@(negedge clk);rst=1;cmd("J",1);
wait(packet);put("@");put("A");put(10);wait(actions==1);repeat(10000)@(negedge clk);
wait(packet);put("@");put("B");put(10);wait(actions==2);repeat(10000)@(negedge clk);
wait(packet);put("@");put("T");put(10);wait(actions==3);repeat(10000)@(negedge clk);
wait(packet);put("@");put("?");put(10);repeat(50000)@(negedge clk);
wait(packet);put("!");put("F");put("0");put("3");put("0");put("1");put("0");put("3");put("B");put("3");put(10);
wait(!ebusy);if(ext.extra_fx!=3)$fatal(1,"FX while recording");
wait(input_samples>=3000);cmd("K",2);
wait(!sbusy && !ebusy);repeat(5000)@(negedge clk);
vectors=$fopen("checks/stream_controls_wire.hex","w");for(k=0;k<count;k=k+1)$fwrite(vectors,"%02x\n",captured[k]);$fclose(vectors);
at=0;
while(at<count)begin
 if(captured[at]=="!")begin
 if(captured[at+1]!="r")$fatal(1,"bad ack");
 while(captured[at]!=10 && at<count)at=at+1;at=at+1;acks=acks+1;
 end else if(captured[at]=="K" || captured[at]=="N")begin normalacks=normalacks+1;at=at+1;end else begin
 if(captured[at]!=8'ha5||captured[at+1]!=8'h5a)$fatal(1,"interleaved packet at %d",at);
 if({captured[at+3],captured[at+2]}!=packets)$fatal(1,"sequence");
 n=captured[at+4];checksum=0;
 for(k=at+2;k<at+11+n;k=k+1)checksum=checksum+captured[k];
 if(checksum!=0)$fatal(1,"checksum");
 for(k=0;k<n;k=k+1)if(captured[at+10+k]!=128)$fatal(1,"PCM corruption");
 if(captured[at+5]==1)ended=1;
 if({captured[at+9],captured[at+8],captured[at+7],captured[at+6]}!=0)$fatal(1,"reported drop");
 packets=packets+1;pcmcount=pcmcount+n;at=at+11+n;
 end
end
if(actions!=3||normalacks!=4||!ended||acks!=3||dropped!=0||pcmcount!=input_samples/6)$fatal(1,"stream result acks=%d pcm=%d input=%d",acks,pcmcount,input_samples);
$display("PASS production 115200 recording + A/B/T/query commands during packets, exactly once, complete packet arbitration, stop during stream, checksums, zero dropped samples: %d PCM samples",pcmcount);$finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule

