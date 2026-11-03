`timescale 1ns/1ps
// Control path only. Vote WHOLE one-hot samples, never independent bits.
// Five-frame window, >=4 identical samples. Conflicts clear the old key;
// a stable new key can recover WITHOUT requiring an all-zero frame.
module touch_command_guard #(
 parameter integer STABLE_FRAMES=4, RELEASE_FRAMES=3, TEST_FRAMES=360,
 parameter integer TIMEOUT_CYCLES=500000, CRITICAL_FRAMES=3,
 parameter integer CONFLICT_FRAMES=3
)(input wire clk,rst_n,frame_valid,slow_test,
 input wire [7:0] raw_keys,output reg valid,output reg [7:0] keys);
 localparam integer CW=$clog2(TEST_FRAMES+RELEASE_FRAMES+CRITICAL_FRAMES+CONFLICT_FRAMES+2);
 localparam integer TW=$clog2(TIMEOUT_CYCLES+1);
 localparam [CW-1:0] RELEASE_LIMIT=RELEASE_FRAMES-1,
   TEST_LIMIT=TEST_FRAMES-1, CRITICAL_LIMIT=CRITICAL_FRAMES-1,
   CONFLICT_LIMIT=CONFLICT_FRAMES-1;
 localparam [TW-1:0] TIMEOUT_LIMIT=TIMEOUT_CYCLES-1;
 reg [7:0] history[0:3];
 reg [7:0] candidate,pending,blocked_key;
 reg [CW-1:0] release_count,bad_count,confirm_count,test_count;
 reg [TW-1:0] age;
 reg accepted;
 wire single_key=(raw_keys!=0) && ((raw_keys & (raw_keys-8'd1))==0);
 wire [2:0] votes=3'd1+{2'd0,(history[0]==raw_keys)}+
   {2'd0,(history[1]==raw_keys)}+{2'd0,(history[2]==raw_keys)}+
   {2'd0,(history[3]==raw_keys)};
 wire qualified=single_key && raw_keys!=blocked_key && votes>=STABLE_FRAMES;
 integer i;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   valid<=0;keys<=0;candidate<=0;pending<=0;release_count<=0;
   bad_count<=0;confirm_count<=0;test_count<=0;age<=0;accepted<=0;blocked_key<=0;
   for(i=0;i<4;i=i+1)history[i]<=0;
  end else begin
   valid<=0;
   if(frame_valid)begin
    valid<=1;age<=0;
    history[0]<=raw_keys;
    for(i=1;i<4;i=i+1)history[i]<=history[i-1];
    if(raw_keys==0)begin
     if(release_count>=RELEASE_LIMIT)blocked_key<=0;
     if(release_count<RELEASE_LIMIT)release_count<=release_count+1'b1;
    end else release_count<=0;
    if(accepted)begin
     // Short glitches retain the held key; sustained conflict clears it.
     // Fresh voting then allows rollover, as the 764A controls did.
     if(raw_keys==candidate)begin bad_count<=0;keys<=candidate;end
     else begin
      if(bad_count<CONFLICT_LIMIT)bad_count<=bad_count+1'b1;
      if((raw_keys==0 && release_count>=RELEASE_LIMIT) || bad_count>=CONFLICT_LIMIT)begin
       keys<=0;accepted<=0;candidate<=0;pending<=0;confirm_count<=0;test_count<=0;bad_count<=0;
       for(i=0;i<4;i=i+1)history[i]<=0;
      end
     end
    end else begin
     keys<=0;
     if(raw_keys==0 && release_count>=RELEASE_LIMIT)begin
      pending<=0;confirm_count<=0;test_count<=0;
      for(i=0;i<4;i=i+1)history[i]<=0;
     end else begin
      // Auto test audio still requires uninterrupted T5, not accumulated taps.
      if(raw_keys==8'h10 && slow_test)begin
       pending<=0;confirm_count<=0;
       if(test_count<TEST_LIMIT)test_count<=test_count+1'b1;
       else if(qualified)begin keys<=raw_keys;candidate<=raw_keys;blocked_key<=raw_keys;accepted<=1;bad_count<=0;end
      end else begin
       test_count<=0;
       if(qualified)begin
        // Game T5 toggles state: require 3 consecutive qualified windows.
        if(raw_keys==8'h10)begin
         if(pending!=raw_keys)begin pending<=raw_keys;confirm_count<=1;end
         else if(confirm_count<CRITICAL_LIMIT)confirm_count<=confirm_count+1'b1;
         else begin keys<=raw_keys;candidate<=raw_keys;blocked_key<=raw_keys;accepted<=1;bad_count<=0;end
        end else begin keys<=raw_keys;candidate<=raw_keys;blocked_key<=raw_keys;accepted<=1;bad_count<=0;pending<=0;confirm_count<=0;end
       end else begin pending<=0;confirm_count<=0;end
      end
     end
    end
   end else if(age<TIMEOUT_LIMIT)age<=age+1'b1;
   else begin
    valid<=1;keys<=0;candidate<=0;pending<=0;release_count<=0;
    bad_count<=0;confirm_count<=0;test_count<=0;accepted<=0;blocked_key<=0;
    for(i=0;i<4;i=i+1)history[i]<=0;
   end
  end
 end
endmodule
