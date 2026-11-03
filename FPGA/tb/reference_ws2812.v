module reference_ws2812_joint_driver #(parameter integer TRAINER=0) (
    input wire guide_active,guide_running,guide_done,guide_wait,guide_beat,
    input wire [7:0] guide_target,guide_next,guide_pressed,guide_misses,guide_wrong,
    input wire clk,       // 50MHz系统时钟
    input wire rst_n,     // 低电平复位
    // ================= 新增：8个区的压力输入 =================
    input wire [7:0] p1,  // 区1压力
    input wire [7:0] p2,  // 区2压力
    input wire [7:0] p3,  // 区3压力
    input wire [7:0] p4,  // 区4压力
    input wire [7:0] p5,  // 区5压力
    input wire [7:0] p6,  // 区6压力
    input wire [7:0] p7,  // 区7压力
    input wire [7:0] p8,  // 区8压力
    input wire [5:0] events,input wire [7:0] prox,
    output reg dout       // 接WS2812B的数据线
);

    // ================= 参数定义 =================
    localparam NUM_LEDS = 30;         // 灯珠数量
    localparam T0H = 20, T0L = 42;    // 0码: 高20个clk, 低42个clk (共1.24us)
    localparam T1H = 40, T1L = 22;    // 1码: 高40个clk, 低22个clk (共1.24us)
    localparam TRST = 14000;          // 复位: 280us的低电平

    // ================= 内部变量 =================
    reg [1:0] state;
    localparam IDLE = 2'b00, SEND = 2'b01, LOAD = 2'b10, RESET = 2'b11;

    reg [5:0]  bit_cnt;      // 位计数器 (0~23)
    reg [13:0] time_cnt;     // 时间计数器
    reg [4:0]  led_cnt;      // 灯珠计数器 (0~29)
    reg [23:0] shift_reg;    // 当前正在发送的24位数据

    // 30个灯的数据缓存（每个24位，按GRB顺序）
    reg [23:0] led_data [0:NUM_LEDS-1];

    // ================= 压力值到亮度的映射（带死区） =================
    // 压力0~10时亮度为0；否则压力值直接作为亮度（0~255）。
    wire [7:0] bri1 = (p1 > 8'd10) ? p1 : 8'd0;
    wire [7:0] bri2 = (p2 > 8'd10) ? p2 : 8'd0;
    wire [7:0] bri3 = (p3 > 8'd10) ? p3 : 8'd0;
    wire [7:0] bri4 = (p4 > 8'd10) ? p4 : 8'd0;
    wire [7:0] bri5 = (p5 > 8'd10) ? p5 : 8'd0;
    wire [7:0] bri6 = (p6 > 8'd10) ? p6 : 8'd0;
    wire [7:0] bri7 = (p7 > 8'd10) ? p7 : 8'd0;
    wire [7:0] bri8 = (p8 > 8'd10) ? p8 : 8'd0;

    // 组合逻辑：根据当前最高位，决定高低电平时间
    wire [5:0] high_time = shift_reg[23] ? T1H : T0H;
    wire [6:0] total_time = 7'd62; // Both symbols have the same 62-clock period.

    reg [3:0] direction;reg [1:0] distance;
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n)begin direction<=0;distance<=0;end
      else begin
        if(|events[3:0])direction<=events[3:0];
        if(events[4])distance<=1;else if(events[5])distance<=2;
      end
    end
    integer i, j;

    // ================= 主状态机 =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= RESET; // Start with a full latch interval after power-up.
            dout     <= 0;
            bit_cnt  <= 0;
            time_cnt <= 0;
            led_cnt  <= 0;
            shift_reg<= 0;
            // 复位时清空所有灯
            for (i = 0; i < NUM_LEDS; i = i + 1) begin
                led_data[i] <= 24'h000000;
            end
        end else begin
            case (state)
                IDLE: begin
                    // ================= 在这里根据压力值刷新灯珠数据 =================
                    // 注意 WS2812B 的颜色顺序是 GRB (G高位在前，R中位，B低位)
                    
                    // 区1 (灯 0,1,2)：红色 -> 24'h00FF00 (G=00, R=FF, B=00)
                    led_data[0] <= {8'd0, bri1, 8'd0};
                    led_data[1] <= {8'd0, bri1, 8'd0};
                    led_data[2] <= {8'd0, bri1, 8'd0};

                    // 区2 (灯 3,4,5)：绿色 -> 24'hFF0000
                    led_data[3] <= {bri2, 8'd0, 8'd0};
                    led_data[4] <= {bri2, 8'd0, 8'd0};
                    led_data[5] <= {bri2, 8'd0, 8'd0};

                    // 区3 (灯 6,7,8)：蓝色 -> 24'h0000FF
                    led_data[6] <= {8'd0, 8'd0, bri3};
                    led_data[7] <= {8'd0, 8'd0, bri3};
                    led_data[8] <= {8'd0, 8'd0, bri3};

                    // 区4 (灯 9,10,11)：黄色 -> GRB 24'hFFFF00
                    led_data[9]  <= {bri4, bri4, 8'd0};
                    led_data[10] <= {bri4, bri4, 8'd0};
                    led_data[11] <= {bri4, bri4, 8'd0};

                    // 区5 (灯 12,13,14)：青色 -> 24'hFF00FF
                    led_data[12] <= {bri5, 8'd0, bri5};
                    led_data[13] <= {bri5, 8'd0, bri5};
                    led_data[14] <= {bri5, 8'd0, bri5};

                    // 区6 (灯 15,16,17)：品红 -> 24'h00FFFF
                    led_data[15] <= {8'd0, bri6, bri6};
                    led_data[16] <= {8'd0, bri6, bri6};
                    led_data[17] <= {8'd0, bri6, bri6};

                    // 区7 (灯 18,19,20)：白色 -> 24'hFFFFFF
                    led_data[18] <= {bri7, bri7, bri7};
                    led_data[19] <= {bri7, bri7, bri7};
                    led_data[20] <= {bri7, bri7, bri7};

                    // 区8 (灯 21,22,23)：白色 -> 24'hFFFFFF (如果你想换颜色，改这里)
                    led_data[21] <= {bri8, bri8, bri8};
                    led_data[22] <= {bri8, bri8, bri8};
                    led_data[23] <= {bri8, bri8, bri8};

                    // 预留灯 24~29 强制熄灭（黑）
                    led_data[24] <= direction[0] ? 24'h004000 : 0;
                    led_data[25] <= direction[1] ? 24'h400000 : 0;
                    led_data[26] <= {prox,prox,prox};
                    led_data[27] <= direction[2] ? 24'h000040 : 0;
                    led_data[28] <= direction[3] ? 24'h404000 : 0;
                    led_data[29] <= distance==1 ? 24'h400000 : distance==2 ? 24'h004040 : 0;

                    // Offline lesson overlays the same physical strip, captured atomically.
                    if(TRAINER && guide_active)begin
                      for(j=0;j<24;j=j+1)begin
                        if(guide_pressed[j/3] && !guide_target[j/3])led_data[j]<=24'h004000;
                        else if(guide_pressed[j/3] && guide_target[j/3])led_data[j]<=24'h400000;
                        else if(guide_target[j/3])led_data[j]<=24'h000040;
                        else if(guide_next[j/3] && j%3==0)led_data[j]<=24'h080808;
                        else led_data[j]<=0;
                      end
                      led_data[24]<=guide_beat ? 24'h404040 : 0;
                      led_data[25]<=!guide_running ? 24'h204000 : 0;
                      led_data[26]<=guide_wait ? 24'h200020 : 24'h000020;
                      led_data[27]<=guide_done ? 24'h400000 : 0;
                      led_data[28]<=guide_misses!=0 ? 24'h004000 : 0;
                      led_data[29]<=guide_wrong!=0 ? 24'h004000 : 0;
                    end
                    // 启动发送流程
                    dout      <= 0;
                    time_cnt  <= 0;
                    bit_cnt   <= 0;
                    led_cnt   <= 0;
                    state     <= LOAD;
                end

                LOAD: begin
                    // The frame buffer was captured in IDLE. Load it one clock later
                    // so LED 0 uses the same pressure snapshot as LEDs 1..29.
                    shift_reg <= led_data[0];
                    state     <= SEND;
                end

                SEND: begin
                    time_cnt <= time_cnt + 14'd1;
                    
                    // 根据时间计数器输出高低电平
                    if (time_cnt < high_time) dout <= 1;
                    else                      dout <= 0;

                    // 一个位发送完成
                    if (time_cnt == total_time - 1) begin
                        time_cnt <= 0;
                        
                        // 判断24位是否发完
                        if (bit_cnt == 23) begin
                            bit_cnt <= 0;
                            // 判断30个灯是否发完
                            if (led_cnt == NUM_LEDS - 1) begin
                                led_cnt <= 0;
                                state   <= RESET; // 30个灯全发完，进入复位
                            end else begin
                                led_cnt   <= led_cnt + 5'd1;
                                shift_reg <= led_data[led_cnt + 5'd1]; // 加载下一颗灯的数据
                            end
                        end else begin
                            bit_cnt   <= bit_cnt + 6'd1;
                            shift_reg <= {shift_reg[22:0], 1'b0}; // 左移，最高位先发
                        end
                    end
                end

                RESET: begin
                    dout     <= 0;
                    time_cnt <= time_cnt + 14'd1;
                    if (time_cnt == TRST - 1) begin
                        time_cnt <= 0;
                        state    <= IDLE; // 重新开始发送
                    end
                end

                default: begin
                    state     <= IDLE;
                    dout      <= 0;
                    bit_cnt   <= 0;
                    time_cnt  <= 0;
                    led_cnt   <= 0;
                    shift_reg <= 0;
                end
            endcase
        end
    end

endmodule

