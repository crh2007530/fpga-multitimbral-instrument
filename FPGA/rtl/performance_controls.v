`timescale 1ns/1ps
// Two identical frames confirm a key. Ignore multi-key overlap without
// consuming a command; accept a different stable single key on rollover.
// A held key fires once, and repeating that same key needs a confirmed release.
// 1/2/3 octave; 4 next target; 5 FFT toggle; 6 test mute;
// 7 ALL target (performance) / all four on (FFT); 8 safe return to normal.
module performance_controls #(parameter integer TEST_VOICES=64,EXPANSION=0,EXTERNAL_CLEAR=0,REMOTE=0)(input wire clk,rst_n,frame_valid,clear,
 input wire remote_valid,input wire[7:0] remote_keys,
 input wire [7:0] keys,output reg [15:0] modes,
 output reg [3:0] selected,output reg test_mode,output reg [3:0] test_mask,
 output wire [1:0] selected_mode,output reg [15:0] command_count,
 output reg [7:0] last_command, output reg chord_mode, test32,
 output reg [$clog2(TEST_VOICES)-1:0] selected_test, output reg [TEST_VOICES-1:0] mask32);
 reg [7:0] previous,last_accepted;reg have_previous;
 wire single_key=(keys!=0) && ((keys & (keys-8'd1))==0);
 wire remote_fire=REMOTE && remote_valid;
 wire local_fire=frame_valid && have_previous && previous==keys && single_key && keys!=last_accepted;
 wire[7:0] action=local_fire ? keys : remote_keys;
 integer i;
 assign selected_mode=test_mode ? 2'd0 : (selected<8 ? modes[selected*2+:2] : modes[1:0]);
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n || (EXTERNAL_CLEAR && clear))begin chord_mode<=0;test32<=0;selected_test<=0;mask32<={TEST_VOICES{1'b1}};modes<=0;selected<=8;test_mode<=0;test_mask<=15;previous<=0;have_previous<=0;last_accepted<=0;command_count<=0;last_command<=0;end
  else begin
   if(frame_valid)begin
    previous<=keys;have_previous<=1;
    if(have_previous && previous==keys)begin
     if(keys==0)last_accepted<=0;
     else if(single_key && keys!=last_accepted)last_accepted<=keys;
    end
   end
   // Physical controls win simultaneous remote commands. Remote-only commands
   // remain available and do not synthesize held touches.
   if(local_fire || remote_fire)begin
     if(!((test_mode && !(TEST_VOICES==128 && test32) && (action==1 || action==2 || action==4)) || (!test_mode && action==32 && !EXPANSION)))begin
      command_count<=command_count+1'b1;last_command<=action;
     end
     case(action)
      8'h01,8'h02,8'h04:if(TEST_VOICES==128 && test_mode && test32)begin
       if(action==1)selected_test<=0;
       else if(action==2)selected_test<=64;
       else selected_test<=selected_test-1'b1;
      end else if(!test_mode)begin
       for(i=0;i<8;i=i+1)if(selected==8 || selected==i)
        modes[i*2+:2]<=(action==1)?2'd1:(action==4)?2'd2:2'd0;
      end
      8'h08:if(EXPANSION && test_mode && test32)selected_test<=selected_test+1'b1;else selected <= test_mode ? ((selected>=3)?4'd0:selected+4'd1) : ((selected>=7)?4'd0:selected+4'd1);
      8'h10:begin test_mode<=!test_mode;selected<=0;test_mask<=15;selected_test<=0;mask32<={TEST_VOICES{1'b1}};test32<=EXPANSION && !test_mode && chord_mode;end
      8'h20:if(EXPANSION && !test_mode)chord_mode<=!chord_mode;
       else if(EXPANSION && test32)mask32[selected_test]<=!mask32[selected_test];
       else if(test_mode && selected<4)test_mask[selected]<=!test_mask[selected];
      8'h40:if(test_mode)begin test_mask<=15;mask32<={TEST_VOICES{1'b1}};end else selected<=8;
      8'h80:begin chord_mode<=0;test32<=0;selected_test<=0;mask32<={TEST_VOICES{1'b1}};test_mode<=0;selected<=8;modes<=0;test_mask<=15;end
      default:;
     endcase
   end
  end
 end
endmodule
