`timescale 1ns/1ps
module video_mixer(input[10:0] x,input[9:0] y,input[63:0] data,input signed[8:0] wave,input wave_valid,
 output reg[23:0] bg,color,output reg text_on,output reg[3:0] row,col,output reg[7:0] letter);
 wire[10:0] title_x=x-11'd240,wx=x-11'd128,vx=x-11'd672,hx=x-(x<640?11'd128:11'd640);
 wire[9:0] title_y=y-10'd16,wytext=y-10'd104,py=y-10'd264;
 wire[7:0] value8={3'd0,value},dry8={3'd0,c[4:0]};
 wire[32:0] c=data[32:0];wire[3:0] selected=data[37:34];
 reg[1:0] panel;reg[10:0] lx;reg[3:0] item;reg[4:0] value;reg[255:0] line;
 reg[23:0] accent;reg[4:0] char_index;reg active_row;reg[4:0] row_y;
 wire signed[10:0] wave_y=11'sd176-($signed({{2{wave[8]}},wave})>>>1);
 function[31:0] gain_text;input[4:0] v;begin case(v)
 5'd0:gain_text=32'h010b0000;
 5'd1:gain_text=32'h070b0000;
 5'd2:gain_text=32'h02040b00;
 5'd3:gain_text=32'h020a0b00;
 5'd4:gain_text=32'h03060b00;
 5'd5:gain_text=32'h04020b00;
 5'd6:gain_text=32'h04090b00;
 5'd7:gain_text=32'h05050b00;
 5'd8:gain_text=32'h06010b00;
 5'd9:gain_text=32'h06070b00;
 5'd10:gain_text=32'h07040b00;
 5'd11:gain_text=32'h070a0b00;
 5'd12:gain_text=32'h08060b00;
 5'd13:gain_text=32'h09020b00;
 5'd14:gain_text=32'h09090b00;
 5'd15:gain_text=32'h0a050b00;
 5'd16:gain_text=32'h0201010b;
 default:gain_text=0;endcase end endfunction
 function[31:0] volume_text;input[6:0] v;begin case(v)
 7'd0:volume_text=32'h010b0000;
 7'd6:volume_text=32'h070b0000;
 7'd13:volume_text=32'h02040b00;
 7'd19:volume_text=32'h020a0b00;
 7'd25:volume_text=32'h03060b00;
 7'd31:volume_text=32'h04020b00;
 7'd38:volume_text=32'h04090b00;
 7'd44:volume_text=32'h05050b00;
 7'd50:volume_text=32'h06010b00;
 7'd56:volume_text=32'h06070b00;
 7'd63:volume_text=32'h07040b00;
 7'd69:volume_text=32'h070a0b00;
 7'd75:volume_text=32'h08060b00;
 7'd81:volume_text=32'h09020b00;
 7'd88:volume_text=32'h09090b00;
 7'd94:volume_text=32'h0a050b00;
 7'd100:volume_text=32'h0201010b;
 default:volume_text=0;endcase end endfunction
 always @*begin
 panel=x<464?0:x<816?1:2;lx=x-(x<464?11'd128:x<816?11'd480:11'd832);
 accent=panel==0?24'h008b82:panel==1?24'hb86700:24'h7841bd;
 bg=24'hf0f5fa;color=24'h18354c;text_on=0;row=y[3:0];col=lx[3:0];letter=0;line=0;item=15;value=0;active_row=0;row_y=0;char_index=lx[8:4];
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
 if(y>=304 && y<320)begin text_on=1;line=panel==0?256'h4b23000000000000000000000000000000000000000000000000000000000000:panel==1?256'h2629000000000000000000000000000000000000000000000000000000000000: 256'h2224000000000000000000000000000000000000000000000000000000000000;end
 if(y>=336 && y<368)begin row_y=y[4:0]-5'd16; item=panel==0?0:panel==1?4:9;line=data[48]?256'haf3e3d6400000000000000000000000000000000000000000000000000000000:(data[38+panel]?256'h36ae000000000000000000000000000000000000000000000000000000000000:256'h16ad000000000000000000000000000000000000000000000000000000000000);end
 if(y>=384 && y<416)begin row_y=y[4:0]-5'd0; item=panel==0?1:panel==1?5:10;line=panel==0?(c[13:12]==0?256'h57c7c80000000000000000000000000000000000000000000000000000000000:c[13:12]==1?256'h6f94c90000000000000000000000000000000000000000000000000000000000: 256'hcacbc80000000000000000000000000000000000000000000000000000000000):panel==1?(data[42:41]==0?256'hcccd356700000000000000000000000000000000000000000000000000000000:data[42:41]==1?256'h5426290000000000000000000000000000000000000000000000000000000000:data[42:41]==2?256'h5e2b262900000000000000000000000000000000000000000000000000000000: 256'hce26290000000000000000000000000000000000000000000000000000000000):(data[44:43]==0?256'hcfd0000000000000000000000000000000000000000000000000000000000000:data[44:43]==1?256'hd1d2000000000000000000000000000000000000000000000000000000000000: 256'hd3d4000000000000000000000000000000000000000000000000000000000000);end
 if(y>=432 && y<464)begin row_y=y[4:0]-5'd16;
 item=panel==0?2:panel==1?6:11;line=panel==0?256'hd529000000000000000000000000000000000000000000000000000000000000:panel==1?256'hc8d6000000000000000000000000000000000000000000000000000000000000: 256'hd78c000000000000000000000000000000000000000000000000000000000000;
 value=panel==0?c[9:5]:panel==1?{3'd0,c[20:19]}:{3'd0,c[30:29]};end
 if(y>=480 && y<512)begin row_y=y[4:0]-5'd0;
 item=panel==0?3:panel==1?7:12;line=panel==0?256'h9b9c000000000000000000000000000000000000000000000000000000000000:panel==1?256'h898a000000000000000000000000000000000000000000000000000000000000: 256'h788c000000000000000000000000000000000000000000000000000000000000;
 value=panel==0?{3'd0,c[11:10]}:panel==1?{2'd0,c[23:21]}:{3'd0,c[32:31]};end
 if(y>=528 && y<560 && panel!=0)begin row_y=y[4:0]-5'd16; item=panel==1?8:13;line=256'hd529000000000000000000000000000000000000000000000000000000000000;value=panel==1?c[18:14]:c[28:24];end
 active_row=item!=15;
 if(active_row)begin
 if(selected==item)begin bg=24'hdceaf5;if(lx<4)bg=accent;end
 if(row_y<16)text_on=1;
 if(item==2 || item==3 || item==6 || item==7 || item==8 || item==11 || item==12 || item==13)begin
 if(row_y>=24 && row_y<28 && lx>=16 && lx<272)begin
 bg=24'he2eaf1;
 if(lx-16 < ((item==2 || item==8 || item==13)?{value,4'd0}:item==7?{value,5'd0}:{value,7'd0}))bg=accent;
 end
 if(item==2 || item==8 || item==13)line[207-:32]=gain_text(value);
 else if(item==6)line[207-:64]=value==0?64'h05030c0747550000:value==1?64'h09060c0347550000:64'h0208010c06475500;
 else if(item==7)line[207-:32]=value==0?32'h010b0000:value==1?32'h02040b00:value==2?32'h03060b00:value==3?32'h04090b00:value==4?32'h06010b00:value==5?32'h07040b00:32'h08060b00;
 else line[207-:32]=value==0?32'hb3000000:value==1?32'h12000000:32'h72000000;
 end
 end
 if(y>=568 && y<584 && data[45+panel])begin text_on=1;line=256'h34deba0000000000000000000000000000000000000000000000000000000000;end
 end
 if(y>=16 && y<48 && x>=240 && x<1008)begin
 text_on=1;line=256'h6fc4ba6fc5000000000000000000000000000000000000000000000000000000;char_index=title_x[9:5];col=title_x[4:1];row=title_y[4:1];end
 if(y>=104 && y<120 && x>=128 && x<640)begin text_on=1;line=256'h333ec61849370000000000000000000000000000000000000000000000000000;char_index=wx[8:4];col=wx[3:0];row=wytext[3:0];color=24'hc9e8f1;end
 if(y>=264 && y<280 && x>=128 && x<640)begin text_on=1;line=256'hdfe0b62974e164e2e30000000000000000000000000000000000000000000000;char_index=wx[8:4];col=wx[3:0];row=py[3:0];end
 if(y>=608 && y<640 && x>=128 && x<640)begin
 if(selected==14)bg=24'hdceaf5;
 if(y<624)begin text_on=1;line=256'haa29000000000000000000000000000000000000000000000000000000000000;char_index=wx[8:4];col=wx[3:0];
 line[207-:32]=gain_text(c[4:0]);
 end
 if(y>=632 && y<636 && x<384)bg=x-128<{c[4:0],4'd0}?24'h008b82:24'he2eaf1;
 end
 if(y>=608 && y<624 && x>=672 && x<1184)begin text_on=1;line=256'h6fb1dbc175d86fb1000000000000000000000000000000000000000000000000;char_index=vx[8:4];col=vx[3:0];line[159-:32]=volume_text(data[55:49]);end
 if(y>=640 && y<656 && x>=128 && x<1152)begin text_on=1;line=x<640?256'h7b7c6d75543a10d9da74ce3aa6d9da0000000000000000000000000000000000:256'h6f5ddbc175ba5ea1a2da00000000000000000000000000000000000000000000;char_index=hx[8:4];col=x[3:0];end
 if(y>=672 && y<688 && x>=128 && x<1152)begin text_on=1;line=x<640?256'h3d646d75543adcdd74ce3a652600000000000000000000000000000000000000:256'h6fb1dbc175d86fb1000000000000000000000000000000000000000000000000;char_index=hx[8:4];col=x[3:0];end
 if(y>=72 && y<88 && x>=128 && x<640)begin
 text_on=1;line=data[57:56]==1?256'ha1a29495757e7f00000000000000000000000000000000000000000000000000:data[57:56]==2?256'ha1a29495756b5100000000000000000000000000000000000000000000000000:256'ha1a2949575215100000000000000000000000000000000000000000000000000;
 char_index=wx[8:4];col=wx[3:0];row=y[3:0]-4'd8;
 if(selected==15)begin bg=24'hdceaf5;color=24'h008b82;end
 end
 letter=line[(31-char_index)*8+:8];
 end
endmodule
