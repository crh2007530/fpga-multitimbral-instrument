`timescale 1ns/1ps
// Registered character lookup is the existing second label stage, not extra latency.
module video_mixer_char(input clk,input[21:0] descriptor,output[7:0] letter);
 reg[7:0] strings[0:2047];initial $readmemh("assets/mixer_strings.hex",strings);
 reg[7:0] rom_q,suffix_q;reg use_suffix_q;
 wire[4:0] index=descriptor[15:11];wire[3:0] kind=descriptor[10:7];wire[6:0] value=descriptor[6:0];
 reg[63:0] suffix;reg selected;reg[7:0] selected_char;
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
 suffix=0;selected=0;selected_char=0;
 case(kind)
 1:suffix={gain_text(value[4:0]),32'd0};
 2:suffix=value==0?64'h05030c0747550000:value==1?64'h09060c0347550000:64'h0208010c06475500;
 3:suffix={value==0?32'h010b0000:value==1?32'h02040b00:value==2?32'h03060b00:value==3?32'h04090b00:value==4?32'h06010b00:value==5?32'h07040b00:32'h08060b00,32'd0};
 4:suffix={value==0?32'hb3000000:value==1?32'h12000000:32'h72000000,32'd0};
 5:suffix={volume_text(value),32'd0};
 default:suffix=0;
 endcase
 if(kind>=1 && kind<=4 && index>=6 && index<(kind==2?14:10))begin
 selected=1;selected_char=suffix[(13-index)*8+:8];end
 if(kind==5 && index>=12 && index<16)begin
 selected=1;selected_char=suffix[(19-index)*8+:8];end
 end
 always @(posedge clk)begin rom_q<=strings[descriptor[21:11]];suffix_q<=selected_char;use_suffix_q<=selected;end
 assign letter=use_suffix_q?suffix_q:rom_q;
endmodule

