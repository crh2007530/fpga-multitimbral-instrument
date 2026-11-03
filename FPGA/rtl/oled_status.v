`timescale 1ns/1ps
module touch_event_history (
    input wire clk, rst_n, event_valid,
    input wire [7:0] press_mask, release_mask,
    input wire [55:0] note_ids,
    output reg [111:0] records,
    output reg [3:0] valid,
    output reg [15:0] count_bcd
);
    reg [7:0] pending, pending_down;
    reg [55:0] pending_notes;
    reg [2:0] zone;
    integer i;
    always @(*) begin
        zone=0;
        for (i=7;i>=0;i=i-1) if (pending[i]) zone=i[2:0];
    end
    function [15:0] increment_bcd;
        input [15:0] value;
        begin
            if (value[3:0]<9) increment_bcd={value[15:4],value[3:0]+4'd1};
            else if (value[7:4]<9) increment_bcd={value[15:8],value[7:4]+4'd1,4'd0};
            else if (value[11:8]<9) increment_bcd={value[15:12],value[11:8]+4'd1,8'd0};
            else if (value[15:12]<9) increment_bcd={value[15:12]+4'd1,12'd0};
            else increment_bcd=0;
        end
    endfunction
    wire [15:0] next_count=increment_bcd(count_bcd);
    wire [3:0] zone_number={1'b0,zone}+4'd1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            records<=0; valid<=0; count_bcd<=0;
            pending<=0; pending_down<=0; pending_notes<=0;
        end else if (event_valid) begin
            pending<=press_mask | release_mask;
            pending_down<=press_mask; pending_notes<=note_ids;
        end else if (|pending) begin
            records<={records[83:0],next_count,zone_number,pending_down[zone],pending_notes[7*zone +: 7]};
            valid<={valid[2:0],1'b1}; count_bcd<=next_count;
            pending[zone]<=0;
        end
    end
endmodule

module oled_i2c_token #(
    parameter integer HALF_CYCLES = 250
)(
    input wire clk, rst_n, request,
    input wire [1:0] operation, // 0=START, 1=BYTE, 2=STOP
    input wire [7:0] data,
    output reg done, ack,
    output wire scl,
    inout wire sda
);
    localparam [3:0] IDLE=0, START_A=1, START_B=2, BIT_LOW=3,
        BIT_HIGH=4, ACK_LOW=5, ACK_HIGH=6, STOP_A=7, STOP_B=8, STOP_C=9;
    localparam integer TIMER_WIDTH = (HALF_CYCLES<2) ? 1 : $clog2(HALF_CYCLES);
    localparam [TIMER_WIDTH-1:0] LAST_TICK = HALF_CYCLES-1;
    reg [3:0] state;
    reg [TIMER_WIDTH-1:0] timer;
    reg [2:0] bit_index;
    reg [7:0] shift;
    reg scl_low, sda_low, sda_meta, sda_sync;
    // Both lines are open drain: only drive LOW, otherwise release.
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin sda_meta<=1; sda_sync<=1; end
        else begin sda_meta<=sda; sda_sync<=sda_meta; end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; timer<=0; bit_index<=0; shift<=0;
            scl_low<=0; sda_low<=0; done<=0; ack<=0;
        end else begin
            done<=0;
            if (state==IDLE) begin
                timer<=0;
                if (request) begin
                    case (operation)
                        0: begin scl_low<=0; sda_low<=0; state<=START_A; end
                        1: begin
                            scl_low<=1; shift<=data; bit_index<=7;
                            sda_low<=~data[7]; state<=BIT_LOW;
                        end
                        2: begin scl_low<=1; sda_low<=1; state<=STOP_A; end
                        default: done<=1;
                    endcase
                end
            end else if (timer==LAST_TICK) begin
                timer<=0;
                case (state)
                    START_A: begin sda_low<=1; state<=START_B; end
                    START_B: begin scl_low<=1; state<=IDLE; done<=1; end
                    BIT_LOW: begin scl_low<=0; state<=BIT_HIGH; end
                    BIT_HIGH: begin
                        scl_low<=1;
                        if (bit_index==0) begin sda_low<=0; state<=ACK_LOW; end
                        else begin
                            bit_index<=bit_index-3'd1;
                            sda_low<=~shift[bit_index-3'd1]; state<=BIT_LOW;
                        end
                    end
                    ACK_LOW: begin scl_low<=0; state<=ACK_HIGH; end
                    ACK_HIGH: begin
                        ack<=~sda_sync; scl_low<=1; state<=IDLE; done<=1;
                    end
                    STOP_A: begin scl_low<=0; state<=STOP_B; end
                    STOP_B: begin sda_low<=0; state<=STOP_C; end
                    STOP_C: begin state<=IDLE; done<=1; end
                    default: begin state<=IDLE; scl_low<=0; sda_low<=0; end
                endcase
            end else timer<=timer+1'b1;
        end
    end
endmodule

// SSD1306, 128x64, page addressing. No framebuffer RAM required.
// Repaints all eight pages from one snapshot of status and event history.
module oled_status #(
    parameter integer EXTENDED=0, EXPANSION=0, EXPRESSION=0, WAVEFORM=0, TRAINER=0, HDMI_STATUS=0,
    parameter [6:0] ADDRESS = 7'h3c,
    parameter integer POWERUP_MS = 100,
    parameter integer HALF_CYCLES = 250,
    parameter [3:0] COLUMN_OFFSET = 0
)(
    input wire clk, rst_n,
    input wire [39:0] trainer_status,input wire [7:0] trainer_target,trainer_next,
    input wire [1:0] visual_mode,input wire [74:0] spectrum_bars,
    input wire [319:0] wave_points,
    input wire [3:0] expression_config,
    input wire [1:0] octave, // All voices: 0=middle, 1=one octave down, 2=one up
    input wire [10:0] keys,
    input wire [111:0] history,
    input wire [3:0] history_valid,
    input wire [15:0] event_count,
    output wire [1343:0] screen_text,
    output reg [1:0] screen_pitch,
    output reg [7:0] screen_pressed,
    output reg [15:0] screen_id,
    output reg screen_online, screen_available,
    output wire scl,
    inout wire sda, input wire [15:0] voice_modes,input wire [3:0] selected,test_mask,input wire test_mode, input wire chord_mode,test32,input wire [5:0] selected_test,input wire [63:0] mask32
);
    localparam [3:0] BOOT=0, START_SEND=1, START_WAIT=2, BYTE_SEND=3,
        BYTE_WAIT=4, STOP_SEND=5, STOP_WAIT=6, FRAME_PAUSE=7, PIXEL_PREP0=8, PIXEL_PREP1=9, PIXEL_PREP2=10, XY_SCAN=11;
    localparam [1:0] INITIALIZE=0, PAGE_COMMAND=1, PAGE_DATA=2;
    localparam integer POWERUP_CYCLES = 50000*POWERUP_MS;
    reg [3:0] state;
    reg [1:0] segment;
    reg [31:0] timer;
    reg [7:0] byte_index;
    reg [2:0] page, glyph_column;
    reg [4:0] character_index;
    reg [1:0] frame_octave;
    reg [10:0] frame_keys;
    reg [127:0] frame_history;
    reg [3:0] frame_history_valid;
    reg [15:0] frame_event_count;
    reg [15:0] screen_event_count;
    reg [127:0] screen_context;
    wire [127:0] live_context=EXPANSION ? {(TRAINER ? trainer_target : 8'd0),(TRAINER ? trainer_next : 8'd0),{selected_test[5],1'b1},(TRAINER ? trainer_status : 40'd0),(WAVEFORM ? visual_mode : 2'd0),(EXPRESSION ? expression_config : 4'd0),(selected_test[5]?mask32[63:32]:mask32[31:0]),selected_test[4:0],test32,chord_mode,test_mode,test_mask,selected,voice_modes} : {87'd0,test_mode,test_mask,selected,voice_modes};
    reg [319:0] frame_wave;
    reg [74:0] frame_spectrum;
    reg failed;
    reg request;
    reg [1:0] operation;
    reg [7:0] tx_data;
    wire done, ack;
    oled_i2c_token #(.HALF_CYCLES(HALF_CYCLES)) u_bus (
        .clk(clk), .rst_n(rst_n), .request(request), .operation(operation),
        .data(tx_data), .done(done), .ack(ack), .scl(scl), .sda(sda)
    );

    function [7:0] init_byte;
        input [7:0] index;
        begin
            case (index)
                8'd0: init_byte=8'hae;
                8'd1: init_byte=8'hd5;
                8'd2: init_byte=8'h80;
                8'd3: init_byte=8'ha8;
                8'd4: init_byte=8'h3f;
                8'd5: init_byte=8'hd3;
                8'd6: init_byte=8'h00;
                8'd7: init_byte=8'h40;
                8'd8: init_byte=8'h8d;
                8'd9: init_byte=8'h14;
                8'd10: init_byte=8'h20;
                8'd11: init_byte=8'h02;
                8'd12: init_byte=8'ha1;
                8'd13: init_byte=8'hc8;
                8'd14: init_byte=8'hda;
                8'd15: init_byte=8'h12;
                8'd16: init_byte=8'h81;
                8'd17: init_byte=8'h7f;
                8'd18: init_byte=8'hd9;
                8'd19: init_byte=8'hf1;
                8'd20: init_byte=8'hdb;
                8'd21: init_byte=8'h40;
                8'd22: init_byte=8'ha4;
                8'd23: init_byte=8'ha6;
                8'd24: init_byte=8'haf;
                default: init_byte=8'haf;
            endcase
        end
    endfunction

    // Publish only completely ACKed frames. UART therefore mirrors a completed
    // screen, rather than mixing live inputs with a partially refreshed OLED.
    genvar text_index;
    generate for(text_index=0;text_index<168;text_index=text_index+1) begin: published_text
        assign screen_text[text_index*8 +: 8]=screen_available ?
            text_char(text_index/21,text_index%21,screen_pitch,{3'b0,screen_pressed},
                screen_context,4'd0,screen_event_count) : 8'h20;
    end endgenerate

    function [7:0] text_char;
        input [2:0] row;
        input [4:0] pos;
        input [1:0] bank;
        input [10:0] pressed;
        input [127:0] events;
        input [3:0] events_valid;
        input [15:0] total;
        reg [167:0] line;
        reg [2:0] zone;
        reg [4:0] cell_pos;
        begin
            line="                     ";
            zone=0; cell_pos=0;
            case (row)
                0: begin
                    case (bank)
                        1: line="LOW C4  261.63HZ     ";
                        2: line="HIGH C6 1046.50HZ    ";
                        default: line="MID C5  523.25HZ     ";
                    endcase
                end
                1: line="KEYS: -------- E:0000";
                2: line="1=LOW 2=MID 3=HIGH   ";
                3: line="ON=20 OFF=10 HYST    ";
                default: line="                     ";
            endcase
            if(EXTENDED)begin
                if(row==0)line=events[24] ? "FFT PURE 4 VOICES    " : "PLAY PER-VOICE       ";
                if(row==2)line="SEL:Z1  4:NEXT 7:ALL ";
            end
            if(EXPANSION)begin
                if(row==0 && events[25] && !events[24])line="CHORD 64  8 PADS X8  ";
                if(row==0 && events[26] && events[24])line="FFT PURE 64 VOICES   ";
                if(row==2 && events[26] && events[24])line="SEL:V01 4:NEXT 6:MUTE";
                if(row==3 && events[26] && events[24])line="MASK:FFFFFFFF 7:ALL  ";
            end
            if(EXPRESSION && row==3 && !events[24])begin
              line="T:REED G:0 V:0 E:0   ";
              if(events[64])line="T:FLUT G:0 V:0 E:0   ";
            end
            if(WAVEFORM && row==2 && !events[24])begin
                case(events[69:68])
                0:line="WAVE 10.66MS WINDOW  ";
                1:line="DFT 188-2815HZ      ";
                2:line="XY PCM VS DELAY     ";
                default:line="                     ";
                endcase
            end
            if(WAVEFORM && row>=4 && !events[24])begin
                if(row==4)begin
                  case(events[69:68])
                    0:line="LIVE PCM WAVEFORM    ";
                    1:line="LIVE PCM SPECTRUM    ";
                    2:line="LIVE PCM DELAY XY    ";
                    default:line="                     ";
                  endcase
                end else line="                     ";
            end
            if(HDMI_STATUS && !events[24] && row>=4)begin
                case(row)
                  4:line="HDMI: WAVE FFT XY    ";
                  5:line="FX / LEVEL ON HDMI  ";
                  6:line="GAME: HOLD TOUCH 7  ";
                  7:line="GAME SPEED ON HDMI  ";
                endcase
            end
            if (pos>20) text_char=8'h20;
            else text_char=line[167-8*pos -: 8];
            if(EXTENDED && !WAVEFORM && row==2 && !(EXPANSION && events[26] && events[24]))begin
                if(events[19:16]==8 && pos>=4 && pos<=6)case(pos)
                  4:text_char="A";5:text_char="L";6:text_char="L";
                endcase
                else if(pos==5)text_char=49+events[19:16];
            end
            if(EXPANSION && events[26] && events[24])begin
              if(row==3 && pos>=5 && pos<=12)begin
                text_char=(events[32+4*(12-pos)+:4]<10) ? 48+events[32+4*(12-pos)+:4] : 55+events[32+4*(12-pos)+:4];
              end
            end
            if (row==1 && pos>=6 && pos<=13)
                text_char=pressed[pos-6] ? (8'd49+{3'd0,pos}-8'd6) : 8'h2d;
            if (row==1 && pos>=17 && pos<=20)
                text_char=8'd48+{4'd0,total[4*(20-pos) +: 4]};
            if(EXPRESSION && row==3 && !events[24])begin
              if(pos==9)text_char=events[65]?"1":"0";
              if(pos==13)text_char=events[66]?"1":"0";
              if(pos==17)text_char=events[67]?"1":"0";
            end
            // Two live zones per row. Inactive zones leave no Z label behind.
            if (!WAVEFORM && row>=4 && !(EXPANSION && events[26] && events[24])) begin
                zone={(row[1:0]),1'b0} + ((pos>=11) ? 3'd1 : 3'd0);
                cell_pos=(pos>=11) ? pos-5'd11 : pos;
                if (pressed[zone]) case (cell_pos)
                    0:text_char="Z";
                    1:text_char=8'd49+{5'd0,zone};
                    3:case(zone)
                        1:text_char="D"; 2:text_char="E"; 3:text_char="F";
                        4:text_char="G"; 5:text_char="A"; 6:text_char="B";
                        default:text_char="C";
                    endcase
                    4:text_char=((zone==7) ? 8'd54 : 8'd53) +
                        ((EXTENDED ? (!events[24] && events[zone*2+:2]==1) : bank==1) ? -8'd1 :
                         (EXTENDED ? (!events[24] && events[zone*2+:2]==2) : bank==2) ? 8'd1 : 8'd0);
                    6:text_char="O";
                    7:text_char="N";
                    default:text_char=" ";
                endcase
            end
            if(TRAINER && events[70])begin
              case(row)
                0:case(events[75:74])
                  0:line="TWINKLE STAR         ";default:line="UPLOADED SCORE       ";
                endcase
                1:begin
                  line=events[72]?"DONE  BPM:090 RHYTHM ":events[71]?"RUN   BPM:090 RHYTHM ":"PAUSE BPM:090 RHYTHM ";
                  if(events[73])line=events[72]?"DONE  BPM:090 WAIT   ":events[71]?"RUN   BPM:090 WAIT   ":"PAUSE BPM:090 WAIT   ";
                end
                2:line="1:60 2:120 3:240     ";
                3:line="NOW: --------        ";
                4:line="NEXT:--------        ";
                5:line="OK:000 MISS:000      ";
                6:line="WRONG:000 5:PLAY     ";
                7:line="5:PLAY 6:RESET 8:EXIT";
              endcase
              if(events[75:74]!=0)begin
                if(row==1)line=events[72]?"DONE CUSTOM TEMPO    ":events[71]?"RUN CUSTOM TEMPO     ":"PAUSE CUSTOM TEMPO   ";
                if(row==2)line="TEMPO FROM SCORE     ";
              end
              text_char=pos>20 ? 8'h20 : line[167-8*pos-:8];
              if(events[75:74]==0 && row==1 && pos==10)text_char=events[77:76]==0 ? "0" : events[77:76]==1 ? "1" : "2";
              if(events[75:74]==0 && row==1 && pos==11)text_char=events[77:76]==0 ? "6" : events[77:76]==1 ? "2" : "4";
              if(row==3 && pos>=5 && pos<=12)text_char=events[120+pos-5] ? 8'd49+{3'd0,pos}-8'd5 : 8'h2d;
              if(row==4 && pos>=5 && pos<=12)text_char=events[112+pos-5] ? 8'd49+{3'd0,pos}-8'd5 : 8'h2d;
              if(row==5 && pos==3)text_char=8'd48+events[93:86]/8'd100;
              if(row==5 && pos==4)text_char=8'd48+(events[93:86]/8'd10)%8'd10;
              if(row==5 && pos==5)text_char=8'd48+events[93:86]%8'd10;
              if(row==5 && pos==12)text_char=8'd48+events[101:94]/8'd100;
              if(row==5 && pos==13)text_char=8'd48+(events[101:94]/8'd10)%8'd10;
              if(row==5 && pos==14)text_char=8'd48+events[101:94]%8'd10;
              if(row==6 && pos==6)text_char=8'd48+events[109:102]/8'd100;
              if(row==6 && pos==7)text_char=8'd48+(events[109:102]/8'd10)%8'd10;
              if(row==6 && pos==8)text_char=8'd48+events[109:102]%8'd10;
            end
        end
    endfunction

    function [39:0] font;
        input [7:0] ascii;
        begin
            case (ascii)
                8'h30: font=40'h3e4549513e; // 0
                8'h31: font=40'h00407f4200; // 1
                8'h32: font=40'h4649516142; // 2
                8'h33: font=40'h314b454121; // 3
                8'h34: font=40'h107f121418; // 4
                8'h35: font=40'h3945454527; // 5
                8'h36: font=40'h3049494a3c; // 6
                8'h37: font=40'h0305097101; // 7
                8'h38: font=40'h3649494936; // 8
                8'h39: font=40'h1e29494906; // 9
                8'h41: font=40'h7e1111117e; // A
                8'h42: font=40'h364949497f; // B
                8'h43: font=40'h224141413e; // C
                8'h44: font=40'h1c2241417f; // D
                8'h45: font=40'h414949497f; // E
                8'h46: font=40'h010909097f; // F
                8'h47: font=40'h324949413e; // G
                8'h48: font=40'h7f0808087f; // H
                8'h49: font=40'h00417f4100; // I
                8'h4a: font=40'h013f414020; // J
                8'h4b: font=40'h412214087f; // K
                8'h4c: font=40'h404040407f; // L
                8'h4d: font=40'h7f020c027f; // M
                8'h4e: font=40'h7f1008047f; // N
                8'h4f: font=40'h3e4141413e; // O
                8'h50: font=40'h060909097f; // P
                8'h51: font=40'h5e2151413e; // Q
                8'h52: font=40'h462919097f; // R
                8'h53: font=40'h3149494946; // S
                8'h54: font=40'h01017f0101; // T
                8'h55: font=40'h3f4040403f; // U
                8'h56: font=40'h1f2040201f; // V
                8'h57: font=40'h3f4038403f; // W
                8'h58: font=40'h6314081463; // X
                8'h59: font=40'h0708700807; // Y
                8'h5a: font=40'h4345495161; // Z
                8'h2d: font=40'h0808080808; // -
                8'h3a: font=40'h0000363600; // :
                8'h3d: font=40'h1414141414; // =
                8'h2f: font=40'h0204081020; // /
                8'h2e: font=40'h0000606000; // .
                8'h3e: font=40'h0008142241; // >
                default: font=40'd0;
            endcase
        end
    endfunction
    wire [7:0] character = text_char(page, character_index, frame_octave, frame_keys,
        frame_history, frame_history_valid, frame_event_count);
    reg [7:0] character_q;
    wire [39:0] glyph = font(character_q);
    reg [7:0] pixels;
    wire [6:0] wave_x=(byte_index-8'd2)>>1;
    reg [8:0] wave_address_q, previous_address_q;
    reg [4:0] wave_y, wave_previous;
    reg [7:0] pixels_q;
    // Address -> waveform sample -> raster. Three preparation clocks precede
    // each I2C byte; no false-path or multicycle timing exception is needed.
    always @(posedge clk or negedge rst_n)begin
      if(!rst_n)begin character_q<=0;wave_address_q<=0;previous_address_q<=0;wave_y<=16;wave_previous<=16;pixels_q<=0;end
      else begin
        character_q<=character;
        wave_address_q<=wave_x*9'd5;
        previous_address_q<=(wave_x==0 ? 7'd0 : wave_x-1'b1)*9'd5;
        wave_y<=HDMI_STATUS?5'd16:frame_wave[wave_address_q+:5];
        wave_previous<=HDMI_STATUS?5'd16:frame_wave[previous_address_q+:5];
        pixels_q<=pixels;
      end
    end
    integer wave_bit;
    integer wave_row;
    reg [5:0] xy_index;
    reg [7:0] xy_pixels;
    wire [4:0] xy_sample_x=HDMI_STATUS?5'd0:frame_wave[4:0];
    wire [4:0] xy_sample_y=HDMI_STATUS?5'd0:frame_wave[24:20];
    wire xy_active=WAVEFORM && !HDMI_STATUS && page>=4 && !frame_history[24] &&
        !(TRAINER && frame_history[70]) && frame_history[69:68]==2;
    wire [6:0] pixel_x=byte_index[6:0]-7'd2;
    reg [4:0] spec_height;
    always @(*) begin
        spec_height=0;wave_row=0;wave_bit=0;
        case (glyph_column)
            0:pixels=glyph[7:0]; 1:pixels=glyph[15:8]; 2:pixels=glyph[23:16];
            3:pixels=glyph[31:24]; 4:pixels=glyph[39:32];
            default:pixels=0;
        endcase
        if(WAVEFORM && !HDMI_STATUS && page>=4 && !frame_history[24] && !(TRAINER && frame_history[70]))begin
            pixels=0;
            for(wave_bit=0;wave_bit<8;wave_bit=wave_bit+1)begin
                wave_row=(page-4)*8+wave_bit;
                if((wave_row>=wave_y && wave_row<=wave_previous) ||
                   (wave_row>=wave_previous && wave_row<=wave_y)) pixels[wave_bit]=1;
                // Dotted zero reference, 8 pixels apart.
                if(wave_row==16 && byte_index[2:0]==2) pixels[wave_bit]=1;
                if(frame_history[69:68]==1)begin
                    spec_height=0;
                    if(pixel_x<120)spec_height=frame_spectrum[(pixel_x/8)*5+:5];
                    pixels[wave_bit]=(pixel_x<120 && pixel_x%8<6 && wave_row>=32-spec_height);
                end
                // XY pixels are accumulated over 64 clocks (60 points plus 4 rotations to restore) before I2C sends.
                if(frame_history[69:68]==2)pixels[wave_bit]=0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=BOOT; segment<=INITIALIZE; timer<=0; byte_index<=0;xy_index<=0;xy_pixels<=0;
            page<=0; glyph_column<=0; character_index<=0;
            frame_spectrum<=0;frame_wave<={64{5'd16}}; frame_octave<=1; frame_keys<=0; failed<=0;
            frame_history<=0; frame_history_valid<=0; frame_event_count<=0;
            screen_context<=0;screen_pitch<=0; screen_pressed<=0; screen_id<=0; screen_event_count<=0;
            screen_online<=0; screen_available<=0;
            request<=0; operation<=0; tx_data<=0;
        end else begin
            request<=0;
            case (state)
                BOOT: begin
                    if (timer>=POWERUP_CYCLES-1) begin
                        timer<=0; segment<=INITIALIZE; failed<=0; state<=START_SEND;
                    end else timer<=timer+32'd1;
                end
                START_SEND: begin
                    operation<=0; request<=1; byte_index<=0;
                    glyph_column<=0; character_index<=0; state<=START_WAIT;
                end
                START_WAIT: if (done) state<=PIXEL_PREP0;
                PIXEL_PREP0: state<=PIXEL_PREP1;
                PIXEL_PREP1: state<=PIXEL_PREP2;
                PIXEL_PREP2: begin
                    if(xy_active && segment==PAGE_DATA && byte_index>=2)begin
                        xy_index<=0;xy_pixels<=0;state<=XY_SCAN;
                    end else state<=BYTE_SEND;
                end
                XY_SCAN: begin
                    frame_wave<={frame_wave[4:0],frame_wave[319:5]};
                    if(xy_index<60 && pixel_x[6:2]==xy_sample_x && page[1:0]==xy_sample_y[4:3])
                        xy_pixels[xy_sample_y[2:0]]<=1'b1;
                    if(xy_index==63)state<=BYTE_SEND;
                    else xy_index<=xy_index+1'b1;
                end
                BYTE_SEND: begin
                    operation<=1; request<=1; state<=BYTE_WAIT;
                    if (byte_index==0) tx_data<={ADDRESS,1'b0};
                    else if (byte_index==1) tx_data<=(segment==PAGE_DATA) ? 8'h40 : 8'h00;
                    else begin
                        case (segment)
                            INITIALIZE: tx_data<=init_byte(byte_index-8'd2);
                            PAGE_COMMAND: begin
                                case (byte_index)
                                    2:tx_data<={5'b10110,page};
                                    3:tx_data<={4'h0,COLUMN_OFFSET};
                                    default:tx_data<=8'h10;
                                endcase
                            end
                            default: tx_data<=xy_active ? xy_pixels : pixels_q;
                        endcase
                    end
                end
                BYTE_WAIT: if (done) begin
                    if (!ack) begin failed<=1; screen_online<=0; state<=STOP_SEND; end
                    else if ((segment==INITIALIZE && byte_index==8'd26) ||
                             (segment==PAGE_COMMAND && byte_index==8'd4) ||
                             (segment==PAGE_DATA && byte_index==8'd129)) state<=STOP_SEND;
                    else begin
                        byte_index<=byte_index+8'd1; state<=PIXEL_PREP0;
                        if (segment==PAGE_DATA && byte_index>=2) begin
                            if (glyph_column==5) begin
                                glyph_column<=0; character_index<=character_index+5'd1;
                            end else glyph_column<=glyph_column+3'd1;
                        end
                    end
                end
                STOP_SEND: begin operation<=2; request<=1; state<=STOP_WAIT; end
                STOP_WAIT: if (done) begin
                    if (failed) begin timer<=0; state<=BOOT; end
                    else case (segment)
                        INITIALIZE: begin
                            page<=0; segment<=PAGE_COMMAND; state<=START_SEND;
                            frame_spectrum<=spectrum_bars;frame_wave<=wave_points; frame_octave<=octave; frame_keys<=keys;
                            frame_history<=EXTENDED ? live_context : history; frame_history_valid<=history_valid; frame_event_count<=event_count;
                        end
                        PAGE_COMMAND: begin segment<=PAGE_DATA; state<=START_SEND; end
                        default: begin
                            if (page==7) begin
                                timer<=0; state<=FRAME_PAUSE;
                                screen_context<=frame_history;screen_pitch<=frame_octave; screen_pressed<=frame_keys[7:0];
                                screen_event_count<=frame_event_count; screen_id<=screen_id+16'd1;
                                screen_online<=1; screen_available<=1;
                            end
                            else begin
                                page<=page+3'd1; segment<=PAGE_COMMAND; state<=START_SEND;
                            end
                        end
                    endcase
                end
                FRAME_PAUSE: begin
                    if (timer>=32'd1000000-1) begin
                        timer<=0; page<=0; segment<=PAGE_COMMAND; state<=START_SEND;
                        frame_spectrum<=spectrum_bars;frame_wave<=wave_points; frame_octave<=octave; frame_keys<=keys;
                        frame_history<=EXTENDED ? live_context : history; frame_history_valid<=history_valid; frame_event_count<=event_count;
                    end else timer<=timer+32'd1;
                end
                default: begin state<=BOOT; timer<=0; end
            endcase
        end
    end
endmodule

// TTP229 two-wire serial, 16-key active-low. Sample 5 us after each
// falling SCL, leave SCL high between bursts for >2 ms recovery.
