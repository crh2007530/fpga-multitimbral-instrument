`timescale 1ns/1ps
// !OP SEQ(2hex) LEN(2hex) PAYLOAD(2hex/byte) CHECKSUM(2hex) LF
// Sum(OP+SEQ+LEN+payload+checksum) mod 256 = 0. Response OP='r';
// payload starts with status 0=OK,1=format,2=busy,3=not ready,4=range,5=checksum.
// A successful immediately repeated identical request replays its response.
module bt_extensions #(parameter CLOCK_HZ=50000000,CLIP_ADDR_BITS=15,LEGACY_CHART=1)(
 input clk,rst_n,input[7:0] rx_data,input rx_valid,rx_error,
 output wire tx_valid,output reg[7:0] tx_data,input tx_ready,output wire busy,
 input game_active,input[7:0] pressed,input sample_valid,input signed[15:0] pcm,
 output reg chart_enabled,output reg[255:0] chart_data,
 output reg map_enabled,output reg[55:0] keymap,output reg[1:0] extra_fx,
 output reg[1:0] pluck_config,output reg[60:0] adsr_config,output reg stream_start,stream_stop,input stream_recording,
 output reg chart_begin,output reg[10:0] chart_count,output reg chart_write,output reg[9:0] chart_address,output reg[23:0] chart_event,output reg chart_commit,chart_disable,output reg title_write,output reg[8:0] title_address,output reg[7:0] title_data,output reg title_valid,output reg extra_fx_write);
 localparam IDLE=0,OP=1,HEX=2,EXEC=3,FETCH=4,WAIT_READ=5,CRC=6,TX=7,DROP=8,CHECK_CHART=9,PRECHECK=10,VALIDATE_EVENTS=11,WRITE_EVENTS=12,WRITE_LEGACY=13,COMMIT_LEGACY=14,WRITE_TITLE=15;
 reg[9:0] title_cursor;reg[5:0] title_index;
 reg uploading;reg[10:0] upload_total,upload_cursor;reg[3:0] event_index,event_count;
 // Explicit fixed slices avoid a 32-bit multiply and bit-granular barrel
 // selector for the non-power-of-two 24-bit event stride.
 reg[23:0] selected_event;
 always @*begin
  case(event_index)
   0:selected_event=payload[39:16];
   1:selected_event=payload[63:40];
   2:selected_event=payload[87:64];
   3:selected_event=payload[111:88];
   4:selected_event=payload[135:112];
   5:selected_event=payload[159:136];
   6:selected_event=payload[183:160];
   7:selected_event=payload[207:184];
   8:selected_event=payload[231:208];
   9:selected_event=payload[255:232];
   default:selected_event=24'd0;
  endcase
 end
 reg[3:0] packet_events;
 always @*begin
  case(len)
   8'd5:packet_events=1;8'd8:packet_events=2;8'd11:packet_events=3;8'd14:packet_events=4;8'd17:packet_events=5;
   8'd20:packet_events=6;8'd23:packet_events=7;8'd26:packet_events=8;8'd29:packet_events=9;8'd32:packet_events=10;
   default:packet_events=0;
  endcase
 end
 wire[11:0] packet_end={1'b0,upload_cursor}+{8'd0,packet_events};
 reg match_cached;
 reg[5:0] check_index;reg[8:0] note_count;
 wire[7:0] check_byte=payload[check_index*8+:8];
 // Balanced exact population count; no packet/state/protocol changes.
 function[3:0] popcount;input[7:0] bits;reg[1:0] a,b,c,d;reg[2:0] lo,hi;
 begin a={1'b0,bits[0]}+{1'b0,bits[1]};b={1'b0,bits[2]}+{1'b0,bits[3]};
 c={1'b0,bits[4]}+{1'b0,bits[5]};d={1'b0,bits[6]}+{1'b0,bits[7]};
 lo={1'b0,a}+{1'b0,b};hi={1'b0,c}+{1'b0,d};popcount={1'b0,lo}+{1'b0,hi};end endfunction
 reg[3:0] state;reg[31:0] timer;
 reg[7:0] op,seq,len,checksum;reg[5:0] received;reg half;reg[3:0] high_nibble;
 reg[255:0] payload;
 reg[263:0] response,last_response;reg[5:0] response_len,last_len,crc_index;
 reg[7:0] sum,tx_checksum;reg[6:0] tx_index;
 reg cached,cache_this;reg[7:0] last_op,last_seq,last_req_len;reg[255:0] last_payload;
 reg record_start,record_stop;wire recording,clip_ready;wire[15:0] clip_count;
 reg[14:0] read_address;wire[7:0] read_data;reg[5:0] read_index,read_count;
 pcm_clip_recorder #(.ADDR_BITS(CLIP_ADDR_BITS)) recorder(clk,rst_n,record_start,record_stop,sample_valid,pcm,recording,clip_ready,clip_count,read_address,read_data);
 assign busy=state!=IDLE;
 assign tx_valid=state==TX;
 wire ishex=(rx_data>="0"&&rx_data<="9")||(rx_data>="A"&&rx_data<="F")||(rx_data>="a"&&rx_data<="f");
 wire[7:0] nibble_value=rx_data<="9" ? rx_data-8'h30:rx_data<="F" ? rx_data-8'h41+8'd10:rx_data-8'h61+8'd10;
 wire[3:0] nibble=nibble_value[3:0];
 wire[15:0] clip_remaining=clip_count-payload[15:0];
 wire[7:0] byte_in={high_nibble,nibble};
 function[7:0] hx;input[3:0] n;begin hx=n<10 ? "0"+n:"A"+n-10;end endfunction
 wire[7:0] response_byte=response[((tx_index-7'd6)>>1)*8+:8];
 always @*begin
  tx_data=10;
  case(tx_index)
   0:tx_data="!";1:tx_data="r";2:tx_data=hx(seq[7:4]);3:tx_data=hx(seq[3:0]);
   4:tx_data=hx({2'b0,response_len[5:4]});5:tx_data=hx(response_len[3:0]);
   default:if(tx_index<6+2*response_len)tx_data=hx(tx_index[0] ? response_byte[3:0]:response_byte[7:4]);
    else if(tx_index==6+2*response_len)tx_data=hx(tx_checksum[7:4]);
    else if(tx_index==7+2*response_len)tx_data=hx(tx_checksum[3:0]);
  endcase
 end
 integer i;integer m;reg invalid_chart,invalid_map;
 always @*begin
  invalid_chart=0;invalid_map=0;
  for(i=0;i<32;i=i+1)if(payload[i*8+:8]==0)invalid_chart=1;
  for(i=0;i<8;i=i+1)if(payload[i*8+7])invalid_map=1;
 end
 task reply_error;input[7:0] code;begin response<=code;response_len<=1;sum<=8'h72+seq+8'd1;crc_index<=0;cache_this<=0;state<=CRC;end endtask
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  extra_fx_write<=0;title_write<=0;title_address<=0;title_data<=0;title_valid<=0;title_cursor<=0;title_index<=0;
  state<=IDLE;match_cached<=0;timer<=0;op<=0;seq<=0;len<=0;checksum<=0;received<=0;half<=0;high_nibble<=0;payload<=0;check_index<=0;note_count<=0;
  response<=0;response_len<=0;sum<=0;crc_index<=0;tx_checksum<=0;tx_index<=0;cached<=0;cache_this<=0;
  last_op<=0;last_seq<=0;last_req_len<=0;last_payload<=0;last_response<=0;last_len<=0;
  uploading<=0;upload_total<=0;upload_cursor<=0;event_index<=0;event_count<=0;chart_begin<=0;chart_count<=0;chart_write<=0;chart_address<=0;chart_event<=0;chart_commit<=0;chart_disable<=0;record_start<=0;record_stop<=0;stream_start<=0;stream_stop<=0;read_address<=0;read_index<=0;read_count<=0;
  chart_enabled<=0;chart_data<=0;map_enabled<=0;keymap<=0;extra_fx<=0;pluck_config<=2;adsr_config<=0;
 end else begin
  extra_fx_write<=0;title_write<=0;
  record_start<=0;record_stop<=0;stream_start<=0;stream_stop<=0;chart_begin<=0;chart_write<=0;chart_commit<=0;chart_disable<=0;
  if(state==OP || state==HEX || state==DROP)timer<=timer+1'b1;else timer<=0;
  if((state==OP || state==HEX || state==DROP) && (rx_error || timer>=CLOCK_HZ/4-1))begin state<=IDLE;timer<=0;end
  else case(state)
   IDLE:if(rx_valid && rx_data=="!")begin state<=OP;timer<=0;payload<=0;seq<=0;received<=0;half<=0;len<=0;end
   OP:if(rx_valid)begin op<=rx_data;checksum<=rx_data;state<=HEX;timer<=0;end
   HEX:if(rx_valid)begin
    timer<=0;
    if(rx_data==10)begin
     if(half || received!=len+3)reply_error(1);
     else if(checksum!=0)reply_error(5);
     else state<=PRECHECK;
    end else if(!ishex || received>=35)state<=DROP;
    else if(!half)begin high_nibble<=nibble;half<=1;end
    else begin
     half<=0;received<=received+1'b1;checksum<=checksum+byte_in;
     if(received==0)seq<=byte_in;
     else if(received==1)begin len<=byte_in;if(byte_in>32)state<=DROP;end
     else if(received<len+2)payload[(received-2)*8+:8]<=byte_in;
    end
   end
   DROP:if(rx_valid)begin timer<=0;if(rx_data==10)reply_error(1);end
   PRECHECK:begin match_cached<=cached && op==last_op && seq==last_seq && len==last_req_len && payload==last_payload;state<=EXEC;end
   EXEC:begin
    response<=0;response_len<=1;sum<=8'h72+seq+8'd1;crc_index<=0;cache_this<=1;state<=CRC;
    if(match_cached)begin
     response<=last_response;response_len<=last_len;sum<=8'h72+seq+last_len;cache_this<=0;
    end else case(op)
     "C":if(len!=32)reply_error(1);else if(game_active)reply_error(2);else if(invalid_chart)reply_error(4);
       else begin state<=CHECK_CHART;check_index<=0;note_count<=0;end
     "M":if(len!=8)reply_error(1);else if(game_active || |pressed)reply_error(2);else if(invalid_map)reply_error(4);
       else begin for(m=0;m<8;m=m+1)keymap[m*7+:7]<=payload[m*8+:7];map_enabled<=1;end
     "D":if(len!=0)reply_error(1);else if(game_active || |pressed)reply_error(2);else begin chart_enabled<=0;map_enabled<=0;chart_disable<=1;uploading<=0;title_valid<=0;title_cursor<=0;end
     "U":if(len!=2)reply_error(1);else if(game_active)reply_error(2);else if(payload[15:0]==0 || payload[15:0]>1024)reply_error(4);
       else begin title_valid<=0;title_cursor<=0;uploading<=1;upload_total<=payload[10:0];upload_cursor<=0;chart_begin<=1;chart_count<=payload[10:0];end
     "V":if(game_active)reply_error(2);else if(!uploading)reply_error(3);
       else if(packet_events==0)reply_error(1);
       else if(payload[15:0]!=upload_cursor || packet_end>{1'b0,upload_total})reply_error(4);
       else begin event_index<=0;event_count<=packet_events;state<=VALIDATE_EVENTS;end
     "Z":if(len!=0)reply_error(1);else if(game_active)reply_error(2);else if(!uploading || upload_cursor!=upload_total)reply_error(3);
       else begin chart_commit<=1;uploading<=0;chart_enabled<=0;title_valid<=title_cursor==512;end
     "N":if(game_active)reply_error(2);else if(!uploading)reply_error(3);
       else if(len<3 || len>32)reply_error(1);
       else if(payload[15:0]!={6'd0,title_cursor} || {6'd0,title_cursor}+{8'd0,len}-16'd2>512)reply_error(4);
       else begin title_index<=2;state<=WRITE_TITLE;end
     "J":if(len!=0)reply_error(1);else if(stream_recording)reply_error(2);else stream_start<=1;
     "K":if(len!=0)reply_error(1);else stream_stop<=1;
     "P":if(len!=1)reply_error(1);else if(payload[7:2]!=0)reply_error(4);else if(game_active || |pressed)reply_error(2);else pluck_config<=payload[1:0];
     "E":if(len!=9)reply_error(1);else if(game_active || |pressed)reply_error(2);
       else if(payload[7:1]!=0 || payload[23] || payload[39] || payload[55] || payload[71] || payload[22:8]==0 || payload[38:24]==0 || payload[70:56]==0)reply_error(4);
       else adsr_config<={payload[0],payload[70:56],payload[54:40],payload[38:24],payload[22:8]};
     "F":if(len!=1)reply_error(1);else if(payload[7:2]!=0)reply_error(4);else begin extra_fx<=payload[1:0];extra_fx_write<=1;end
     "B":if(len!=0)reply_error(1);else if(recording)reply_error(2);else record_start<=1;
     "S":if(len!=0)reply_error(1);else record_stop<=1;
     "H":if(len!=0)reply_error(1);else begin
       response[15:8]<=14;response[23:16]<={4'd0,map_enabled,chart_enabled,clip_ready,recording};response[39:24]<=clip_count;
       response[55:40]<=16'd12012;response_len<=7;sum<=8'h72+seq+8'd7;
     end
     "G":if(len!=2)reply_error(1);else if(recording)reply_error(2);else if(!clip_ready)reply_error(3);
      else if(payload[15:0]>=clip_count)reply_error(4);else begin
       read_address<=payload[14:0];read_index<=0;
       read_count<=clip_remaining>=16'd32 ? 6'd32:clip_remaining[5:0];state<=FETCH;
      end
     default:reply_error(1);
    endcase
   end
   CHECK_CHART:begin
    if(note_count+popcount(check_byte)>64)reply_error(4);
    else if(check_index==31)begin
     uploading<=0;title_valid<=0;title_cursor<=0;
     if(LEGACY_CHART)begin chart_data<=payload;chart_enabled<=1;chart_disable<=1;state<=CRC;end
     else begin chart_begin<=1;chart_count<=32;check_index<=0;state<=WRITE_LEGACY;end
    end
    else begin check_index<=check_index+1'b1;note_count<=note_count+popcount(check_byte);end
   end
   WRITE_LEGACY:begin
    chart_write<=1;chart_address<={4'd0,check_index};chart_event<={16'd500,check_byte};
    if(check_index==31)state<=COMMIT_LEGACY;else check_index<=check_index+1'b1;
   end
   COMMIT_LEGACY:begin chart_commit<=1;chart_enabled<=1;state<=CRC;end
   VALIDATE_EVENTS:if(selected_event[23:8]<20 || selected_event[23:8]>60000)reply_error(4);
    else if(event_index+1==event_count)begin event_index<=0;state<=WRITE_EVENTS;end
    else event_index<=event_index+1'b1;
   WRITE_EVENTS:begin
    chart_write<=1;chart_address<=upload_cursor[9:0];chart_event<=selected_event;upload_cursor<=upload_cursor+1'b1;
    if(event_index+1==event_count)state<=CRC;else event_index<=event_index+1'b1;
   end
   WRITE_TITLE:begin
    title_write<=1;title_address<=title_cursor[8:0];title_data<=payload[title_index*8+:8];title_cursor<=title_cursor+1'b1;
    if(title_index+1==len)state<=CRC;else title_index<=title_index+1'b1;
   end
   FETCH:state<=WAIT_READ;
   WAIT_READ:begin
    response[(read_index+1)*8+:8]<=read_data;
    if(read_index+1==read_count)begin response_len<=read_count+1'b1;sum<=8'h72+seq+read_count+1'b1;crc_index<=0;state<=CRC;end
    else begin read_index<=read_index+1'b1;read_address<=read_address+1'b1;state<=FETCH;end
   end
   CRC:if(crc_index<response_len)begin sum<=sum+response[crc_index*8+:8];crc_index<=crc_index+1'b1;end
    else begin
     tx_checksum<=-sum;tx_index<=0;state<=TX;
     if(cache_this)begin cached<=1;last_op<=op;last_seq<=seq;last_req_len<=len;last_payload<=payload;last_response<=response;last_len<=response_len;end
    end
   TX:if(tx_ready)begin if(tx_index==8+2*response_len)state<=IDLE;else tx_index<=tx_index+1'b1;end
   default:state<=IDLE;
  endcase
 end
endmodule
