`timescale 1ns/1ps
// JDY-31 UART, 8N1. Two-flop RX synchronizer; midpoint start/stop validation.
module bt_uart_rx #(parameter integer CLOCK_HZ=50000000,BAUD=9600)(
 input wire clk,rst_n,rx,output reg [7:0] data,output reg valid,error);
 localparam integer DIV=CLOCK_HZ/BAUD;
 reg meta,sync;reg[2:0] state,bit_index;reg[31:0] timer;reg[7:0] shift;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin meta<=1;sync<=1;end else begin meta<=rx;sync<=meta;end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin state<=0;timer<=0;bit_index<=0;shift<=0;data<=0;valid<=0;error<=0;end
 else begin
  valid<=0;error<=0;
  case(state)
   0:if(!sync)begin timer<=DIV/2-1;state<=1;end
   1:if(timer!=0)timer<=timer-1'b1;else if(sync)state<=0;
     else begin state<=2;timer<=DIV-1;bit_index<=0;end
   2:if(timer!=0)timer<=timer-1'b1;else begin
      shift[bit_index]<=sync;timer<=DIV-1;
      if(bit_index==7)state<=3;else bit_index<=bit_index+1'b1;
     end
   3:if(timer!=0)timer<=timer-1'b1;else begin
      if(sync)begin data<=shift;valid<=1;state<=0;end
      else begin error<=1;state<=4;end
     end
   4:if(sync)state<=0; // One framing error per sustained break, no false commands.
   default:state<=0;
  endcase
 end
endmodule

module bt_uart_tx #(parameter integer CLOCK_HZ=50000000,BAUD=9600)(
 input wire clk,rst_n,send,input wire[7:0] data,output wire tx,output reg busy);
 localparam integer DIV=CLOCK_HZ/BAUD;
 reg[9:0] shift;reg[3:0] bit_index;reg[31:0] timer;
 assign tx=busy ? shift[0] : 1'b1;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin shift<=10'h3ff;bit_index<=0;timer<=0;busy<=0;end
 else if(!busy)begin
  if(send)begin shift<={1'b1,data,1'b0};bit_index<=0;timer<=DIV-1;busy<=1;end
 end else if(timer!=0)timer<=timer-1'b1;
 else if(bit_index==9)busy<=0;
 else begin shift<={1'b1,shift[9:1]};bit_index<=bit_index+1'b1;timer<=DIV-1;end
endmodule

// Exact text frames: @<command> followed by LF or CR (CRLF also allowed).
// Prefix/length enforcement prevents JDY connection logs or arbitrary text
// from being mistaken for performance commands. Partial frames expire at 250ms.
// Replies are one ASCII byte: K=accepted, I=inhibited, E=invalid,
// query replies N=normal, F=FFT, P=lesson paused, R=lesson running, D=done.
module bluetooth_control #(parameter integer CLOCK_HZ=50000000,BAUD=9600,FEATURES=0,PRACTICE=0)(
 input wire clk,rst_n,rx,test_mode,trainer_active,trainer_running,trainer_done,
 output wire tx,output reg key_valid,output reg[7:0] key_mask,
 output reg trainer_toggle,output reg[5:0] effect_events,
 output reg visual_valid,output reg[1:0] visual_select,output wire control_lock, input ext_tx_valid,input[7:0] ext_tx_data,input ext_busy,output ext_tx_ready,output[7:0] rx_data_out,output rx_valid_out,rx_error_out,output command_pending,input practice_mode,output reg practice_start);
 wire[7:0] data;wire valid,error,tx_busy;
 reg send;reg[7:0] reply,command;reg[2:0] state;reg[31:0] age;
 // Serialize local mode changes with a complete remote transaction. Include
 // the pulse/response tail so mode validation and application see one state.
 // State 4 discards an unframed line and does not hold local controls locked.
 assign rx_data_out=data;assign rx_valid_out=valid;assign rx_error_out=error;
 assign command_pending=state==5;
 assign ext_tx_ready=!tx_busy && !send && !(state==5 && !(FEATURES && ext_busy));
 assign control_lock=(state!=0 && state!=4) || valid || send ||
                     key_valid || trainer_toggle || (|effect_events) || visual_valid;
 bt_uart_rx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) receiver(clk,rst_n,rx,data,valid,error);
 bt_uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) transmitter(clk,rst_n,send || (FEATURES && ext_tx_valid && ext_tx_ready),send ? reply : ext_tx_data,tx,tx_busy);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  state<=0;age<=0;command<=0;send<=0;reply<=0;key_valid<=0;key_mask<=0;
  trainer_toggle<=0;practice_start<=0;effect_events<=0;visual_valid<=0;visual_select<=0;
 end else begin
  send<=0;key_valid<=0;trainer_toggle<=0;practice_start<=0;effect_events<=0;visual_valid<=0;
  if(state==5 && !tx_busy && !send && !(FEATURES && ext_busy))begin
   state<=0;
       send<=1;reply<="K";
       if(command>="1" && command<="8")begin
        // Paused-only lesson settings and FFT octave commands match local UI.
        if((trainer_active && command=="7") ||
           (trainer_active && trainer_running && command>="1" && command<="4") ||
           (test_mode && command>="1" && command<="3"))reply<="I";
        else begin key_valid<=1;key_mask<=8'b1 << (command-"1");end
       end else case(command)
        "L":if(!PRACTICE || test_mode || trainer_active)reply<="I";else begin trainer_toggle<=1;practice_start<=1;end
        "T":if(test_mode)reply<="I";else trainer_toggle<=1;
        "A","B","C","D":if(test_mode)reply<="I";
          else case(command)
           "A":effect_events<=6'b000001; // timbre
           "B":effect_events<=6'b000100; // glide
           "C":effect_events<=6'b001000; // vibrato
           "D":effect_events<=6'b000010; // echo
          endcase
        "W","S","X","R":if(test_mode || trainer_active)reply<="I";
          else begin visual_valid<=1;visual_select<=command=="W"?0:command=="S"?1:command=="X"?2:3;end
        "?":reply<=trainer_active ? ((PRACTICE && practice_mode)?(trainer_done?"O":trainer_running?"J":"H"):(trainer_done?"D":trainer_running?"R":"P")) : test_mode?"F":"N";
        default:reply<="E";
       endcase
  end
  if(state!=0 && state!=5)begin
   if(age==CLOCK_HZ/4-1)begin state<=0;age<=0;end else age<=age+1'b1;
  end
  if(error)begin state<=0;age<=0;end
  else if(state!=0 && state!=5 && age==CLOCK_HZ/4-1)begin state<=0;age<=0;end
  else if(valid && state!=5)begin
   age<=0;
   case(state)
    0:if(data=="@")state<=1;else if(data!=10 && data!=13)state<=4;
    1:if(data==10 || data==13)begin state<=0;if(!tx_busy && !(FEATURES && ext_busy))begin send<=1;reply<="E";end end
      else begin command<=data;state<=2;end
    2:if(data==10 || data==13)begin
      state<=0;
      // One outstanding command is retained until the current audio packet
      // and extension response finish. The companion app waits for its ACK.
      state<=5;
     end else state<=3;
    3:if(data==10 || data==13)begin state<=0;if(!tx_busy && !(FEATURES && ext_busy))begin send<=1;reply<="E";end end
    4:if(data==10 || data==13)state<=0;
    default:state<=0;
   endcase
  end
 end
endmodule
