`timescale 1ns/1ps
// Entire lesson clock, score ROM and assessment run in FPGA without host input.
// Hold touch 7 for one second to enter (outside FFT); touch 8 exits.
module offline_trainer #(parameter integer CLOCK_HZ=50000000,REMOTE=0)(
 input wire remote_valid,remote_toggle,input wire[7:0] remote_keys,input wire local_inhibit,
 input wire clk,rst_n,frame_valid,test_mode,input wire[7:0] keys,pressed,
 output reg active,running,done,wait_mode,output reg[1:0] song,tempo,
 output reg[4:0] step_index,output reg[2:0] count_in,
 output reg[7:0] hits,misses,wrong,
 output wire[7:0] target,next_target,output wire beat_flash,
 output reg exit_pulse,output wire[47:0] status);
 wire local_locked=REMOTE && local_inhibit;
 wire[7:0] action=(REMOTE && remote_valid) ? remote_keys : (local_locked ? 8'd0 : command);
 reg[7:0] previous_keys,accepted,stable_keys,command,previous_pressed;
 reg have_previous,hold_consumed,step_hit,started;
 reg[31:0] hold_count,timer;
 wire[31:0] beat_cycles=tempo==0 ? CLOCK_HZ : tempo==1 ? (CLOCK_HZ/3)*2 : CLOCK_HZ/2;
 wire[7:0] rise=pressed & ~previous_pressed;
 // Each 16-step score fits the existing C5..C6 pressure-pad layout.
 function[7:0] score;
 input[1:0] tune;input[4:0] pos;
 begin
 score=0;
 if(pos<16)case(tune)
  0:case(pos)
   0,14:score=1;1,13:score=2;2,12:score=4;3,11:score=8;
   4,10:score=16;5,9:score=32;6,8:score=64;7:score=128;default:score=0;
  endcase
  1:case(pos)
   0,4,8,12:score=8'h15;1,5,9,13:score=8'h2a;2,6,10,14:score=8'h52;default:score=0;
  endcase
  2:case(pos)
   0,1,8:score=1;3,10,11:score=4;4,5,12:score=16;7,14:score=128;default:score=0;
  endcase
  default:score=0;
 endcase
 end endfunction
 wire[7:0] expected=score(song,step_index);
 // Rhythm score: step 7 and 15 last two beats; other steps one beat.
 wire double_beat=song==2 && (step_index==7 || step_index==15);
 wire[31:0] step_cycles=double_beat ? beat_cycles<<1 : beat_cycles;
 assign target=active && !done && count_in==0 ? expected : 0;
 assign next_target=active && step_index<15 ? score(song,step_index+1'b1) : 0;
 assign beat_flash=active && running && ((timer<beat_cycles/8) || (double_beat && count_in==0 && timer>=beat_cycles && timer<beat_cycles+beat_cycles/8));
 assign status={1'b0,wrong,misses,hits,count_in,step_index,tempo,song,wait_mode,done,running,active};
 function[7:0] inc;input[7:0] value;begin inc=value==255 ? value : value+1'b1;end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin previous_keys<=0;accepted<=0;stable_keys<=0;command<=0;have_previous<=0;end
 else begin
  command<=0;
  if(frame_valid && !local_locked)begin
   previous_keys<=keys;have_previous<=1;
   if(have_previous && previous_keys==keys)begin
    stable_keys<=keys;
    if(keys==0)accepted<=0;
    else if((keys & (keys-8'd1))==0 && keys!=accepted)begin command<=keys;accepted<=keys;end
   end
  end
 end
 // No automatic playing: the human pressure inputs always remain the sound source.
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  active<=0;running<=0;done<=0;wait_mode<=0;song<=0;tempo<=1;step_index<=0;
  count_in<=0;hits<=0;misses<=0;wrong<=0;exit_pulse<=0;
  hold_count<=0;hold_consumed<=0;timer<=0;step_hit<=0;previous_pressed<=0;started<=0;
 end else begin
  previous_pressed<=pressed;exit_pulse<=0;
  if(!local_locked)begin
  if(stable_keys!=8'h40 || test_mode)begin hold_count<=0;hold_consumed<=0;end
  else if(!hold_consumed)begin
   if(hold_count==CLOCK_HZ-1)begin
    hold_consumed<=1;active<=!active;running<=0;done<=0;step_index<=0;count_in<=0;
    hits<=0;misses<=0;wrong<=0;timer<=0;step_hit<=0;started<=0;
    if(active)exit_pulse<=1;
   end else hold_count<=hold_count+1'b1;
  end
  end
  if(active)begin
   if(action==8'h80)begin active<=0;running<=0;count_in<=0;exit_pulse<=1;end
   else if(action==8'h20)begin running<=0;done<=0;step_index<=0;count_in<=0;timer<=0;step_hit<=0;hits<=0;misses<=0;wrong<=0;started<=0;end
   else if(action==8'h10)begin
    running<=!running;
    if(done || !started)begin
     started<=1;done<=0;step_index<=0;count_in<=4;timer<=0;step_hit<=0;hits<=0;misses<=0;wrong<=0;
    end
   end
   else if(!running && (action==1 || action==2 || action==4 || action==8))begin
    if(action==1)song<=song==0 ? 2'd2 : song-2'd1;
    if(action==2)song<=song==2 ? 2'd0 : song+2'd1;
    if(action==4)tempo<=tempo==2 ? 2'd0 : tempo+2'd1;
    if(action==8)wait_mode<=!wait_mode;
    done<=0;step_index<=0;count_in<=0;timer<=0;step_hit<=0;hits<=0;misses<=0;wrong<=0;started<=0;
   end
   else if(running)begin
    if(count_in!=0)begin
     if(timer==beat_cycles-1)begin timer<=0;count_in<=count_in-1'b1;end else timer<=timer+1'b1;
    end else begin
     if(|(rise & ~expected))wrong<=inc(wrong);
     // A held pad from the preceding step cannot score a repeated note.
     // Chords allow finger skew, but all requested pads and no extra pads must be down.
     if(expected!=0 && |(rise & expected) && pressed==expected && !step_hit &&
        (wait_mode || timer<beat_cycles/4))begin step_hit<=1;hits<=inc(hits);end
     if((wait_mode && expected!=0 && step_hit && pressed==0) ||
        ((!wait_mode || expected==0) && timer==step_cycles-1))begin
      if(!wait_mode && expected!=0 && !step_hit)misses<=inc(misses);
      timer<=0;step_hit<=0;
      if(step_index==15)begin done<=1;running<=0;end else step_index<=step_index+1'b1;
     end else if(!wait_mode || expected==0)timer<=timer+1'b1;
    end
   end
  end
  if(REMOTE && remote_toggle && !test_mode)begin
   active<=!active;running<=0;done<=0;step_index<=0;count_in<=0;
   hits<=0;misses<=0;wrong<=0;timer<=0;step_hit<=0;started<=0;
   hold_count<=0;hold_consumed<=1;
   if(active)exit_pulse<=1;
  end

 end
endmodule
