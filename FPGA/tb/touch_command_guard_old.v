`timescale 1ns/1ps
// Control keys only: the pressure/audio path is not delayed.
// At the production 2.82ms scan interval: 8 frames ~=23ms, 360 ~=1.02s.
// Require a clean release at startup and between commands. T8 remains an
// escape even without a prior release. Long T5 applies only to test entry,
// not to lesson start/pause. Invalid overlaps cancel the current gesture.
module touch_command_guard_old #(
 parameter integer STABLE_FRAMES=8, RELEASE_FRAMES=8, TEST_FRAMES=360,
 parameter integer TIMEOUT_CYCLES=500000
)(input wire clk,rst_n,frame_valid,slow_test,
 input wire [7:0] raw_keys,output reg valid,output reg [7:0] keys);
 localparam integer CW=$clog2(TEST_FRAMES+STABLE_FRAMES+RELEASE_FRAMES+1);
 localparam integer TW=$clog2(TIMEOUT_CYCLES+1);
 localparam [CW-1:0] STABLE_LIMIT=STABLE_FRAMES-1,
   RELEASE_LIMIT=RELEASE_FRAMES-1, TEST_LIMIT=TEST_FRAMES-1;
 localparam [TW-1:0] TIMEOUT_LIMIT=TIMEOUT_CYCLES-1;
 reg [CW-1:0] count,release_count;
 reg [TW-1:0] age;
 reg [7:0] candidate;
 reg armed,accepted;
 wire single_key=(raw_keys!=0) && ((raw_keys & (raw_keys-8'd1))==0);
 wire [CW-1:0] threshold=(raw_keys==8'h10 && slow_test)?TEST_LIMIT:STABLE_LIMIT;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   valid<=0;keys<=0;count<=0;release_count<=0;age<=0;
   candidate<=0;armed<=0;accepted<=0;
  end else begin
   valid<=0;
   if(frame_valid)begin
    age<=0;valid<=1;
    if(raw_keys==0)begin
     keys<=0;candidate<=0;count<=0;accepted<=0;
     if(release_count<RELEASE_LIMIT)release_count<=release_count+1'b1;
     else armed<=1;
    end else begin
     release_count<=0;
     if(!single_key)begin
      keys<=0;candidate<=0;count<=0;accepted<=0;armed<=0;
     end else if(candidate!=raw_keys)begin
      keys<=0;candidate<=raw_keys;count<=1;accepted<=0;
      // A rollover after a dispatched command must not trigger another key.
      if(accepted)armed<=0;
     end else if(accepted)keys<=raw_keys;
     else if(armed || raw_keys==8'h80)begin
      if(count>=threshold)begin keys<=raw_keys;accepted<=1;armed<=0;end
      else count<=count+1'b1;
     end
    end
   end else if(age<TIMEOUT_LIMIT)age<=age+1'b1;
   else begin
    // A stopped scanner must not leave a held key in the lesson controller.
    valid<=1;keys<=0;candidate<=0;count<=0;release_count<=0;
    armed<=0;accepted<=0;
   end
  end
 end
endmodule

