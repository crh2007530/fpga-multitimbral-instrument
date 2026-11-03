`timescale 1ns/1ps
module ui_press #(parameter FILTER=500000,LONG=35000000)(input clk,rst_n,key_n,output reg short_press,long_press);
 reg m,s,candidate,stable,armed,fired;reg[25:0] filter_count,hold_count;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin m<=1;s<=1;candidate<=1;stable<=1;armed<=0;fired<=0;filter_count<=0;hold_count<=0;short_press<=0;long_press<=0;end
 else begin
 m<=key_n;s<=m;short_press<=0;long_press<=0;
 if(s!=candidate)begin candidate<=s;filter_count<=0;end
 else if(filter_count<FILTER)filter_count<=filter_count+1'b1;
 else begin
 stable<=candidate;
 if(candidate)begin
 if(!stable && armed && !fired)short_press<=1;
 armed<=1;fired<=0;hold_count<=0;
 end else if(armed && !fired)begin
 if(hold_count==LONG-1)begin fired<=1;long_press<=1;end else hold_count<=hold_count+1'b1;
 end
 end
 end
endmodule

module mixer_controls(input clk,rst_n,blocked,open_event,next_event,prev_event,inc,dec,
 input[2:0] base_enable,output reg active,output reg[3:0] item,
 output reg[32:0] config_data,output[2:0] effective_enable,
 output reg[1:0] echo_preset,chorus_preset,output reg[2:0] edited,input remote_write,echo_event,echo_clear);
 reg[2:0] last_base,local_enable;reg[2:0] local_override;
 assign effective_enable=(local_enable & local_override) | (base_enable & ~local_override);
 wire up=inc && !dec,down=dec && !inc;
 wire[1:0] room_next=up?(config_data[13:12]==2?2'd0:config_data[13:12]+2'd1):(config_data[13:12]==0?2'd2:config_data[13:12]-2'd1);
 wire[1:0] echo_next=up?echo_preset+2'd1:echo_preset-2'd1;
 wire[1:0] chorus_next=up?(chorus_preset==2?2'd0:chorus_preset+2'd1):(chorus_preset==0?2'd2:chorus_preset-2'd1);
 function[4:0] gain_step;input[4:0] n;input u;begin gain_step=u?(n<16?n+1'b1:n):(n>0?n-1'b1:n);end endfunction
 function[1:0] tier_step;input[1:0] n;input u;begin tier_step=u?(n<2?n+1'b1:n):(n>0?n-1'b1:n);end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
 active<=0;item<=0;last_base<=0;local_enable<=0;local_override<=0;echo_preset<=1;chorus_preset<=0;edited<=0;
 config_data<={2'd0,2'd0,5'd4,3'd2,2'd0,5'd4,2'd0,2'd0,5'd4,5'd16};
 end else begin
 last_base<=base_enable;
 // A later gesture/app enable update takes precedence over panel enable choices.
 if(base_enable[0]!=last_base[0] || remote_write)local_override[0]<=0;
 if(base_enable[2]!=last_base[2] || remote_write)local_override[2]<=0;
 if(echo_event)begin local_enable[1]<=~effective_enable[1];local_override[1]<=1;end
 if(echo_clear)local_override[1]<=0;
 if(blocked)active<=0;else if(open_event)active<=~active;
 if(active && !blocked)begin
 if(next_event)item<=item==14?4'd0:item+4'd1;
 else if(prev_event)item<=item==0?4'd14:item-4'd1;
 if(up || down)case(item)
 0:begin local_enable[0]<=up;local_override[0]<=1;end
 1:begin
 config_data[13:12]<=room_next;config_data[11:10]<=room_next;
 config_data[9:5]<=room_next==0?5'd8:room_next==1?5'd12:5'd16;edited[0]<=0;
 end
 2:begin config_data[9:5]<=gain_step(config_data[9:5],up);edited[0]<=1;end
 3:begin config_data[11:10]<=tier_step(config_data[11:10],up);edited[0]<=1;end
 4:begin local_enable[1]<=up;local_override[1]<=1;end
 5:begin
 echo_preset<=echo_next;edited[1]<=0;
 config_data[20:19]<=echo_next<2?0:echo_next==2?1:2;
 config_data[23:21]<=echo_next==0?0:echo_next==1?2:echo_next==2?4:6;
 config_data[18:14]<=echo_next<2?4:6;
 end
 6:begin config_data[20:19]<=tier_step(config_data[20:19],up);edited[1]<=1;end
 7:begin config_data[23:21]<=up?(config_data[23:21]<6?config_data[23:21]+3'd1:3'd6):(config_data[23:21]>0?config_data[23:21]-3'd1:3'd0);edited[1]<=1;end
 8:begin config_data[18:14]<=gain_step(config_data[18:14],up);edited[1]<=1;end
 9:begin local_enable[2]<=up;local_override[2]<=1;end
 10:begin chorus_preset<=chorus_next;config_data[30:29]<=chorus_next;config_data[32:31]<=chorus_next;config_data[28:24]<=chorus_next==0?4:chorus_next==1?6:8;edited[2]<=0;end
 11:begin config_data[30:29]<=tier_step(config_data[30:29],up);edited[2]<=1;end
 12:begin config_data[32:31]<=tier_step(config_data[32:31],up);edited[2]<=1;end
 13:begin config_data[28:24]<=gain_step(config_data[28:24],up);edited[2]<=1;end
 14:config_data[4:0]<=gain_step(config_data[4:0],up);
 endcase
 end
 end
endmodule

// Independent live effect settings for each instrument; reset restores defaults.
module instrument_mixer_controls(input clk,rst_n,blocked,open_event,next_event,prev_event,inc,dec,
 input[2:0] base_enable,output reg active,output reg[3:0] item,
 output reg[32:0] config_data,output[2:0] effective_enable,
 output reg[1:0] echo_preset,chorus_preset,output reg[2:0] edited,input remote_write,echo_event,echo_clear,input[1:0] instrument,output reg[1:0] current_instrument);
 localparam[32:0] DEFAULT_CONFIG={2'd0,2'd0,5'd4,3'd2,2'd0,5'd4,2'd0,2'd0,5'd4,5'd16};
 reg[32:0] saved_config[0:2];reg[2:0] saved_enable[0:2],saved_edited[0:2];
 reg[1:0] saved_echo[0:2],saved_chorus[0:2];reg[2:0] saved_valid;
 wire[1:0] requested_instrument=instrument<3?instrument:2'd0;
 reg[2:0] last_base,local_enable;reg[2:0] local_override;
 assign effective_enable=(local_enable & local_override) | (base_enable & ~local_override);
 wire up=inc && !dec,down=dec && !inc;
 wire[1:0] room_next=up?(config_data[13:12]==2?2'd0:config_data[13:12]+2'd1):(config_data[13:12]==0?2'd2:config_data[13:12]-2'd1);
 wire[1:0] echo_next=up?echo_preset+2'd1:echo_preset-2'd1;
 wire[1:0] chorus_next=up?(chorus_preset==2?2'd0:chorus_preset+2'd1):(chorus_preset==0?2'd2:chorus_preset-2'd1);
 function[4:0] gain_step;input[4:0] n;input u;begin gain_step=u?(n<16?n+1'b1:n):(n>0?n-1'b1:n);end endfunction
 function[1:0] tier_step;input[1:0] n;input u;begin tier_step=u?(n<2?n+1'b1:n):(n>0?n-1'b1:n);end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
 current_instrument<=0;
 saved_valid<=3'b000;
 active<=0;item<=15;last_base<=0;local_enable<=0;local_override<=0;echo_preset<=1;chorus_preset<=0;edited<=0;
 config_data<={2'd0,2'd0,5'd4,3'd2,2'd0,5'd4,2'd0,2'd0,5'd4,5'd16};
 end else begin
 last_base<=base_enable;
 // A later gesture/app enable update takes precedence over panel enable choices.
 if(base_enable[0]!=last_base[0] || remote_write)local_override[0]<=0;
 if(base_enable[2]!=last_base[2] || remote_write)local_override[2]<=0;
 if(echo_event)begin local_enable[1]<=~effective_enable[1];local_override[1]<=1;end
 if(echo_clear)local_override[1]<=0;
 if(blocked)active<=0;else if(open_event)active<=~active;
 if(requested_instrument!=current_instrument)begin
 saved_valid[current_instrument]<=1'b1;
 config_data<=(saved_valid[requested_instrument]?saved_config[requested_instrument]:DEFAULT_CONFIG);local_enable<=(saved_valid[requested_instrument]?saved_enable[requested_instrument]:3'b000);local_override<=3'b111;
 edited<=(saved_valid[requested_instrument]?saved_edited[requested_instrument]:3'b000);echo_preset<=(saved_valid[requested_instrument]?saved_echo[requested_instrument]:2'd1);chorus_preset<=(saved_valid[requested_instrument]?saved_chorus[requested_instrument]:2'd0);
 current_instrument<=requested_instrument;
 end else if(active && !blocked)begin
 if(next_event)item<=item==15?4'd0:item+4'd1;
 else if(prev_event)item<=item==0?4'd15:item-4'd1;
 if(up || down)case(item)
 0:begin local_enable[0]<=up;local_override[0]<=1;end
 1:begin
 config_data[13:12]<=room_next;config_data[11:10]<=room_next;
 config_data[9:5]<=room_next==0?5'd8:room_next==1?5'd12:5'd16;edited[0]<=0;
 end
 2:begin config_data[9:5]<=gain_step(config_data[9:5],up);edited[0]<=1;end
 3:begin config_data[11:10]<=tier_step(config_data[11:10],up);edited[0]<=1;end
 4:begin local_enable[1]<=up;local_override[1]<=1;end
 5:begin
 echo_preset<=echo_next;edited[1]<=0;
 config_data[20:19]<=echo_next<2?0:echo_next==2?1:2;
 config_data[23:21]<=echo_next==0?0:echo_next==1?2:echo_next==2?4:6;
 config_data[18:14]<=echo_next<2?4:6;
 end
 6:begin config_data[20:19]<=tier_step(config_data[20:19],up);edited[1]<=1;end
 7:begin config_data[23:21]<=up?(config_data[23:21]<6?config_data[23:21]+3'd1:3'd6):(config_data[23:21]>0?config_data[23:21]-3'd1:3'd0);edited[1]<=1;end
 8:begin config_data[18:14]<=gain_step(config_data[18:14],up);edited[1]<=1;end
 9:begin local_enable[2]<=up;local_override[2]<=1;end
 10:begin chorus_preset<=chorus_next;config_data[30:29]<=chorus_next;config_data[32:31]<=chorus_next;config_data[28:24]<=chorus_next==0?4:chorus_next==1?6:8;edited[2]<=0;end
 11:begin config_data[30:29]<=tier_step(config_data[30:29],up);edited[2]<=1;end
 12:begin config_data[32:31]<=tier_step(config_data[32:31],up);edited[2]<=1;end
 13:begin config_data[28:24]<=gain_step(config_data[28:24],up);edited[2]<=1;end
 14:config_data[4:0]<=gain_step(config_data[4:0],up);
 endcase
 end
 end
// Cache data need no reset: invalid banks are never exposed to consumers.
 always @(posedge clk)begin
 if(rst_n && requested_instrument!=current_instrument)begin
 saved_config[current_instrument]<=config_data;saved_enable[current_instrument]<=effective_enable;
 saved_edited[current_instrument]<=edited;saved_echo[current_instrument]<=echo_preset;saved_chorus[current_instrument]<=chorus_preset;
 end
 end
endmodule
