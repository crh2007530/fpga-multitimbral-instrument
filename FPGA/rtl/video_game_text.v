`timescale 1ns/1ps
// Two pipeline stages: coordinate decode, then synchronous character ROM.
module video_game_text(input wire clk,rst_n,input wire[10:0] x,input wire[9:0] y,input wire[127:0] state,
 output reg text_on,output reg[3:0] row,output reg[3:0] col,output reg[7:0] letter);
 // Shared sequential binary-to-BCD converter: no decimal division in the
 // 74MHz pixel path. All seven fields refresh in 119 clocks, before HUD row128.
 reg[19:0] digits[0:6],work_bcd,adjusted;
 reg[15:0] binary_value;reg[4:0] bit_count;reg[2:0] field;
 integer n;
 always @*begin
 adjusted=work_bcd;
 for(n=0;n<5;n=n+1)if(work_bcd[n*4+:4]>=5)adjusted[n*4+:4]=work_bcd[n*4+:4]+4'd3;
 end
 integer a;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
 for(a=0;a<7;a=a+1)digits[a]<=0;
 work_bcd<=0;binary_value<=0;bit_count<=0;field<=0;
 end else if(bit_count==0)begin
 case(field)
 0:binary_value<=state[51:36];1:binary_value<={8'd0,state[59:52]};
 2:binary_value<={8'd0,state[75:68]};3:binary_value<={8'd0,state[83:76]};
 4:binary_value<={8'd0,state[91:84]};5:binary_value<={8'd0,state[99:92]};
 default:binary_value<={8'd0,state[67:60]};endcase
 work_bcd<=0;bit_count<=1;
 end else begin
 work_bcd<={adjusted[18:0],binary_value[15]};binary_value<={binary_value[14:0],1'b0};
 if(bit_count==16)begin digits[field]<={adjusted[18:0],binary_value[15]};bit_count<=0;field<=field==6?3'd0:field+1'b1;end
 else bit_count<=bit_count+1'b1;
 end

 reg[7:0] chars[0:2047];initial $readmemh("assets/game_text.hex",chars);
 reg[4:0] id;reg[10:0] ox;reg[9:0] oy;reg big,num,en;
 reg[2:0] num_id;integer lane;
 wire[10:0] lx=x-ox;wire[9:0] ly=y-oy;
 reg[4:0] id1;reg[5:0] index1;reg[3:0] row1;reg[3:0] col1;
 reg en1,num1;reg[19:0] digits1;
 always @*begin
 id=0;ox=0;oy=0;big=0;num=0;en=0;num_id=0;
 if(y>=16 && y<48 && x>=240 && x<1264)begin id=state[120]?29:state[101]?28:27;ox=240;oy=16;big=1;en=1;end
 else if(x>=32 && x<200)begin
 ox=32;oy={y[9:5],5'd0};en=y[4]==0;
 case(y[9:5])
 4:id=2;5:begin num=1;big=1;en=1;end
 7:id=3;8:begin num=1;num_id=1;big=1;en=1;end
 10:id=4;11:begin num=1;num_id=2;end
 12:id=5;13:begin num=1;num_id=3;end
 14:id=6;15:begin num=1;num_id=4;end
 16:id=7;17:begin num=1;num_id=5;end
 18:id=8;19:begin num=1;num_id=6;end
 default:en=0;
 endcase end
 else if(x>=1040 && x<1264)begin
 ox=1040;
 if(y>=104 && y<120)begin id=9;oy=104;en=1;end
 if(y>=256 && y<272)begin id=10;oy=256;en=1;end
 if(y>=424 && y<440)begin id=11;oy=424;en=1;end
 if(y>=624 && y<640)begin id=12;oy=624;en=1;end
 if(y>=648 && y<664)begin id=13;oy=648;en=1;end
 end
 if(x>=320 && x<832 && y>=64 && y<80)begin ox=320;oy=64;en=1;num=0;big=0;id=state[104]?31:14;end
 if(x>=320 && x<960 && y>=112 && y<128)begin ox=320;oy=112;en=1;num=0;big=0;id=state[104]?31:state[103:102]==0?0:state[103:102]==2?30:1;end
 if(x>=256 && x<1008 && y>=132 && y<148)begin ox=256;oy=132;en=1;num=0;big=0;id=15;end
 if(x>=464 && x<800 && y>=80 && y<96)begin
 ox=464;oy=80;en=1;num=0;big=0;
 case(state[35:33])1:id=4;2:id=5;3:id=6;4:id=7;default:begin id=14;en=0;end endcase
 end
 if(x>=432 && x<816 && y>=296 && y<328 && (!state[31] || state[32]))begin
 ox=432;oy=296;en=1;big=1;num=0;id=state[32]?16:state[100]?17:18;
 end
 for(lane=0;lane<8;lane=lane+1)
 if(x>=256+lane*96 && x<288+lane*96 && y>=640 && y<656)begin
 ox=256+lane*96;oy=640;en=1;big=0;num=0;id=19+lane;end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin id1<=0;index1<=0;row1<=0;col1<=0;en1<=0;num1<=0;digits1<=0;
 text_on<=0;row<=0;col<=0;letter<=0;end
 else begin
 id1<=id;index1<=big && !num?{1'b0,lx[10:5]}:lx[9:4];row1<=big?ly[4:1]:ly[3:0];col1<=big && !num?lx[4:1]:lx[3:0];
 en1<=en;num1<=num;digits1<=digits[num_id];
 text_on<=en1 && (!num1 || index1<5);row<=row1;col<=col1;
 if(num1 && index1<5)letter<=8'd1+{4'd0,digits1[(4-index1)*4+:4]};
 else letter<=chars[{id1,index1}];
 end
endmodule
