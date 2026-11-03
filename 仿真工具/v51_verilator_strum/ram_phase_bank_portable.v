`timescale 1ns/1ps
// 32 slots per RAM lane. Independent 32-bit phases; one adder per lane.
// Snapshot pass starts at sample_ce. Update pass follows the 32-result pitch batch.
// A reset before/after a pitch update preserves the original operation order.
module ram_phase_bank #(parameter VOICES=128)(
 input clk,rst_n,sample_ce,batch_valid,input[4:0]batch_index,
 input[31:0]batch_increment,input test_mode,test_all,
 input[VOICES-1:0]phase_reset,
 output wire[VOICES*10-1:0]addresses,output reg fault);
localparam LANES=VOICES/32;
reg snap_active,update_active,read_valid,read_snapshot;
reg[4:0]snap_index,update_index,read_index;
reg[VOICES-1:0]reset_pending,step_pending,snap_reset;
reg captured_test,captured_all;
wire ren=snap_active || update_active;
wire[4:0]ra=snap_active?snap_index:update_index;
wire write_phase=read_valid && !read_snapshot;
wire[35:0]pitch_word;
wire[31:0]pitch_q=pitch_word[31:0];
voice_state_ram #(.AW(5)) pitch_storage(clk,update_active,batch_valid,update_index,batch_index,{4'd0,batch_increment},pitch_word);
integer i;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
 snap_active<=0;update_active<=0;read_valid<=0;read_snapshot<=0;
 snap_index<=0;update_index<=0;read_index<=0;
 reset_pending<=0;step_pending<=0;snap_reset<=0;captured_test<=0;captured_all<=0;fault<=0;
 end else begin
 read_valid<=ren;read_snapshot<=snap_active;read_index<=ra;
 if(sample_ce)begin
  if(snap_active || update_active || read_valid)fault<=1;
  snap_active<=1;snap_index<=0;snap_reset<=reset_pending;
  captured_test<=test_mode;captured_all<=test_all;
 end else if(snap_active)begin
  if(snap_index==31)snap_active<=0;else snap_index<=snap_index+1'b1;
 end
 if(batch_valid && batch_index==31)begin
  if(snap_active || update_active)fault<=1;
  update_active<=1;update_index<=0;
 end else if(update_active)begin
  if(update_index==31)update_active<=0;else update_index<=update_index+1'b1;
 end
 for(i=0;i<VOICES;i=i+1)begin
  if(batch_valid && batch_index==i%32)step_pending[i]<=1;
  if(phase_reset[i])begin reset_pending[i]<=1;step_pending[i]<=0;end
  if(write_phase && read_index==i%32)begin
   reset_pending[i]<=0;step_pending[i]<=0;
   if(batch_valid && batch_index==i%32)fault<=1;
  end
 end
 end
end
function[31:0]test_inc;input integer index;reg[63:0]n;
begin n=(64'd257+64'd83*index)*64'd4294967296;test_inc=(n*512+12300000)/24600000;end endfunction
// Original four-note diagnostic uses the base eight-note increments.
function[31:0]base_inc;input integer index;
begin case(index%8)
0:base_inc=46774041;1:base_inc=52502086;2:base_inc=58931599;3:base_inc=62435854;
4:base_inc=70081876;5:base_inc=78664247;6:base_inc=88297631;7:base_inc=93548082;
default:base_inc=0;
endcase end endfunction
function[1023:0]packed_test_table;input integer lane_number;integer ti;
begin for(ti=0;ti<32;ti=ti+1)packed_test_table[ti*32+:32]=test_inc(lane_number*32+ti);end endfunction
function[31:0]plane_bits_module;input[1023:0]bits;input integer bn;integer n;
begin for(n=0;n<32;n=n+1)plane_bits_module[n]=bits[n*32+bn];end endfunction
genvar g,bit_number;
generate for(g=0;g<LANES;g=g+1)begin:lane
wire[35:0]q;reg[31:0]valid;
reg[319:0]lane_addresses;assign addresses[g*320+:320]=lane_addresses;
localparam[1023:0]TEST_BITS=packed_test_table(g);
wire[31:0]test_lookup;reg[31:0]test_q;
for(bit_number=0;bit_number<32;bit_number=bit_number+1)begin:bit_plane
 localparam[31:0]PLANE=plane_bits_module(TEST_BITS,bit_number);
 assign test_lookup[bit_number]=PLANE[update_index];
end
always @(posedge clk)if(update_active)test_q<=test_lookup;
wire[31:0]old_phase=valid[read_index]?q[31:0]:32'd0;
wire reset_now=reset_pending[g*32+read_index] || phase_reset[g*32+read_index];
wire apply_step=step_pending[g*32+read_index] && !phase_reset[g*32+read_index];
wire[31:0]increment=captured_test?(captured_all?test_q:base_inc(read_index)):(pitch_q>>g);
wire[31:0]next_phase=(reset_now?32'd0:old_phase)+(apply_step?increment:32'd0);
voice_state_ram #(.AW(5)) ram(clk,ren,write_phase,ra,read_index,{4'd0,next_phase},q);
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin valid<=0;lane_addresses<=0;end
 else begin
  if(write_phase)valid[read_index]<=1;
  if(read_valid && read_snapshot)
   lane_addresses[read_index*10+:10]<=snap_reset[g*32+read_index]?10'd0:old_phase[31:22];
 end
end
end endgenerate
endmodule
