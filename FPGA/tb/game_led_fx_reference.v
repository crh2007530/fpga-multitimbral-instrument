`timescale 1ns/1ps
// One shared pixel evaluator; the WS2812 driver snapshots 30 pixels in 30 clocks.
module game_led_fx_reference #(parameter integer TICK_CYCLES=500000)(
 input clk,rst_n,active,running,done,input[2:0] event_code,input[7:0] event_mask,
 input[4:0] pixel,output reg[23:0] color);
 reg[18:0] divider;reg[5:0] phase;reg[5:0] age[0:7];
 reg[6:0] flash_age,finish_age;reg[2:0] flash;reg previous_done;
 wire tick=divider==TICK_CYCLES-1;
 integer i,j,d,r,level,best;reg[7:0] breath;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin divider<=0;phase<=0;flash_age<=127;finish_age<=127;flash<=0;previous_done<=0;for(i=0;i<8;i=i+1)age[i]<=63;end
 else begin
  previous_done<=done;
  if(tick)begin divider<=0;phase<=phase+1'b1;end else divider<=divider+1'b1;
  if(!active)begin flash<=0;flash_age<=127;finish_age<=127;for(i=0;i<8;i=i+1)age[i]<=63;end
  else if(done)begin
   flash<=0;for(i=0;i<8;i=i+1)age[i]<=63;
   if(!previous_done)finish_age<=0;else if(tick && finish_age<100)finish_age<=finish_age+1'b1;
  end else if(!running)begin flash<=0;flash_age<=127;finish_age<=127;for(i=0;i<8;i=i+1)age[i]<=63;end
  else begin
   finish_age<=127;
   if(tick)begin
    if(flash_age<127)flash_age<=flash_age+1'b1;
    for(i=0;i<8;i=i+1)if(age[i]<63)age[i]<=age[i]+1'b1;
   end
   if(event_code==4 || event_code==3 || event_code==2)begin
    flash<=event_code;flash_age<=0;for(i=0;i<8;i=i+1)age[i]<=63;
   end else if(event_code==1)begin
    flash<=0;flash_age<=127;
    for(i=0;i<8;i=i+1)if(event_mask[i])age[i]<=0;
   end
  end
 end
 always @* begin
  color=24'h000008;best=0;d=0;r=0;level=0;
  breath=phase[5]?8'd8+{3'd0,~phase[4:0]}:8'd8+{3'd0,phase[4:0]};
  if(!active)color=0;
  else if(done)begin
   if(finish_age<100)begin
    case((pixel+finish_age[6:2])%6)
     0:color=24'h004000;1:color=24'h204000;2:color=24'h400000;
     3:color=24'h400040;4:color=24'h000040;default:color=24'h002040;
    endcase
   end else color=24'h300000;
  end else if(!running)color={16'd0,breath};
  else if((flash==4 || flash==3) && flash_age<30)begin
   if(flash_age<8 || (flash_age>=15 && flash_age<23))color=flash==4?24'h004000:24'h304000;
  end else if(flash==2 && flash_age<15)color={8'd60-({1'b0,flash_age}<<2),16'd0};
  else begin
   for(j=0;j<8;j=j+1)begin
    d=$signed({1'b0,pixel})-(j*3+1);if(d<0)d=-d;r=age[j];
    level=0;
    if(age[j]<35 && d<=r && r-d<5)level=64-((r-d)*12);
    if(level>best)best=level;
   end
   if(best!=0)color={best[7:0],(best[7:0]>>2),best[7:0]};
  end
 end
endmodule


