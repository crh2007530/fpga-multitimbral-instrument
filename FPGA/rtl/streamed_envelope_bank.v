`timescale 1ns/1ps
// Frame-scheduled independent envelopes. Two RAM lanes, one state per voice.
// Contract: note events are settled before sample_ce and remain quiet through
// sample_ce+3 (the legacy snapshot aperture). The top-level FRAME_CONTROL path
// meets this contract; musical controls are committed at I2S frame start.
module streamed_envelope_bank #(parameter VOICES=128,LANES=2)(
 input clk,rst_n,sample_ce,input[VOICES-1:0]note_on,note_off,
 input diagnostic,slow_release,
 output wire[LANES*16-1:0]stream_levels,output reg[VOICES-1:0]active,
 output reg fault,output wire stream_valid,output wire[$clog2(VOICES/LANES)-1:0]stream_index);
 localparam GROUP=VOICES/LANES,AW=$clog2(GROUP);
 reg[VOICES-1:0]pending_on,pending_off,pending_test,pending_slow;
 reg[VOICES-1:0]frame_on,frame_off,frame_test,frame_slow,frame_skip;
 assign stream_valid=rst_n && read_valid;
 assign stream_index=read_index;
 reg scanning,read_valid;reg[AW-1:0]index,read_index;
 reg[2:0]aperture;integer v;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  pending_on<=0;pending_off<=0;pending_test<=0;pending_slow<=0;
  frame_on<=0;frame_off<=0;frame_test<=0;frame_slow<=0;frame_skip<=0;
  scanning<=0;read_valid<=0;index<=0;read_index<=0;fault<=0;aperture<=0;
 end else begin
  read_valid<=scanning;read_index<=index;aperture<={aperture[1:0],sample_ce};
  if((|aperture) && (|(note_on|note_off)))fault<=1;
  if(sample_ce)begin
   if(scanning || read_valid)fault<=1;
   scanning<=1;index<=0;
  end else if(scanning)begin
   if(index==GROUP-1)scanning<=0;else index<=index+1'b1;
  end
  for(v=0;v<VOICES;v=v+1)begin
   if(sample_ce)begin
    frame_on[v]<=pending_on[v] || note_on[v];
    frame_off[v]<=!note_on[v] && (pending_off[v] || note_off[v]);
    frame_test[v]<=note_on[v]?diagnostic:pending_test[v];
    frame_slow[v]<=note_on[v]?slow_release:pending_slow[v];
    frame_skip[v]<=note_on[v] || note_off[v];
    pending_on[v]<=0;pending_off[v]<=0;
   end else if(note_on[v])begin
    pending_on[v]<=1;pending_off[v]<=0;pending_test[v]<=diagnostic;pending_slow[v]<=slow_release;
   end else if(note_off[v])pending_off[v]<=1;
  end
 end
 // Packed state: amplitude[14:0], state[17:15], divider[20:18],
 // diagnostic[21], slow musical release[22]. Same arithmetic as instrument_env.
 function[22:0]next_state;
 input[22:0]old;input on_event,off_event,new_test,new_slow,skip_sample;
 reg[14:0]a,base;reg[2:0]s,d;reg t,slow;reg skip;
 begin
  a=old[14:0];s=old[17:15];d=old[20:18];t=old[21];slow=old[22];
  skip=skip_sample && (on_event || (off_event && s!=0));
  if(on_event)begin t=new_test;slow=new_slow;d=0;s=new_test?1:3;if(!new_test)a=32767;end
  if(off_event && s!=0)s=4;
  if(!skip)begin
   base=slow?{9'd0,a[14:9]}:{8'd0,a[14:8]};
   case(s)
    0:a=0;
    1:if(a>=32630)begin a=32767;s=2;end else a=a+15'd137;
    2:if(a<=19667)begin a=19660;s=3;end else a=a-15'd7;
    3:a=t?15'd19660:15'd32767;
    4:if(t)begin if(a<=9)begin a=0;s=0;end else a=a-15'd9;end
      else if(d==0)begin if(a<=1)begin a=0;s=0;end else a=a-base-15'd1;end
    default:begin s=0;a=0;end
   endcase
   d=d+1'b1;
  end
  next_state={slow,t,d,s,a};
 end endfunction
 genvar g;
 generate for(g=0;g<LANES;g=g+1)begin:lane
  reg[GROUP-1:0]initialized;
  wire[35:0]q;
  wire[22:0]previous=initialized[read_index]?q[22:0]:23'd0;
  localparam[AW:0]BASE=g*GROUP;
  wire[AW:0]voice_index=BASE+{1'b0,read_index};
  wire[22:0]next=next_state(previous,frame_on[voice_index],frame_off[voice_index],frame_test[voice_index],frame_slow[voice_index],frame_skip[voice_index]);
  voice_state_ram #(.AW(AW)) ram(clk,scanning,read_valid,index,read_index,{13'd0,next},q);
  assign stream_levels[g*16+:16]={1'b0,next[14:0]};
  always @(posedge clk or negedge rst_n)
  if(!rst_n)begin initialized<=0;active[g*GROUP+:GROUP]<=0;end
  else if(read_valid)begin
   initialized[read_index]<=1;
   active[g*GROUP+read_index]<=next[17:15]!=0;
  end
 end endgenerate
endmodule
