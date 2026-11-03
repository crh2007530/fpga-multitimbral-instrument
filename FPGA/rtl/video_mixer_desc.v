`timescale 1ns/1ps
module video_mixer_desc(input[10:0] x,input[9:0] y,input[63:0] data,input signed[8:0] wave,input wave_valid,
 output reg[23:0] bg,color,output reg text_on,output reg[3:0] row,col,output wire[21:0] descriptor);
 wire[10:0] title_x=x-11'd240,wx=x-11'd128,vx=x-11'd672,hx=x-(x<640?11'd128:11'd640);
 wire[9:0] title_y=y-10'd16,wytext=y-10'd104,py=y-10'd264;
 wire[7:0] value8={3'd0,value},dry8={3'd0,c[4:0]};
 wire[32:0] c=data[32:0];wire[3:0] selected=data[37:34];
 reg[1:0] panel;reg[10:0] lx;reg[3:0] item;reg[4:0] value;reg[5:0] line;reg[3:0] suffix_kind;reg[6:0] suffix_value;
 reg[23:0] accent;reg[4:0] char_index;reg active_row;reg[4:0] row_y;
 wire signed[10:0] wave_y=11'sd176-($signed({{2{wave[8]}},wave})>>>1);
 always @*begin
 panel=x<464?0:x<816?1:2;lx=x-(x<464?11'd128:x<816?11'd480:11'd832);
 accent=panel==0?24'h008b82:panel==1?24'hb86700:24'h7841bd;
 bg=24'hf0f5fa;color=24'h18354c;text_on=0;row=y[3:0];col=lx[3:0];line=0;suffix_kind=0;suffix_value=0;item=15;value=0;active_row=0;row_y=0;char_index=lx[8:4];
 if(y<64)bg=24'hffffff;
 if(y==63)bg=24'h008fa5;
 if(x>=112 && x<1168 && y>=96 && y<256)begin
 bg=24'h102239;
 if(x[6:0]==0 || y[5:0]==0)bg=24'h294257;
 if(wave_valid && y>=128 && y<240 && $signed({1'b0,y})>=wave_y-1 && $signed({1'b0,y})<=wave_y+1)bg=24'h38e2ed;
 end
 if(x>=112 && x<1168 && y>=288 && y<592 && lx<320)begin
 bg=24'hffffff;
 if(y<320)begin bg=accent;color=24'hffffff;end
 if(y>=304 && y<320)begin text_on=1;line=panel==0?6'd1:panel==1?6'd2: 6'd3;end
 if(y>=336 && y<368)begin row_y=y[4:0]-5'd16; item=panel==0?0:panel==1?4:9;line=data[48]?6'd4:(data[38+panel]?6'd5:6'd6);end
 if(y>=384 && y<416)begin row_y=y[4:0]-5'd0; item=panel==0?1:panel==1?5:10;line=panel==0?(c[13:12]==0?6'd7:c[13:12]==1?6'd8: 6'd9):panel==1?(data[42:41]==0?6'd10:data[42:41]==1?6'd11:data[42:41]==2?6'd12: 6'd13):(data[44:43]==0?6'd14:data[44:43]==1?6'd15: 6'd16);end
 if(y>=432 && y<464)begin row_y=y[4:0]-5'd16;
 item=panel==0?2:panel==1?6:11;line=panel==0?6'd17:panel==1?6'd18: 6'd19;
 value=panel==0?c[9:5]:panel==1?{3'd0,c[20:19]}:{3'd0,c[30:29]};end
 if(y>=480 && y<512)begin row_y=y[4:0]-5'd0;
 item=panel==0?3:panel==1?7:12;line=panel==0?6'd20:panel==1?6'd21: 6'd22;
 value=panel==0?{3'd0,c[11:10]}:panel==1?{2'd0,c[23:21]}:{3'd0,c[32:31]};end
 if(y>=528 && y<560 && panel!=0)begin row_y=y[4:0]-5'd16; item=panel==1?8:13;line=6'd17;value=panel==1?c[18:14]:c[28:24];end
 active_row=item!=15;
 if(active_row)begin
 if(selected==item)begin bg=24'hdceaf5;if(lx<4)bg=accent;end
 if(row_y<16)text_on=1;
 if(item==2 || item==3 || item==6 || item==7 || item==8 || item==11 || item==12 || item==13)begin
 if(row_y>=24 && row_y<28 && lx>=16 && lx<272)begin
 bg=24'he2eaf1;
 if(lx-16 < ((item==2 || item==8 || item==13)?{value,4'd0}:item==7?{value,5'd0}:{value,7'd0}))bg=accent;
 end
 if(item==2 || item==8 || item==13)begin suffix_kind=1;suffix_value={2'd0,value};end
 else if(item==6)begin suffix_kind=2;suffix_value={2'd0,value};end
 else if(item==7)begin suffix_kind=3;suffix_value={2'd0,value};end
 else begin suffix_kind=4;suffix_value={2'd0,value};end
 end
 end
 if(y>=568 && y<584 && data[45+panel])begin text_on=1;line=6'd23;end
 end
 if(y>=16 && y<48 && x>=240 && x<1008)begin
 text_on=1;line=6'd24;char_index=title_x[9:5];col=title_x[4:1];row=title_y[4:1];end
 if(y>=104 && y<120 && x>=128 && x<640)begin text_on=1;line=6'd25;char_index=wx[8:4];col=wx[3:0];row=wytext[3:0];color=24'hc9e8f1;end
 if(y>=264 && y<280 && x>=128 && x<640)begin text_on=1;line=6'd26;char_index=wx[8:4];col=wx[3:0];row=py[3:0];end
 if(y>=608 && y<640 && x>=128 && x<640)begin
 if(selected==14)bg=24'hdceaf5;
 if(y<624)begin text_on=1;line=6'd27;char_index=wx[8:4];col=wx[3:0];
 suffix_kind=1;suffix_value={2'd0,c[4:0]};
 end
 if(y>=632 && y<636 && x<384)bg=x-128<{c[4:0],4'd0}?24'h008b82:24'he2eaf1;
 end
 if(y>=608 && y<624 && x>=672 && x<1184)begin text_on=1;line=6'd28;char_index=vx[8:4];col=vx[3:0];suffix_kind=5;suffix_value=data[55:49];end
 if(y>=640 && y<656 && x>=128 && x<1152)begin text_on=1;line=x<640?6'd29:6'd30;char_index=hx[8:4];col=x[3:0];end
 if(y>=672 && y<688 && x>=128 && x<1152)begin text_on=1;line=x<640?6'd31:6'd28;char_index=hx[8:4];col=x[3:0];end

 if(y>=72 && y<88 && x>=128 && x<640)begin
 text_on=1;line=data[57:56]==1?6'd33:data[57:56]==2?6'd34:6'd32;
 char_index=wx[8:4];col=wx[3:0];row=y[3:0]-4'd8;
 if(selected==15)begin bg=24'hdceaf5;color=24'h008b82;end
 end
 end
 assign descriptor={line,char_index,suffix_kind,suffix_value};
endmodule
