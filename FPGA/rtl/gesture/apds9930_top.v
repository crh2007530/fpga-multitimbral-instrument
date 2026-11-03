// APDS-9960 完整顶层：I2C 主机 -> 传感器驱动 -> 手势识别。
// 顶层连接关系：传感器驱动发起寄存器访问，I2C 主机执行总线事务；
// 完整的 U/D/L/R 样本交给识别器，单周期方向事件再驱动调试引脚和 WS2812B。
// 模块和工程名称沿用 apds9930，实际配置及读取的传感器为 APDS-9960。
module apds9930_top #(
    // 四路数据总和低于此值时忽略，避免弱噪声触发滑动。
    parameter integer PRESENCE_THRESHOLD = 20,
    // 选轴所需差值及两轴差值优势；接近时使用上升时间差选轴。
    parameter integer GESTURE_MIN_DELTA = 8,
    // 25%/50%/75% 三档上升时序的最少同向票数（1～3）。
    parameter integer GESTURE_FILTER_SAMPLES = 1,
    // 波形结束和识别后重新允许触发所需的连续释放样本数。
    parameter integer GESTURE_NEUTRAL_SAMPLES = 4,
    // 板载时钟频率，作为上电等待、超时、I2C 分频和灯带时序的计算依据。
    parameter integer CLK_HZ = 50000000,
    // 请求的数据位 SCL 频率，实际频率由整数分频得到；ACK 阶段额外延长。
    parameter integer I2C_HZ = 384000,
    // 左右调试输出的保持时长，默认 CLK_HZ/5，即约 200 ms。
    parameter integer LED_HOLD_CYCLES = CLK_HZ / 5,
    // 调试引脚有效极性：0 为高有效，非零为低有效；不影响灯带的颜色数据。
    parameter integer LED_ACTIVE_LOW = 0,
    parameter integer UART_BAUD = 115200
) (
    // 接口：clk 为系统时钟，rst_n 为低有效外部复位；sda 为带外部上拉的双向总线。
    // scl 由 I2C 主机输出，gesture_near/far 对应左/右调试信号，dout 接灯带 DIN。
    input  wire       clk,
    input  wire       rst_n,
    inout  wire       sda,
    output wire       scl,
    output wire       gesture_near,
    output wire       gesture_far,
    output wire       dout,
    output wire       uart_tx
);
    localparam [6:0] APDS9960_ADDR = 7'h39;
    // Asynchronous assertion, synchronous release of the external reset.
    // 外部复位拉低立即清零；释放后经过两个时钟上升沿才解除内部复位。
    reg [1:0] reset_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) reset_sync <= 2'b00;
        else reset_sync <= {reset_sync[0], 1'b1};
    wire core_rst_n = reset_sync[1];

    // 驱动与主机之间的事务接口：start 保持至 done；rw=0 写、rw=1 读。
    // reg_addr/wr_data 在发起前准备，rd_data 在 done 时有效，error 指示从机 NACK。
    wire       i2c_start;
    wire       i2c_rw;
    wire [7:0] i2c_reg_addr;
    wire [7:0] i2c_wr_data;
    wire [7:0] i2c_rd_data;
    wire       i2c_done;
    wire       i2c_error;
    // 接近数据另行送入趋势识别，保留四方向与左右调试引脚的原有作用。
    wire [7:0]  prox_data;
    wire       prox_valid;
    // 四路 8 位强度在 gesture_valid 有效时属于同一组 FIFO 数据。
    // sensor_ready 为配置完成标志，恢复期间使识别器同步丢弃未完成的手势。
    wire [7:0]  gesture_u;
    wire [7:0]  gesture_d;
    wire [7:0]  gesture_l;
    wire [7:0]  gesture_r;
    wire        gesture_valid;
    wire        sensor_ready;
    wire        swipe_left;
    wire        swipe_right;
    wire        swipe_up;
    wire        swipe_down;
    // 独立缓存原始样本，不阻塞传感器读取或手势识别。
    wire [31:0] uart_dropped_samples /* synthesis syn_keep=1 */;
    gesture_uart_logger #(.CLK_HZ(CLK_HZ), .BAUD(UART_BAUD)) u_logger (
        .clk(clk), .rst_n(core_rst_n), .sample_valid(gesture_valid),
        .sample_u(gesture_u), .sample_d(gesture_d),
        .sample_l(gesture_l), .sample_r(gesture_r), .uart_tx(uart_tx),
        .dropped_samples(uart_dropped_samples),
        .swipe_up(swipe_up),.swipe_down(swipe_down),
        .swipe_left(swipe_left),.swipe_right(swipe_right),.dropped_events()
    );
    // 独立的单周期靠近/远离事件，可在片上逻辑分析仪观察；不占用现有调试引脚。
    wire near_detected /* synthesis syn_keep=1 */;
    wire far_detected /* synthesis syn_keep=1 */;

    // 按系统时钟计算约 10 ms 上电/故障恢复等待，然后依次配置并轮询 FIFO。
    apds9930_driver #(.POWERUP_CYCLES(CLK_HZ / 100)) u_driver (
        .clk         (clk),
        .rst_n       (core_rst_n),
        .i2c_start   (i2c_start),
        .i2c_rw      (i2c_rw),
        .i2c_reg_addr(i2c_reg_addr),
        .i2c_wr_data (i2c_wr_data),
        .i2c_rd_data (i2c_rd_data),
        .i2c_done    (i2c_done),
        .i2c_error   (i2c_error),
        .prox_data   (prox_data),
        .prox_valid  (prox_valid),
        .gesture_u   (gesture_u),
        .gesture_d   (gesture_d),
        .gesture_l   (gesture_l),
        .gesture_r   (gesture_r),
        .gesture_valid(gesture_valid),
        .sensor_ready(sensor_ready)
    );

    // Ceiling division keeps SCL below the requested frequency.
    // Default low period is 1.32 us, meeting Fast-mode's 1.3 us minimum.
    // 向上取整计算半周期分频，确保数据位 SCL 不超过请求频率。
    // 默认分频为 66：低电平 1.32 us，数据位频率约 378.8 kHz。
    i2c_master #(
        .CLK_DIV((CLK_HZ + 2*I2C_HZ - 1) / (2*I2C_HZ))
    ) u_i2c (
        .clk      (clk),
        .rst_n    (core_rst_n),
        .start    (i2c_start),
        .rw       (i2c_rw),
        .dev_addr (APDS9960_ADDR),
        .reg_addr (i2c_reg_addr),
        .wr_data  (i2c_wr_data),
        .rd_data  (i2c_rd_data),
        .done     (i2c_done),
        .ack_error(i2c_error),
        .scl      (scl),
        .sda      (sda)
    );

    // 兼容原有两根 LED 引脚：gesture_near 输出左滑，gesture_far 输出右滑。
    // 最长收集 2 秒，超长波形丢弃；无数据 0.5 秒结束并评估当前波形。
    gesture_recognition #(
        .MIN_LEVEL      (PRESENCE_THRESHOLD),
        .MIN_DELTA      (GESTURE_MIN_DELTA),
        .FILTER_SAMPLES (GESTURE_FILTER_SAMPLES),
        .NEUTRAL_SAMPLES(GESTURE_NEUTRAL_SAMPLES),
        .ACTIVE_TIMEOUT_CYCLES(CLK_HZ * 2),
        .TIMEOUT_CYCLES (CLK_HZ / 2)
    ) u_presence (
        .clk         (clk),
        .rst_n       (core_rst_n),
        .gesture_u   (gesture_u),
        .gesture_d   (gesture_d),
        .gesture_l   (gesture_l),
        .gesture_r   (gesture_r),
        .gesture_valid(gesture_valid),
        .clear       (!sensor_ready),
        .prox_data   (prox_data),
        .prox_valid  (prox_valid),
        .near_detected(near_detected),
        .far_detected (far_detected),
        .swipe_left  (swipe_left),
        .swipe_right (swipe_right),
        .swipe_up    (swipe_up),
        .swipe_down  (swipe_down)
    );

    // 把单周期左右事件展宽为可观察的调试输出；新事件到达时重新装载保持计数。
    reg [31:0] left_hold, right_hold;
    always @(posedge clk or negedge core_rst_n) begin
        if (!core_rst_n) begin left_hold<=0; right_hold<=0; end
        else begin
            if (swipe_left) left_hold<=LED_HOLD_CYCLES;
            else if (left_hold!=0) left_hold<=left_hold-1'b1;
            if (swipe_right) right_hold<=LED_HOLD_CYCLES;
            else if (right_hold!=0) right_hold<=right_hold-1'b1;
        end
    end
    // 异或极性参数转换调试输出的有效电平，计数为零时输出无效电平。
    assign gesture_near = (left_hold!=0) ^ (LED_ACTIVE_LOW!=0);
    assign gesture_far  = (right_hold!=0) ^ (LED_ACTIVE_LOW!=0);
    // 灯带独立保持最近一次方向，并连续刷新整帧；传感器恢复不清除灯带方向。
    ws2812_gesture_driver #(.CLK_HZ(CLK_HZ)) u_strip (
        .clk(clk), .rst_n(core_rst_n),
        .swipe_up(swipe_up), .swipe_down(swipe_down),
        .swipe_left(swipe_left), .swipe_right(swipe_right), .dout(dout),
        .prox_data(prox_data)
    );
endmodule
