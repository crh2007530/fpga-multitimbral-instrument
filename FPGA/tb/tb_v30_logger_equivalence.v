`timescale 1ns/1ps
`include "tb/joint07_uart_reference.v"
module tb_v30_logger_equivalence;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,trigger=0;reg [31:0] time_us=0;reg [15:0] seq=0;
 reg [5:0] events=0;wire tx;
 always @(posedge clk)if(rst)time_us<=time_us+1;
 joint07_uart #(.CLOCK_HZ(1000),.BAUD(100),.EXTENDED(1),.TOUCH_DIAG(1),.EXPANSION(1),.HEALTH(1)) dut(.audio_underruns(16'h1234),.spectrum_frames(32'h89abcdef),.spectrum_missed(32'h76543210),
 .clk(clk),.rst_n(rst),.trigger(trigger),.time_us(time_us),.sequence_id(seq),
 .pressed(8'hc3),.seen(8'hff),.stale(8'h00),.flags(8'h82),
 .raw(64'h8070605040302010),.sampled_at(256'd0),.errors0(16'd2),.errors1(16'd3),
 .pitch_mode(2'd1),.touch_keys(8'd1),.events(events),.apds_ready(1'b1),
 .prox_valid(1'b1),.prox(8'd128),.apds_errors(32'd7),.recoveries(32'd2),.tx(tx),
 .touch_scans(32'h12345678),.touch_full(16'habcd),.command_count(16'h1234),.last_command(8'h08),.touch_sdo(1'b1),
 .chord_mode(1'b1),.test32(1'b1),.selected_test(6'd63),.mask32(64'h7ffffffe12345678),
 .voice_modes(16'h4926),.selected(4'd2),.test_mode(1'b1),.test_mask(4'hb));

 wire reference_tx;
 joint07_uart_reference #(.CLOCK_HZ(1000),.BAUD(100),.EXTENDED(1),.TOUCH_DIAG(1),.EXPANSION(1),.HEALTH(1)) reference(.audio_underruns(16'h1234),.spectrum_frames(32'h89abcdef),.spectrum_missed(32'h76543210),
 .clk(clk),.rst_n(rst),.trigger(trigger),.time_us(time_us),.sequence_id(seq),
 .pressed(8'hc3),.seen(8'hff),.stale(8'h00),.flags(8'h82),
 .raw(64'h8070605040302010),.sampled_at(256'd0),.errors0(16'd2),.errors1(16'd3),
 .pitch_mode(2'd1),.touch_keys(8'd1),.events(events),.apds_ready(1'b1),
 .prox_valid(1'b1),.prox(8'd128),.apds_errors(32'd7),.recoveries(32'd2),.tx(reference_tx),
 .touch_scans(32'h12345678),.touch_full(16'habcd),.command_count(16'h1234),.last_command(8'h08),.touch_sdo(1'b1),
 .chord_mode(1'b1),.test32(1'b1),.selected_test(6'd63),.mask32(64'h7ffffffe12345678),
 .voice_modes(16'h4926),.selected(4'd2),.test_mode(1'b1),.test_mask(4'hb));
 always @(negedge clk)if(rst && tx!==reference_tx)$fatal(1,"UART wire changed");
 reg [7:0] bytes[0:159];reg [7:0] value;
 reg [31:0] expected_time[0:34];reg [5:0] expected_mask[0:34];
 integer frames=0,decoded_events=0,bi=0,j,sum,file,k;
 integer busy_drops=0;reg overflow_seen=0;
 initial begin file=$fopen("checks/uart_health.hex","wb");end
 initial forever begin
  @(negedge tx);#50;
  if(tx!==0)$fatal(1,"start");
  for(j=0;j<8;j=j+1)begin #100;value[j]=tx;end
  #100;if(tx!==1)$fatal(1,"stop");bytes[bi]=value;$fwrite(file,"%02x\n",value);
  if(bi==159)begin
   sum=0;for(k=0;k<158;k=k+1)sum=sum+bytes[k];
   if({bytes[159],bytes[158]}!==(sum&65535))$fatal(1,"checksum");
   if(bytes[2]!=3||bytes[3]!=160||bytes[10]!=8'hc3||bytes[14]!=16||bytes[21]!=128||bytes[58]!=1||bytes[60]!=1)$fatal(1,"snapshot mapping");
   if(bytes[88]!=7||bytes[92]!=2||bytes[152]!=71||bytes[155]!=49)$fatal(1,"diagnostic mapping");
   if(bytes[102]!=8'h26||bytes[103]!=8'h49||bytes[156]!=2||bytes[157]!=8'hcb)$fatal(1,"extended control metadata");
   if(bytes[63]<=2)begin
    if(bytes[116]!=8'h48 || bytes[117]!=8'h53 || {bytes[119],bytes[118]}!==16'h1234 ||
       {bytes[123],bytes[122],bytes[121],bytes[120]}!==32'h89abcdef ||
       {bytes[127],bytes[126],bytes[125],bytes[124]}!==32'h76543210)$fatal(1,"health mapping");
   end
   if(bytes[63]<=4)begin
    if((bytes[13]&32)==0 || bytes[128]!=88 || bytes[129]!=49 || bytes[130]!=3 || bytes[131]!=63 || bytes[136]!=64 || bytes[137]!=4 || {bytes[135],bytes[134],bytes[133],bytes[132]}!==32'h7ffffffe)$fatal(1,"expansion payload");
   end else if((bytes[13]&32)!=0)$fatal(1,"expansion overwrote events");
   if(bytes[63]<=6)begin
    if((bytes[13]&16)==0 || bytes[140]!=84 || bytes[141]!=68 || {bytes[145],bytes[144],bytes[143],bytes[142]}!==32'h12345678 || {bytes[147],bytes[146]}!==16'habcd || {bytes[149],bytes[148]}!==16'h1234 || bytes[150]!=8 || bytes[151]!=1)$fatal(1,"touch diagnostic payload");
   end else if((bytes[13]&16)!=0)$fatal(1,"diagnostic overwrote full event payload");
   if(bytes[96]==3)overflow_seen=1;
   if(bytes[100]!=0)busy_drops=1;
   for(k=0;k<bytes[63];k=k+1)begin
    if({bytes[107+6*k],bytes[106+6*k],bytes[105+6*k],bytes[104+6*k]}!==expected_time[decoded_events])$fatal(1,"event timestamp/order %d",decoded_events);
    if(bytes[108+6*k]!=={2'b0,expected_mask[decoded_events]}||bytes[109+6*k]!=128)$fatal(1,"event mask/prox");
    decoded_events=decoded_events+1;
   end
   frames=frames+1;bi=0;
  end else bi=bi+1;
 end
 task snap;begin @(negedge clk);trigger=1;seq=seq+1;@(negedge clk);trigger=0;end endtask
 integer n;
 initial begin
  #30;rst=1;repeat(5)@(negedge clk);snap();
  // A snapshot in flight must remain immutable while the queue fills/overflows.
  for(n=0;n<35;n=n+1)begin
   @(negedge clk);events=(n==0)?6'b000011:(6'b1<<(n%6));
   expected_time[n]=time_us;expected_mask[n]=events;
   @(negedge clk);events=0;
  end
  snap(); // Busy snapshot drop must be visible, not block producers.
  wait(frames==1);wait(!dut.active);
  repeat(5)begin snap();wait(!dut.active);repeat(5)@(negedge clk);end
  wait(frames==6);
  if(decoded_events!=32||!overflow_seen||busy_drops==0||dut.used!=0)$fatal(1,"queue coverage %d",decoded_events);
  if(dut.totals[0]!=6||dut.totals[1]!=7||dut.totals[4]!=6||dut.totals[5]!=5)$fatal(1,"counter coverage");
  $fclose(file);$display("PASS bit-identical reference UART wire and HEALTH + JOINT07 UART: touch diagnostic/event coexistence, physical 8N1, 6 frames, immutable snapshots, 32 ordered timestamped records, simultaneous directions, 3 overflow drops, counters, busy drop, wraparound FIFO drain");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
