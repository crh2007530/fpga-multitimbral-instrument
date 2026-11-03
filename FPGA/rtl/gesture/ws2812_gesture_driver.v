// Adapted from C:/fpga_class/WS2812B/src/ws2812_top.v.
// Same 50 MHz pulse timings: 0=20/42, 1=40/22, reset=14000 clocks.
// 根据最近一次手势连续刷新灯带，复位后全灭；每颗灯发送 24 位 GRB，最高位先发。
// 方向与灯区：上=1~6红，下=7~12绿，左=13~18蓝，右=19~24黄；第27颗显示接近亮度。
module ws2812_gesture_driver #(
    // 时序参数均以系统时钟周期计数，默认时钟为 50 MHz（每周期 20 ns）。
    parameter integer CLK_HZ=50000000,
    // 每帧实际发送的灯珠数量；默认 30，前24颗为手势区域，第27颗为接近指示。
    parameter integer NUM_LEDS=30,
    // 0 码高电平长度，默认 20 个时钟即 400 ns。
    parameter integer T0H=CLK_HZ/2500000,
    // 1 码高电平长度，默认 40 个时钟即 800 ns。
    parameter integer T1H=CLK_HZ/1250000,
    // 一位总长度，整数除法默认得到 62 个时钟即 1.24 us；剩余时间保持低电平。
    parameter integer BIT_CYCLES=CLK_HZ/800000,
    // 帧间复位/锁存低电平的计数门限，默认 14000 个时钟即 280 us。
    parameter integer RESET_CYCLES=(CLK_HZ/100000)*28
) (
    input wire clk, rst_n,
    input wire swipe_up, swipe_down, swipe_left, swipe_right,
    output reg dout,
    input wire [7:0] prox_data // 0~255 直接映射第27颗白色亮度，不改变位发送时序。
);
    // RESET 输出帧间低电平，LOAD 装载方向与首颗颜色，SEND 逐位发送所有灯珠。
    localparam [1:0] RESET=0, LOAD=1, SEND=2;
    localparam [2:0] OFF=0, UP=1, DOWN=2, LEFT=3, RIGHT=4;
    reg [1:0] state;
    // requested_direction 保存最新事件；frame_direction 仅在 LOAD 更新，整帧保持固定。
    reg [2:0] requested_direction, frame_direction;
    // 每帧开始锁存一次接近值，帧中更新延至后续帧，避免一颗灯的三通道采用不同数值。
    reg [7:0] frame_proximity;
    // time_cnt 为位内/复位计时，led_cnt 为从零开始的灯索引，bit_cnt 为已发送位计数。
    reg [31:0] time_cnt, led_cnt;
    reg [4:0] bit_cnt;
    reg [23:0] shift_reg;
    // shift_reg[23] 是当前发送位，决定此位高电平采用 T1H 还是 T0H。
    wire [31:0] high_time=shift_reg[23]?T1H:T0H;
    // LEDs are numbered from 1 at DIN. Color order on the wire is G,R,B.
    // index=0 对应 DIN 端第 1 颗；返回值顺序为 G/R/B，而非通常显示颜色使用的 RGB。
    // 例如 00FF00 在线上传输的是红色，FF0000 是绿色；未命中的灯区全部返回零。
    function [23:0] color;
        input [31:0] index;
        input [2:0] direction;
        input [7:0] brightness;
        begin
            color=24'h000000;
            case(direction)
                UP: if(index<6) color=24'h00FF00;
                DOWN: if(index>=6 && index<12) color=24'hFF0000;
                LEFT: if(index>=12 && index<18) color=24'h0000FF;
                RIGHT: if(index>=18 && index<24) color=24'hFFFF00;
                default: color=24'h000000;
            endcase
            // 灯珠从 DIN 端按1编号，内部 index=26 即第27颗；GRB 相等输出白色。
            if(index==26) color={brightness,brightness,brightness};
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=RESET; requested_direction<=OFF; frame_direction<=OFF;
            frame_proximity<=0;
            time_cnt<=0; led_cnt<=0; bit_cnt<=0; shift_reg<=0; dout<=0;
        end else begin
            // Latest event persists until the next event or external reset.
            // 最近一次方向持续保存至下一个事件或外部复位；同周期多方向时优先级为上、下、左、右。
            if(swipe_up) requested_direction<=UP;
            else if(swipe_down) requested_direction<=DOWN;
            else if(swipe_left) requested_direction<=LEFT;
            else if(swipe_right) requested_direction<=RIGHT;
            case(state)
                // 保持 dout=0，达到复位时长后进入装载；每帧结束也重新走此状态。
                RESET: begin
                    dout<=0;
                    if(time_cnt>=RESET_CYCLES-1) begin time_cnt<=0; state<=LOAD; end
                    else time_cnt<=time_cnt+1'b1;
                end
                // 帧开始锁存方向并装载第 1 颗颜色；帧中事件只修改请求方向，留给下一帧使用。
                // 非阻塞赋值读取旧值，因此若事件恰在 LOAD 当拍到达，该事件要到后续帧才被装载。
                LOAD: begin//装载
                    dout<=0; time_cnt<=0; led_cnt<=0; bit_cnt<=0;
                    // Freeze the complete frame. A mid-frame event is applied
                    // to the next frame, so old and new zones never mix.
                    frame_direction<=requested_direction;
                    frame_proximity<=prox_data;
                    shift_reg<=color(0,requested_direction,prox_data); state<=SEND;
                end
                // 计时从零开始，小于高电平门限输出 1，其余输出 0；满位周期后推进到下一位。
                SEND: begin
                    dout<=(time_cnt<high_time);
                    if(time_cnt>=BIT_CYCLES-1) begin
                        time_cnt<=0;
                        // 一颗灯满 24 位后重新装载下一颗；最后一颗完成后转入帧间复位低电平。
                        if(bit_cnt==23) begin
                            bit_cnt<=0;
                            if(led_cnt==NUM_LEDS-1) begin led_cnt<=0; state<=RESET; end
                            else begin
                                led_cnt<=led_cnt+1'b1;
                                shift_reg<=color(led_cnt+1'b1,frame_direction,frame_proximity);
                            end
                        // 尚未发满一颗灯时左移一位，把下一位送到 bit23，最低位补零。
                        end else begin bit_cnt<=bit_cnt+1'b1; shift_reg<={shift_reg[22:0],1'b0}; end
                    end else time_cnt<=time_cnt+1'b1;
                end
                default: begin state<=RESET; time_cnt<=0; dout<=0; end
            endcase
        end
    end
endmodule
