`timescale 1ns/1ps
module rhythm_game #(parameter integer CLOCK_HZ=50000000,REMOTE=1,CUSTOM_CHART=0,TIMED_CHART=0,PHYSICAL_CONTROL=0)(
 input wire remote_valid,remote_toggle,input wire[7:0] remote_keys,input wire local_inhibit,
 input wire clk,rst_n,frame_valid,test_mode,input wire[7:0] keys,pressed,
 output reg active,running,done,output wire wait_mode,output wire[1:0] song,tempo,
 output wire[4:0] step_index,output wire[2:0] count_in,
 output wire[7:0] hits,output reg[7:0] misses,wrong,
 output wire[7:0] target,next_target,light_target,output wire beat_flash,
 output reg exit_pulse,output wire[47:0] status,output wire[127:0] game_data,input[255:0] user_chart,input chart_enabled,
 input timed_enabled,input[10:0] timed_count,input[39:0] timed_masks,input[79:0] timed_durations,input timed_ready,
 output[9:0] timed_position,output signed[17:0] due_delta,input panel_click,output reg[2:0] led_event,output reg[7:0] led_mask);
 `include "rtl/rhythm_chart.vh"
 localparam integer MS_CYCLES=CLOCK_HZ/1000;
 reg[31:0] divider,hold_count;
 reg[15:0] time_ms,points;
 reg[1:0] difficulty;reg[15:0] beat_elapsed;
 wire builtin=!timed && !(CUSTOM_CHART && chart_enabled);
 wire choose_speed=active && builtin && (action==1 || action==2 || action==4);
 wire[15:0] quarter_ms=difficulty==0?16'd1000:difficulty==2?16'd250:16'd500;
 wire[15:0] note_ms=builtin?(chart_long(position)?quarter_ms<<1:quarter_ms):16'd500;
 reg[9:0] position;reg intro_done;
 wire timed=TIMED_CHART && timed_enabled;
 wire cache_ready=!timed || timed_ready;
 assign timed_position=position;
 assign due_delta=$signed({2'b0,due})-$signed({2'b0,time_ms});
 wire[15:0] window_ms=timed && timed_durations[15:0]<480 ? timed_durations[15:0]>>2 : 16'd120;
 wire[15:0] perfect_ms=window_ms<50?window_ms:16'd50;
 wire signed[17:0] next_due=due_delta+$signed({2'b0,timed_durations[15:0]});
 function[7:0] sat8;input[8:0] v;begin sat8=v[8]?8'hff:v[7:0];end endfunction
 function[15:0] sat16;input[19:0] v;begin sat16=|v[19:16]?16'hffff:v[15:0];end endfunction
 reg[7:0] hit_mask,perfect,good,combo,max_combo;
 reg[7:0] correct_held;
 reg[7:0] previous_keys,accepted,stable_keys,command,previous_pressed;
 reg have_previous,hold_consumed,started;
 reg[2:0] judgment;reg[9:0] judgment_age;
 wire local_locked=REMOTE && local_inhibit;
 // A physical command wins a same-cycle remote command; never queue a
 // conflicting remote toggle to undo a local pause/exit on the next cycle.
 wire local_fire=!local_locked && command!=0;
 wire button_fire=PHYSICAL_CONTROL && panel_click && !test_mode;
 wire button_enter=button_fire && !active;
 wire[7:0] action=button_fire?8'h10:local_fire?command:((REMOTE && remote_valid)?remote_keys:8'd0);
 wire local_toggle=!local_locked && !test_mode && stable_keys==8'h40 && !hold_consumed && hold_count==CLOCK_HZ-1;
 wire toggle_mode=!button_fire && (local_toggle || (REMOTE && remote_toggle && !test_mode && !local_fire));
 wire[7:0] rise=pressed & ~previous_pressed;
 reg[7:0] expected_reg;wire[7:0] expected=timed?timed_masks[7:0]:expected_reg;
 wire[7:0] expected_current=timed?timed_masks[7:0]:(CUSTOM_CHART && chart_enabled)?user_chart[position[4:0]*8+:8]:chart(position);
 wire[7:0] expected_first=timed?timed_masks[7:0]:(CUSTOM_CHART && chart_enabled)?user_chart[7:0]:chart(0);
 wire[7:0] expected_next=timed?timed_masks[15:8]:(CUSTOM_CHART && chart_enabled)?user_chart[(position+6'd1)*8+:8]:chart(position+6'd1);
 reg[15:0] due;
 wire in_window=cache_ready && due_delta<=$signed({2'b0,window_ms}) && due_delta>=-$signed({2'b0,window_ms});
 wire in_perfect=due_delta<=$signed({2'b0,perfect_ms}) && due_delta>=-$signed({2'b0,perfect_ms});
 wire[7:0] valid_hits=in_window?(rise & expected & ~hit_mask):8'd0;
 wire[7:0] bad_hits=(cache_ready?rise:8'd0) & ~(in_window?expected:8'd0);
 function[3:0] pop;input[7:0] v;reg[1:0] a,b,c,d;reg[2:0] e,f;begin
a={1'b0,v[0]}+v[1];b={1'b0,v[2]}+v[3];c={1'b0,v[4]}+v[5];d={1'b0,v[6]}+v[7];
e={1'b0,a}+b;f={1'b0,c}+d;pop={1'b0,e}+f;end endfunction
 wire[3:0] n=pop(valid_hits);
 wire[7:0] new_combo=sat8({1'b0,combo}+n);
 assign wait_mode=0;assign song=timed?1:0;assign tempo=difficulty;
 assign step_index=position[4:0];
 assign count_in=active && started && !intro_done && time_ms<2000 ? (time_ms<500?3'd4:time_ms<1000?3'd3:time_ms<1500?3'd2:3'd1):3'd0;
 assign hits=sat8({1'b0,perfect}+good);
 assign target=active && !done && cache_ready?expected & ~hit_mask:8'd0;
 // Keep successful held notes green even after the chart advances.
 // This feedback mask must not feed the scoring/remaining-note target.
 assign light_target=active ? target | correct_held : 8'd0;
 assign next_target=active && !done && cache_ready && (timed?({1'b0,position}+1<timed_count):position<(builtin?41:31)) ? expected_next:8'd0;
 assign beat_flash=active && running && beat_elapsed<16'd64;
 assign status={1'b0,wrong,misses,hits,count_in,step_index,tempo,song,wait_mode,done,running,active};
 assign game_data={27'd0,started,wrong,misses,good,perfect,max_combo,combo,points,judgment,done,running,active,hit_mask,position[5:0],time_ms};
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
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
 led_event<=0;led_mask<=0;beat_elapsed<=0;difficulty<=1;expected_reg<=chart(0);active<=0;running<=0;done<=0;started<=0;divider<=0;time_ms<=0;position<=0;intro_done<=0;due<=16'd2000;
 hit_mask<=0;correct_held<=0;perfect<=0;good<=0;misses<=0;wrong<=0;points<=0;combo<=0;max_combo<=0;
 judgment<=0;judgment_age<=0;hold_count<=0;hold_consumed<=0;previous_pressed<=0;exit_pulse<=0;
 end else begin
 led_event<=0;led_mask<=0;
 if(cache_ready)begin expected_reg<=expected_current;previous_pressed<=pressed;end exit_pulse<=0;
 correct_held<=correct_held & pressed;
 if(stable_keys!=8'h40 || test_mode || local_locked)begin hold_count<=0;hold_consumed<=0;end
 else if(!hold_consumed)begin
  if(local_toggle)hold_consumed<=1;else hold_count<=hold_count+1'b1;
 end
 if(choose_speed || button_enter || toggle_mode || (active && action==8'h20) || (active && action==8'h10 && (done || !started)))begin
  beat_elapsed<=0;expected_reg<=expected_first;divider<=0;time_ms<=0;position<=0;intro_done<=0;due<=16'd2000;hit_mask<=0;perfect<=0;good<=0;misses<=0;wrong<=0;
  points<=0;combo<=0;max_combo<=0;judgment<=0;judgment_age<=0;done<=0;correct_held<=0;
  if(choose_speed)begin difficulty<=action==1?0:action==4?2:1;running<=0;started<=0;end
  else if(button_enter)begin active<=1;running<=1;started<=1;end
  else if(toggle_mode)begin active<=!active;running<=0;started<=0;if(active)exit_pulse<=1;end
  else begin running<=action==8'h10;started<=action==8'h10;end
 end else if(active && action==8'h80)begin active<=0;running<=0;exit_pulse<=1;correct_held<=0;end
 else if(active && action==8'h10)running<=!running;
 else if(active && running)begin
  if(divider==MS_CYCLES-1)begin
   beat_elapsed<=beat_elapsed+1>=(builtin?quarter_ms:16'd500)?16'd0:beat_elapsed+1'b1;
   divider<=0;if(time_ms!=65535)time_ms<=time_ms+1'b1;if(time_ms>=1999)intro_done<=1;
   if(judgment_age<500)judgment_age<=judgment_age+1'b1;else judgment<=0;
  end else divider<=divider+1'b1;
  // Fresh edges only. Chord fingers are assessed independently in the same window.
  if(n!=0)begin
   led_event<=in_perfect?3'd1:3'd2;led_mask<=valid_hits;
   correct_held<=(correct_held & pressed) | valid_hits;
   hit_mask<=hit_mask|valid_hits;
   if(in_perfect)begin perfect<=sat8({1'b0,perfect}+n);points<=sat16({4'd0,points}+n*20'd1000);judgment<=1;end
   else begin good<=sat8({1'b0,good}+n);points<=sat16({4'd0,points}+n*20'd600);judgment<=2;end
   combo<=new_combo;if(new_combo>max_combo)max_combo<=new_combo;judgment_age<=0;
  end
  if(|bad_hits)begin led_event<=4;led_mask<=0; if(wrong!=255)wrong<=wrong+1'b1;combo<=0;judgment<=4;judgment_age<=0;end
  if(cache_ready && (due_delta<-$signed({2'b0,window_ms}) || ((hit_mask|valid_hits)==expected && expected!=0)))begin
   if((expected & ~(hit_mask|valid_hits))!=0)begin
    led_event<=|bad_hits?3'd4:3'd3;led_mask<=0;
    misses<=sat8({1'b0,misses}+pop(expected & ~(hit_mask|valid_hits)));combo<=0;judgment<=3;judgment_age<=0;
   end
   hit_mask<=0;
   if(timed?({1'b0,position}+1>=timed_count):position==(builtin?41:31))begin done<=1;running<=0;end
   else begin expected_reg<=expected_next;position<=position+1'b1;
    if(timed)begin due<=next_due<0?16'd0:next_due[15:0];time_ms<=0;intro_done<=1;end
    else due<=due+note_ms;
   end
  end
 end
 end
endmodule
