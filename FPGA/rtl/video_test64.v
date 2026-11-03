`timescale 1ns/1ps
// 4 rows x 16 measured tone bins. Mask changes badges, NEVER measured bars.
module video_test64(input[10:0]x,input[9:0]y,input[7:0]magnitude,input visible,
 input[63:0]mask,input[5:0]selected,output reg[23:0]rgb);
 wire[10:0]lx=x-11'd128;wire[9:0]ly=y-10'd128;
 wire[5:0]voice_id={ly[8:7],lx[9:6]};
 wire[6:0]number={1'b0,voice_id}+7'd1;
 wire[6:0]tens_wide=number/7'd10,ones_wide=number%7'd10;
 wire[3:0]tens=tens_wide[3:0],ones=ones_wide[3:0];
 function[6:0]segments;input[3:0]n;begin case(n)
 0:segments=7'b1111110;1:segments=7'b0110000;2:segments=7'b1101101;
 3:segments=7'b1111001;4:segments=7'b0110011;5:segments=7'b1011011;
 6:segments=7'b1011111;7:segments=7'b1110000;8:segments=7'b1111111;
 9:segments=7'b1111011;default:segments=0;endcase end endfunction

 wire second=lx[5:0]>=32;
 wire[5:0]digit_x=second?lx[5:0]-6'd33:lx[5:0]-6'd19;
 wire[6:0]digit_y=ly[6:0]-7'd101;
 wire[6:0]seg=segments(second?ones:tens);
 wire ink=(digit_x<10 && digit_y<2 && seg[6]) ||
 (digit_x>=8 && digit_x<10 && digit_y<10 && seg[5]) ||
 (digit_x>=8 && digit_x<10 && digit_y>=9 && digit_y<20 && seg[4]) ||
 (digit_x<10 && digit_y>=18 && digit_y<20 && seg[3]) ||
 (digit_x<2 && digit_y>=9 && digit_y<20 && seg[2]) ||
 (digit_x<2 && digit_y<10 && seg[1]) ||
 (digit_x<10 && digit_y>=9 && digit_y<11 && seg[0]);
 wire[6:0]bar_height={1'b0,magnitude[7:2]}+{2'b0,magnitude[7:3]};
 always @*begin
 rgb=24'h091120;
 if(y<64)rgb=24'h152942;
 if(x>=128 && x<1152 && y>=128 && y<640)begin
  if(lx[5:0]<60 && ly[6:0]<124)begin
   rgb=24'h101f32;
   if(ly[6:0]==96 || ly[6:0]==64 || ly[6:0]==32)rgb=24'h203042;
   if(lx[5:0]>=22 && lx[5:0]<38 && ly[6:0]<96 &&
       visible && magnitude!=0 && ly[6:0]>=7'd96-bar_height)rgb=24'hffbb36;
   if(ly[6:0]>=98)rgb=mask[voice_id]?24'h16583c:24'h721f32;
   // Explicit crossed badge when muted. Does not erase a real residual peak.
   if(!mask[voice_id] && lx[5:0]>=3 && lx[5:0]<13 && ly[6:0]>=104 && ly[6:0]<114 &&
      ((lx[5:0]-3)==(ly[6:0]-104) || (lx[5:0]-3)+(ly[6:0]-104)==9))rgb=24'hffb2bc;
   if(voice_id==selected && (lx[5:0]<2 || lx[5:0]>=58 || ly[6:0]<2 || ly[6:0]>=122))rgb=24'hffdf40;
   if(ink)rgb=24'he1edf7;
  end
 end
 end
endmodule

// Nearest actual FFT bin for each diagnostic frequency, 257+83*n Hz.
module test64_bin(input[5:0] voice_id,output reg[9:0] bin);
 always @*case(voice_id)
 6'd0:bin=10'd11;
 6'd1:bin=10'd14;
 6'd2:bin=10'd18;
 6'd3:bin=10'd22;
 6'd4:bin=10'd25;
 6'd5:bin=10'd29;
 6'd6:bin=10'd32;
 6'd7:bin=10'd36;
 6'd8:bin=10'd39;
 6'd9:bin=10'd43;
 6'd10:bin=10'd46;
 6'd11:bin=10'd50;
 6'd12:bin=10'd53;
 6'd13:bin=10'd57;
 6'd14:bin=10'd60;
 6'd15:bin=10'd64;
 6'd16:bin=10'd68;
 6'd17:bin=10'd71;
 6'd18:bin=10'd75;
 6'd19:bin=10'd78;
 6'd20:bin=10'd82;
 6'd21:bin=10'd85;
 6'd22:bin=10'd89;
 6'd23:bin=10'd92;
 6'd24:bin=10'd96;
 6'd25:bin=10'd99;
 6'd26:bin=10'd103;
 6'd27:bin=10'd106;
 6'd28:bin=10'd110;
 6'd29:bin=10'd114;
 6'd30:bin=10'd117;
 6'd31:bin=10'd121;
 6'd32:bin=10'd124;
 6'd33:bin=10'd128;
 6'd34:bin=10'd131;
 6'd35:bin=10'd135;
 6'd36:bin=10'd138;
 6'd37:bin=10'd142;
 6'd38:bin=10'd145;
 6'd39:bin=10'd149;
 6'd40:bin=10'd152;
 6'd41:bin=10'd156;
 6'd42:bin=10'd160;
 6'd43:bin=10'd163;
 6'd44:bin=10'd167;
 6'd45:bin=10'd170;
 6'd46:bin=10'd174;
 6'd47:bin=10'd177;
 6'd48:bin=10'd181;
 6'd49:bin=10'd184;
 6'd50:bin=10'd188;
 6'd51:bin=10'd191;
 6'd52:bin=10'd195;
 6'd53:bin=10'd198;
 6'd54:bin=10'd202;
 6'd55:bin=10'd206;
 6'd56:bin=10'd209;
 6'd57:bin=10'd213;
 6'd58:bin=10'd216;
 6'd59:bin=10'd220;
 6'd60:bin=10'd223;
 6'd61:bin=10'd227;
 6'd62:bin=10'd230;
 6'd63:bin=10'd234;
 default:bin=0;endcase
endmodule

`timescale 1ns/1ps
// 4 rows x 16 measured tone bins. Mask changes badges, NEVER measured bars.
module video_test128(input[10:0]x,input[9:0]y,input[7:0]magnitude,input visible,
 input[63:0]mask,input[5:0]selected,output reg[23:0]rgb,input bank);
 wire[10:0]lx=x-11'd128;wire[9:0]ly=y-10'd128;
 wire[5:0]voice_id={ly[8:7],lx[9:6]};
 wire[7:0]number={1'b0,bank,voice_id}+8'd1;
 wire[7:0]remainder=number>=100?number-8'd100:number;
 wire[7:0]tens_full=remainder/8'd10,ones_full=remainder%8'd10;
 wire[3:0]tens=tens_full[3:0],ones=ones_full[3:0];
 function[6:0]segments;input[3:0]n;begin case(n)
 0:segments=7'b1111110;1:segments=7'b0110000;2:segments=7'b1101101;
 3:segments=7'b1111001;4:segments=7'b0110011;5:segments=7'b1011011;
 6:segments=7'b1011111;7:segments=7'b1110000;8:segments=7'b1111111;
 9:segments=7'b1111011;default:segments=0;endcase end endfunction

 wire[1:0]digit=lx[5:0]>=42?2'd2:lx[5:0]>=28?2'd1:2'd0;
 wire[5:0]digit_x=lx[5:0]-(digit==2?6'd42:digit==1?6'd28:6'd14);
 wire[6:0]digit_y=ly[6:0]-7'd101;
 wire[6:0]seg=segments(digit==2?ones:digit==1?tens:number>=100?4'd1:4'hf);
 wire ink=(digit_x<10 && digit_y<2 && seg[6]) ||
 (digit_x>=8 && digit_x<10 && digit_y<10 && seg[5]) ||
 (digit_x>=8 && digit_x<10 && digit_y>=9 && digit_y<20 && seg[4]) ||
 (digit_x<10 && digit_y>=18 && digit_y<20 && seg[3]) ||
 (digit_x<2 && digit_y>=9 && digit_y<20 && seg[2]) ||
 (digit_x<2 && digit_y<10 && seg[1]) ||
 (digit_x<10 && digit_y>=9 && digit_y<11 && seg[0]);
 wire[6:0]bar_height={1'b0,magnitude[7:2]}+{2'b0,magnitude[7:3]};
 always @*begin
 rgb=24'h091120;
 if(y<64)rgb=24'h152942;
 if(x>=128 && x<1152 && y>=128 && y<640)begin
  if(lx[5:0]<60 && ly[6:0]<124)begin
   rgb=24'h101f32;
   if(ly[6:0]==96 || ly[6:0]==64 || ly[6:0]==32)rgb=24'h203042;
   if(lx[5:0]>=22 && lx[5:0]<38 && ly[6:0]<96 &&
       visible && magnitude!=0 && ly[6:0]>=7'd96-bar_height)rgb=24'hffbb36;
   if(ly[6:0]>=98)rgb=mask[voice_id]?24'h16583c:24'h721f32;
   // Explicit crossed badge when muted. Does not erase a real residual peak.
   if(!mask[voice_id] && lx[5:0]>=3 && lx[5:0]<13 && ly[6:0]>=104 && ly[6:0]<114 &&
      ((lx[5:0]-3)==(ly[6:0]-104) || (lx[5:0]-3)+(ly[6:0]-104)==9))rgb=24'hffb2bc;
   if(voice_id==selected && (lx[5:0]<2 || lx[5:0]>=58 || ly[6:0]<2 || ly[6:0]>=122))rgb=24'hffdf40;
   if(ink)rgb=24'he1edf7;
  end
 end
 end
endmodule

