`timescale 1ns/1ps
// Protocol V3: 160 bytes. 25 snapshots/s, up to 8 event records/snapshot.
// Event records are {prox,mask,time_us}, with a 32-entry nonblocking queue.
module joint07_uart #(parameter integer CLOCK_HZ=50000000,BAUD=115200,EXTENDED=0,TOUCH_DIAG=0,EXPANSION=0,EXPRESSION=0,TRAINER=0,HEALTH=0)(
 input wire[15:0] audio_underruns,input wire[31:0] spectrum_frames,spectrum_missed,
 input wire [7:0] trainer_flags,input wire clk,rst_n,trigger,input wire [31:0] time_us,input wire [15:0] sequence_id,
 input wire [7:0] pressed,seen,stale,flags,input wire [63:0] raw,
 input wire [255:0] sampled_at,input wire [15:0] errors0,errors1,
 input wire [1:0] pitch_mode,input wire [7:0] touch_keys,
 input wire [5:0] events,input wire apds_ready,prox_valid,input wire [7:0] prox,
 input wire [31:0] apds_errors,recoveries,output reg tx, input wire [15:0] voice_modes, input wire [3:0] selected,
 input wire test_mode,input wire [3:0] test_mask,
 input wire [31:0] touch_scans,input wire [15:0] touch_full,command_count,
 input wire [7:0] last_command,input wire touch_sdo,
 input wire [3:0] expression_config,input wire chord_mode,test32,input wire [5:0] selected_test,input wire [63:0] mask32
);
 reg [7:0] packet[0:159];
 reg [47:0] queue[0:31];
 reg [4:0] wr,rd;
 reg [5:0] used;
 reg [31:0] totals[0:5];
 reg [31:0] lost,prox_time;
 reg prox_seen;
 reg [7:0] prox_saved;
 reg [15:0] dropped;
 reg [7:0] index;
 reg [3:0] bit_no;
 reg [9:0] shifter;
 reg [31:0] accumulator;
 reg active,sending;
 reg [15:0] checksum;
 wire snapshot=trigger && !active;
 wire push=(|events) && used<32;
 wire [5:0] take=snapshot ? ((used>8)?6'd8:used) : 6'd0;
 wire [31:0] prox_age=time_us-prox_time;
 reg copy_busy,copy_valid;
 reg[3:0] copy_remaining;
 reg[4:0] copy_rd;
 reg[2:0] copy_slot,copy_dest;
 reg[47:0] copy_word;
 wire fetch_event=snapshot ? take!=0 : copy_busy;
 // One synchronous queue read per clock, instead of eight parallel read ports.
 // Fetch starts on the snapshot edge, ahead of any newly freed-slot writes.
 always @(posedge clk)if(fetch_event)copy_word<=queue[snapshot?rd:copy_rd];
 integer i,j;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   copy_busy<=0;copy_valid<=0;copy_remaining<=0;copy_rd<=0;copy_slot<=0;copy_dest<=0;
   wr<=0;rd<=0;used<=0;lost<=0;prox_time<=0;prox_seen<=0;prox_saved<=0;dropped<=0;
   tx<=1;index<=0;bit_no<=0;shifter<=1023;accumulator<=0;active<=0;sending<=0;checksum<=0;
   for(i=0;i<6;i=i+1)totals[i]<=0;
   for(i=0;i<160;i=i+1)packet[i]<=0;
  end else begin
   copy_valid<=fetch_event;
   if(fetch_event)begin
    if(snapshot)begin
     copy_rd<=rd+5'd1;copy_remaining<=take[3:0]-4'd1;copy_slot<=1;copy_dest<=0;copy_busy<=take>1;
    end else begin
     copy_rd<=copy_rd+1'b1;copy_remaining<=copy_remaining-1'b1;
     copy_dest<=copy_slot;copy_slot<=copy_slot+1'b1;copy_busy<=copy_remaining>1;
    end
   end
   // These bytes are serialized much later (byte104), so the wire timing is unchanged.
   for(i=0;i<8;i=i+1)if(copy_valid && copy_dest==i)
    for(j=0;j<6;j=j+1)packet[104+i*6+j]<=copy_word[j*8+:8];
   if(!apds_ready)prox_seen<=0;
   else if(prox_valid)begin prox_time<=time_us;prox_seen<=1;prox_saved<=prox;end
   for(i=0;i<6;i=i+1)if(events[i] && totals[i]!=32'hffffffff)totals[i]<=totals[i]+1'b1;
   if(push)begin queue[wr]<={prox_saved,2'b0,events,time_us};wr<=wr+1'b1;end
   // Conservative full behavior: even a simultaneous dequeue drops this new entry.
   if((|events) && !push && lost!=32'hffffffff)lost<=lost+1'b1;
   // 32-entry ring wraps modulo 32; take is bounded by eight.
   if(take!=0)rd<=rd+take[4:0];
   used<=used+{5'b0,push}-take;
   if(trigger && active && dropped!=65535)dropped<=dropped+1'b1;
   if(snapshot)begin
    packet[0]<=8'ha5;packet[1]<=8'h5a;packet[2]<=3;packet[3]<=160;
    for(i=0;i<4;i=i+1)packet[4+i]<=time_us[i*8+:8];
    packet[8]<=sequence_id[7:0];packet[9]<=sequence_id[15:8];
    packet[10]<=pressed;packet[11]<=seen;packet[12]<=stale;
    packet[13]<=(flags & 8'hcf) | ((TOUCH_DIAG && take<=6) ? 8'h10 : 0) | ((EXPANSION && take<=4) ? 8'h20 : 0);
    for(i=0;i<8;i=i+1)packet[14+i]<=raw[i*8+:8];
    for(i=0;i<32;i=i+1)packet[22+i]<=sampled_at[i*8+:8];
    packet[54]<=errors0[7:0];packet[55]<=errors0[15:8];
    packet[56]<=errors1[7:0];packet[57]<=errors1[15:8];
    packet[58]<={6'b0,pitch_mode};packet[59]<=touch_keys;
    packet[60]<={7'b0,apds_ready};packet[61]<=prox_saved;
    packet[62]<={7'b0,(prox_seen && apds_ready && prox_age<32'd500000)};
    packet[63]<={2'b0,take};
    for(i=0;i<6;i=i+1)for(j=0;j<4;j=j+1)packet[64+i*4+j]<=totals[i][j*8+:8];
    for(i=0;i<4;i=i+1)begin
     packet[88+i]<=apds_errors[i*8+:8];packet[92+i]<=recoveries[i*8+:8];packet[96+i]<=lost[i*8+:8];
    end
    packet[100]<=dropped[7:0];packet[101]<=dropped[15:8];packet[102]<=EXTENDED ? voice_modes[7:0] : 0;packet[103]<=EXTENDED ? voice_modes[15:8] : 0;
    for(i=0;i<8;i=i+1)for(j=0;j<6;j=j+1)
     packet[104+i*6+j]<=0;
    // Health uses event slots 2/3 only when empty. Existing V3 parsers ignore
    // these bytes; events are never displaced and packet checksum is unchanged.
    if(HEALTH && take<=2)begin
     packet[116]<=8'h48;packet[117]<=8'h53;
     packet[118]<=audio_underruns[7:0];packet[119]<=audio_underruns[15:8];
     for(i=0;i<4;i=i+1)begin packet[120+i]<=spectrum_frames[i*8+:8];packet[124+i]<=spectrum_missed[i*8+:8];end
    end
    // Only use event slots 6 and 7 when they are unused. Never truncate events.
    if(TOUCH_DIAG && take<=6)begin
     packet[140]<=8'h54;packet[141]<=8'h44;
     for(i=0;i<4;i=i+1)packet[142+i]<=touch_scans[i*8+:8];
     packet[146]<=touch_full[7:0];packet[147]<=touch_full[15:8];
     packet[148]<=command_count[7:0];packet[149]<=command_count[15:8];
     packet[150]<=last_command;packet[151]<={7'b0,touch_sdo};
    end
    if(EXPANSION && take<=4)begin
     packet[128]<=8'h58;packet[129]<=8'h31; // X1
     packet[130]<={6'b0,test32,chord_mode};packet[131]<={2'b0,selected_test};
     for(i=0;i<4;i=i+1)packet[132+i]<=(selected_test[5] ? mask32[32+i*8+:8] : mask32[i*8+:8]);
     packet[136]<=64;packet[137]<=4;packet[138]<=EXPRESSION?{4'd0,expression_config}:0;packet[139]<=TRAINER?trainer_flags:0;
    end
    packet[152]<=8'h47;packet[153]<=8'h30;packet[154]<=8'h37;packet[155]<=8'h31;
    packet[156]<=EXTENDED ? {4'b0,selected} : 0;packet[157]<=EXTENDED ? {1'b1,test_mode,2'b0,test_mask} : 0;
    index<=0;active<=1;sending<=0;accumulator<=0;checksum<=0;
   end
   if(active && !sending)begin
    if(index<158)begin checksum<=checksum+{8'b0,packet[index]};shifter<={1'b1,packet[index],1'b0};end
    else if(index==158)shifter<={1'b1,checksum[7:0],1'b0};
    else shifter<={1'b1,checksum[15:8],1'b0};
    tx<=0;bit_no<=0;accumulator<=0;sending<=1;
   end else if(sending)begin
    if(accumulator>=CLOCK_HZ-BAUD)begin
     accumulator<=accumulator+BAUD-CLOCK_HZ;
     if(bit_no==9)begin sending<=0;tx<=1;if(index==159)active<=0;else index<=index+1'b1;end
     else begin shifter<={1'b1,shifter[9:1]};tx<=shifter[1];bit_no<=bit_no+1'b1;end
    end else accumulator<=accumulator+BAUD;
   end
  end
 end
endmodule
