// Buffered raw APDS9960 samples, ASCII hex, 8N1 UART. No sensor backpressure.
module gesture_uart_logger #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 115200,
    parameter integer FIFO_ADDR_BITS = 8,
    parameter integer EVENT_ADDR_BITS = 4
) (
    input wire clk, input wire rst_n,
    input wire sample_valid,
    input wire [7:0] sample_u, sample_d, sample_l, sample_r,
    output wire uart_tx,
    output reg [31:0] dropped_samples,
    input wire swipe_up,swipe_down,swipe_left,swipe_right,
    output reg [31:0] dropped_events
);
    localparam integer DEPTH = 2**FIFO_ADDR_BITS;
    localparam [1:0] IDLE=0, SEND=1, WAIT_TX=2;
    localparam [2:0] BOOT=0, DATA=1, OVERFLOW=2, GESTURE=3, EVENT_OVERFLOW=4;
    reg [31:0] memory [0:DEPTH-1];
    reg [FIFO_ADDR_BITS-1:0] wr_ptr, rd_ptr;
    reg [FIFO_ADDR_BITS:0] count;
    reg [31:0] active_sample;
    reg [1:0] state;
    reg [2:0] kind;
    reg [4:0] char_index;
    reg boot_pending, overflow_reported,event_overflow_reported;
    localparam integer EVENT_DEPTH=2**EVENT_ADDR_BITS;
    reg [2:0] event_memory[0:EVENT_DEPTH-1];
    reg [EVENT_ADDR_BITS-1:0] event_wr,event_rd;
    reg [EVENT_ADDR_BITS:0] event_count;
    reg [2:0] active_event;
    wire event_valid=swipe_up || swipe_down || swipe_left || swipe_right;
    wire [2:0] event_code=swipe_up?3'd1:swipe_down?3'd2:swipe_left?3'd3:3'd4;
    wire event_push=event_valid && event_count<EVENT_DEPTH;
    wire event_pop=state==IDLE && !boot_pending &&
        !(dropped_samples!=0 && !overflow_reported) &&
        !(dropped_events!=0 && !event_overflow_reported) && event_count!=0;
    wire pop = state==IDLE && !boot_pending &&
               !(dropped_samples!=0 && !overflow_reported) &&
               !(dropped_events!=0 && !event_overflow_reported) && event_count==0 && count!=0;
    // Reject writes while full, even if a pop occurs this clock. This avoids
    // undefined same-address read/write behavior in the inferred dual-port RAM.
    wire push = sample_valid && count<DEPTH;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy, tx_done;

    function [7:0] hex_ascii;
        input [3:0] nibble;
        begin hex_ascii = nibble<4'd10 ? 8'h30+{4'b0,nibble} :
                                       8'h41+({4'b0,nibble}-8'd10); end
    endfunction

    reg [7:0] character;
    reg [39:0] event_name;
    reg [2:0] event_length;
    always @* begin
        case(active_event)
            1:begin event_name="UP   ";event_length=2;end
            2:begin event_name="DOWN ";event_length=4;end
            3:begin event_name="LEFT ";event_length=4;end
            default:begin event_name="RIGHT";event_length=5;end
        endcase
    end
    always @* begin
        character=8'h20;
        case(kind)
            BOOT: case(char_index)
                0: character="U"; 1: character="A"; 2: character="R";
                3: character="T"; 4: character=" "; 5: character="O";
                6: character="K"; 7: character=8'h0d; 8: character=8'h0a;
                default: character=" ";
            endcase
            OVERFLOW: case(char_index)
                0: character="O"; 1: character="V"; 2: character="F";
                3: character=8'h0d; 4: character=8'h0a;
                default: character=" ";
            endcase
            GESTURE,EVENT_OVERFLOW: begin
                case(char_index)
                    0:character="G";1:character="E";2:character="S";3:character="T";
                    4:character="U";5:character="R";6:character="E";
                    7:character=(kind==GESTURE)?"=":"_";
                    8:character=(kind==GESTURE)?event_name[39:32]:"O";
                    9:character=(kind==GESTURE)?event_name[31:24]:"V";
                    10:character=(kind==GESTURE)?event_name[23:16]:"F";
                    11:character=(kind==GESTURE)?event_name[15:8]:8'h0d;
                    12:character=(kind==GESTURE)?event_name[7:0]:8'h0a;
                    default:character=" ";
                endcase
                if(kind==GESTURE)begin
                    if(char_index==8+event_length)character=8'h0d;
                    if(char_index==9+event_length)character=8'h0a;
                end
            end
            DATA: case(char_index)
                0: character="U"; 1: character="=";
                2: character=hex_ascii(active_sample[31:28]);
                3: character=hex_ascii(active_sample[27:24]);
                5: character="D"; 6: character="=";
                7: character=hex_ascii(active_sample[23:20]);
                8: character=hex_ascii(active_sample[19:16]);
                10: character="L"; 11: character="=";
                12: character=hex_ascii(active_sample[15:12]);
                13: character=hex_ascii(active_sample[11:8]);
                15: character="R"; 16: character="=";
                17: character=hex_ascii(active_sample[7:4]);
                18: character=hex_ascii(active_sample[3:0]);
                19: character=8'h0d; 20: character=8'h0a;
                default: character=" ";
            endcase
            default: character=" ";
        endcase
    end
    wire last_character = (kind==BOOT && char_index==8) ||
                          (kind==OVERFLOW && char_index==4) ||
                          (kind==DATA && char_index==20) ||
                          (kind==GESTURE && char_index==9+event_length) ||
                          (kind==EVENT_OVERFLOW && char_index==12);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_ptr<=0; rd_ptr<=0; count<=0; dropped_samples<=0;
            active_sample<=0; state<=IDLE; kind<=BOOT; char_index<=0;
            boot_pending<=1; overflow_reported<=0; tx_start<=0; tx_data<=0;
            event_wr<=0;event_rd<=0;event_count<=0;active_event<=0;
            dropped_events<=0;event_overflow_reported<=0;
        end else begin
            tx_start<=0;
            if(event_push)begin event_memory[event_wr]<=event_code;event_wr<=event_wr+1'b1;end
            if(event_pop)begin active_event<=event_memory[event_rd];event_rd<=event_rd+1'b1;end
            case({event_push,event_pop})
                2'b10:event_count<=event_count+1'b1;
                2'b01:event_count<=event_count-1'b1;
                default:;
            endcase
            if(event_valid && !event_push && dropped_events!=32'hffffffff)
                dropped_events<=dropped_events+1'b1;
            if(push) begin
                memory[wr_ptr]<={sample_u,sample_d,sample_l,sample_r};
                wr_ptr<=wr_ptr+1'b1;
            end
            if(pop) begin
                active_sample<=memory[rd_ptr];
                rd_ptr<=rd_ptr+1'b1;
            end
            case({push,pop})
                2'b10: count<=count+1'b1;
                2'b01: count<=count-1'b1;
                default: ;
            endcase
            if(sample_valid && !push && dropped_samples!=32'hffffffff)
                dropped_samples<=dropped_samples+1'b1;
            case(state)
                IDLE: begin
                    char_index<=0;
                    if(boot_pending) begin
                        boot_pending<=0; kind<=BOOT; state<=SEND;
                    end else if(dropped_samples!=0 && !overflow_reported) begin
                        overflow_reported<=1; kind<=OVERFLOW; state<=SEND;
                    end else if(dropped_events!=0 && !event_overflow_reported)begin
                        event_overflow_reported<=1;kind<=EVENT_OVERFLOW;state<=SEND;
                    end else if(event_pop)begin kind<=GESTURE;state<=SEND;
                    end else if(pop) begin kind<=DATA; state<=SEND; end
                end
                SEND: if(!tx_busy) begin
                    tx_data<=character; tx_start<=1; state<=WAIT_TX;
                end
                WAIT_TX: if(tx_done) begin
                    if(last_character) state<=IDLE;
                    else begin char_index<=char_index+1'b1; state<=SEND; end
                end
                default: state<=IDLE;
            endcase
        end
    end
    uart_tx_8n1 #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst_n(rst_n), .start(tx_start), .data(tx_data),
        .busy(tx_busy), .done(tx_done), .tx(uart_tx)
    );
endmodule

module uart_tx_8n1 #(
    parameter integer CLK_HZ=50000000,
    parameter integer BAUD=115200
) (
    input wire clk, rst_n, start,
    input wire [7:0] data,
    output reg busy, done,
    output wire tx
);
    localparam integer ROUND_DIV=(CLK_HZ+BAUD/2)/BAUD;
    localparam integer BIT_CYCLES=ROUND_DIV<1 ? 1 : ROUND_DIV;
    reg [31:0] timer;
    reg [3:0] bit_index;
    reg [9:0] frame;
    assign tx=busy ? frame[0] : 1'b1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy<=0; done<=0; timer<=0; bit_index<=0; frame<=10'h3ff;
        end else begin
            done<=0;
            if(!busy) begin
                if(start) begin
                    frame<={1'b1,data,1'b0}; timer<=0; bit_index<=0; busy<=1;
                end
            end else if(timer==BIT_CYCLES-1) begin
                timer<=0;
                if(bit_index==9) begin busy<=0; done<=1; end
                else begin frame<={1'b1,frame[9:1]}; bit_index<=bit_index+1'b1; end
            end else timer<=timer+1'b1;
        end
    end
endmodule
