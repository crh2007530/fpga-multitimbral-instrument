`timescale 1ns/1ps
// Read-only overlay. Title is written while a new chart is unpublished.
// The valid bit is frame-snapshotted via the same CDC scheme as the UI.
module video_brand_title(input clk,rst_n,sys_clk,sys_rst_n,
 input title_write,input[8:0] title_address,input[7:0] title_data,
 input title_show,game_active,test_mode,input[10:0] x,input[9:0] y,
 input hi,vi,di,input[23:0] rgb_in,output reg ho,vo,do_,output reg[23:0] rgb_out);
 reg logo[0:16383];initial $readmemb("assets/logo.hex",logo);
 reg[7:0] title_mem[0:511];
 always @(posedge sys_clk)if(sys_rst_n && title_write)title_mem[title_address]<=title_data;
 wire[10:0] lx=x-11'd16,tx=x-(game_active?11'd320:11'd560);
 wire[9:0] ly=y-10'd8,ty=y-10'd48;
 wire logo_hit=!test_mode && x>=16 && x<208 && y>=8 && y<56;
 wire title_hit=!test_mode && title_show && (game_active?(x>=320 && x<832 && y>=48 && y<80):(x>=560 && x<816 && y>=48 && y<64));
 wire[8:0] title_read=game_active?{ty[4:1],tx[8:4]}:{ty[3:0],tx[7:3]};
 reg[3:0] lm,tm,lb,tb,gm;reg[7:0] title_byte;reg[2:0] bit_col;
 always @(posedge clk)begin
  lb[0]<=logo[{ly[5:0],lx[7:0]}];lb[3:1]<=lb[2:0];
  title_byte<=title_mem[title_read];bit_col<=game_active?tx[3:1]:tx[2:0];
  tb[1]<=title_byte[7-bit_col];tb[3:2]<=tb[2:1];
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin gm<=0;lm<=0;tm<=0;ho<=0;vo<=0;do_<=0;rgb_out<=0;end
 else begin
  gm<={gm[2:0],game_active};lm<={lm[2:0],logo_hit};tm<={tm[2:0],title_hit};
  ho<=hi;vo<=vi;do_<=di;rgb_out<=di?rgb_in:24'd0;
  // Existing one-bit logo mask: transparent background on the dark game page.
  if(di && lm[3] && (!gm[3] || lb[3]))rgb_out<=lb[3]?(gm[3]?24'h69dfff:24'h005184):24'hffffff;
  else if(di && tm[3])rgb_out<=tb[3]?(gm[3]?24'he5f4ff:24'h123656):(gm[3]?24'h050918:24'hffffff);
 end
endmodule
