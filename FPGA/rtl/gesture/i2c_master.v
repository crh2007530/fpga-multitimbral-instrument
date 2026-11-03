// 单主机、单寄存器字节访问的 I2C 控制器。
// 写事务：START -> 地址W -> 寄存器地址 -> 数据 -> STOP，各发送字节后检查从机 ACK。
// 读事务：START -> 地址W -> 寄存器地址 -> 重复START -> 地址R -> 数据 -> 主机NACK -> STOP。
// SDA 使用开漏输出与外部上拉，SCL 为本模块直接输出；状态机不读取 SCL 等待时钟拉伸。
module i2c_master #(
    // 50 MHz / 250 = 200 kHz tick；每 bit 2 个 tick → SCL = 100 kHz
    parameter integer CLK_DIV = 250
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,        // 保持高直到 done 有效
    input  wire       rw,           // 0: 写, 1: 读
    input  wire [6:0] dev_addr,     // 7 位从机地址
    input  wire [7:0] reg_addr,     // 寄存器地址
    input  wire [7:0] wr_data,      // 写数据
    output reg  [7:0] rd_data,      // 读数据
    output reg        done,         // 事务完成（保持到 start 拉低）
    output reg        ack_error,    // 从机无 ACK
    output reg        scl,
    inout  wire       sda
);
    // ---- 状态编码 ----
    // 状态机按 i2c_tick 推进；发送数据位通常每两次 tick 完成一位。
    // ACK 和接收数据分为拉高、稳定后采样阶段，以留出 SDA 两级同步延迟。
    localparam [4:0] ST_IDLE        = 5'd0;
    localparam [4:0] ST_START1      = 5'd1;
    localparam [4:0] ST_START2      = 5'd2;
    localparam [4:0] ST_TX_LOW      = 5'd3;
    localparam [4:0] ST_TX_HIGH     = 5'd4;
    localparam [4:0] ST_ACK_LOW     = 5'd5;
    localparam [4:0] ST_ACK_HIGH    = 5'd6;
    localparam [4:0] ST_RESTART1    = 5'd7;
    localparam [4:0] ST_RESTART2    = 5'd8;
    localparam [4:0] ST_RESTART3    = 5'd9;
    localparam [4:0] ST_RX_LOW      = 5'd10;
    localparam [4:0] ST_RX_HIGH     = 5'd11;
    localparam [4:0] ST_RX_ACK_LOW  = 5'd12;
    localparam [4:0] ST_RX_ACK_HIGH = 5'd13;
    localparam [4:0] ST_STOP1       = 5'd14;
    localparam [4:0] ST_STOP2       = 5'd15;
    localparam [4:0] ST_STOP3       = 5'd16;
    localparam [4:0] ST_ACK_SAMPLE  = 5'd17;
    localparam [4:0] ST_RX_SAMPLE   = 5'd18;

    // ---- 寄存器 ----
    reg [4:0]  state;
    reg [31:0] clk_cnt;
    reg [3:0]  bit_cnt;
    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;
    reg [2:0]  phase;        // 0:地址W 1:寄存器 2:写数据 3:地址R 4:读数据
    reg        rw_lat;
    reg [6:0]  dev_lat;
    reg [7:0]  reg_lat;
    reg [7:0]  wdata_lat;
    // 每次 start 高电平只接受一次请求；start 撤销后解锁，避免完成后重复启动。
    reg        busy_lock;    // start 边沿锁存
    reg        sda_low;      // 1: 主动拉低；0: 释放（高阻）

    // Allow the two-stage synchronizer to settle even for small test dividers.
    // 分频最小值钳位为 4，保证高速仿真配置下也有足够时间同步 SDA。
    localparam integer DIV_CYCLES = (CLK_DIV < 4) ? 4 : CLK_DIV;
    wire i2c_tick = (clk_cnt == DIV_CYCLES - 1);
    // SDA 属于异步输入，用两级寄存器同步；ACK 和读位均使用第二级 sda_in。
    (* ASYNC_REG = "TRUE" *) reg [1:0] sda_sync;
    wire sda_in = sda_sync[1];
    always @(posedge clk or negedge rst_n)
        if (!rst_n) sda_sync <= 2'b11;
        else sda_sync <= {sda_sync[0], sda};

    // 开漏：只拉低，不主动驱动高
    assign sda = sda_low ? 1'b0 : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            clk_cnt    <= 16'd0;
            bit_cnt    <= 4'd0;
            tx_shift   <= 8'd0;
            rx_shift   <= 8'd0;
            phase      <= 3'd0;
            rw_lat     <= 1'b0;
            dev_lat    <= 7'd0;
            reg_lat    <= 8'd0;
            wdata_lat  <= 8'd0;
            busy_lock  <= 1'b0;
            sda_low    <= 1'b0;
            rd_data    <= 8'd0;
            done       <= 1'b0;
            ack_error  <= 1'b0;
            scl        <= 1'b1;
        end else begin

            // start 拉低时清 done 和 busy_lock
            if (!start) begin
                done      <= 1'b0;
                busy_lock <= 1'b0;
            end

            // tick 计数器
            if (i2c_tick) clk_cnt <= 16'd0;
            else          clk_cnt <= clk_cnt + 1'b1;

            if (i2c_tick) begin
                case (state)

                // 空闲：SCL=1，SDA 释放
                ST_IDLE: begin
                    scl     <= 1'b1;
                    sda_low <= 1'b0;
                    // 仅在空闲时接受请求并锁存地址/方向/数据，事务过程中不依赖调用方输入变化。
                    if (start && !busy_lock) begin
                        busy_lock <= 1'b1;
                        rw_lat    <= rw;
                        dev_lat   <= dev_addr;
                        reg_lat   <= reg_addr;
                        wdata_lat <= wr_data;
                        ack_error <= 1'b0;
                        phase     <= 3'd0;
                        tx_shift  <= {dev_addr, 1'b0}; // 先写
                        bit_cnt   <= 4'd7;
                        state     <= ST_START1;
                    end
                end

                // START: SCL 高时，SDA 由高变低
                ST_START1: begin
                    scl     <= 1'b1;
                    sda_low <= 1'b1;     // SDA 下降沿
                    state   <= ST_START2;
                end

                ST_START2: begin
                    scl   <= 1'b0;       // 然后 SCL 拉低
                    state <= ST_TX_LOW;
                end

                // 发送 1 bit：SCL 低时准备好 SDA
                ST_TX_LOW: begin
                    scl     <= 1'b0;
                    sda_low <= ~tx_shift[bit_cnt];
                    state   <= ST_TX_HIGH;
                end

                // 发送按 bit_cnt 从 7 到 0，即最高有效位先发；最后一位之后进入从机应答阶段。
                ST_TX_HIGH: begin
                    scl <= 1'b1;         // SCL 高时从机采样
                    if (bit_cnt == 4'd0)
                        state <= ST_ACK_LOW;
                    else begin
                        bit_cnt <= bit_cnt - 1'b1;
                        state   <= ST_TX_LOW;
                    end
                end

                // 主机释放 SDA，让从机发 ACK
                ST_ACK_LOW: begin
                    scl     <= 1'b0;
                    sda_low <= 1'b0;     // 释放
                    state   <= ST_ACK_HIGH;
                end

                ST_ACK_HIGH: begin
                    scl <= 1'b1;
                    state <= ST_ACK_SAMPLE;
                end

                // Sample at the end of the stable high period, before lowering SCL.
                // SCL 已保持高电平一个 tick 后检查同步 SDA；高表示 NACK，置错误并转 STOP。
                // 收到 ACK 时按 phase 选择寄存器、写数据、重复 START 或接收数据。
                ST_ACK_SAMPLE: begin
                    // The following LOW/STOP state lowers SCL together with
                    // its SDA setup, preserving the ACK-to-STOP sequence.
                    if (sda_in) begin
                        // 从机没 ACK：报错并 STOP
                        ack_error <= 1'b1;
                        state     <= ST_STOP1;
                    end else begin
                        case (phase)
                        3'd0: begin  // 从机地址 W 的 ACK
                            // 寄存器地址直接采用调用方提供的完整 8 位值，不附加命令位。
                            tx_shift <= reg_lat; // Actual address supplied by caller.
                            bit_cnt  <= 4'd7;
                            phase    <= 3'd1;
                            state    <= ST_TX_LOW;
                        end
                        3'd1: begin  // 寄存器地址的 ACK
                            if (rw_lat) begin
                                // 读：先 repeated START
                                state <= ST_RESTART1;
                            end else begin
                                tx_shift <= wdata_lat;
                                bit_cnt  <= 4'd7;
                                phase    <= 3'd2;
                                state    <= ST_TX_LOW;
                            end
                        end
                        3'd2: begin  // 写数据 ACK
                            state <= ST_STOP1;
                        end
                        3'd3: begin  // 读地址 ACK
                            bit_cnt  <= 4'd7;
                            rx_shift <= 8'd0;
                            phase    <= 3'd4;
                            state    <= ST_RX_LOW;
                        end
                        default: state <= ST_STOP1;
                        endcase
                    end
                end

                // Repeated START：SCL 高时 SDA 从高变低
                // 先在 SCL 低时释放 SDA，再拉高 SCL，最后在高电平期间拉低 SDA 形成重复 START。
                ST_RESTART1: begin
                    scl      <= 1'b0;
                    sda_low  <= 1'b0;                 // 释放 SDA
                    tx_shift <= {dev_lat, 1'b1};      // 读地址
                    bit_cnt  <= 4'd7;
                    phase    <= 3'd3;
                    state    <= ST_RESTART2;
                end

                ST_RESTART2: begin
                    scl   <= 1'b1;                    // SCL 高，SDA 高
                    state <= ST_RESTART3;
                end

                ST_RESTART3: begin
                    sda_low <= 1'b1;                  // SCL 高时 SDA 下降 = repeated START
                    state   <= ST_START2;
                end

                // 接收 1 bit：SCL 低时释放 SDA，SCL 高时采样
                ST_RX_LOW: begin
                    scl     <= 1'b0;
                    sda_low <= 1'b0;                  // 释放，交给从机驱动
                    state   <= ST_RX_HIGH;
                end

                ST_RX_HIGH: begin
                    scl <= 1'b1;
                    state <= ST_RX_SAMPLE;
                end

                // 使用高电平保持阶段结束后的同步数据，采样同时拉低 SCL。
                // 非末位直接进入下一次高电平阶段；主机始终释放 SDA 供从机驱动。
                ST_RX_SAMPLE: begin
                    scl <= 1'b0;
                    rx_shift[bit_cnt] <= sda_in;
                    if (bit_cnt == 4'd0)
                        state <= ST_RX_ACK_LOW;
                    else begin
                        bit_cnt <= bit_cnt - 1'b1;
                        state   <= ST_RX_HIGH;
                    end
                end

                // 主机发 NACK：释放 SDA（高）
                // 只读一个字节，主机释放 SDA 发 NACK，通知从机结束本次读操作。
                ST_RX_ACK_LOW: begin
                    scl     <= 1'b0;
                    sda_low <= 1'b0;                  // 释放 = 高 = NACK
                    state   <= ST_RX_ACK_HIGH;
                end

                ST_RX_ACK_HIGH: begin
                    scl   <= 1'b1;
                    state <= ST_STOP1;
                end

                // STOP：SCL 高时，SDA 由低变高
                ST_STOP1: begin
                    scl     <= 1'b0;
                    sda_low <= 1'b1;                  // SCL 低时先拉低 SDA
                    state   <= ST_STOP2;
                end

                ST_STOP2: begin
                    scl     <= 1'b1;                  // SCL 拉高，SDA 保持低
                    sda_low <= 1'b1;
                    state   <= ST_STOP3;
                end

                // 释放 SDA 形成 STOP，同时发布接收寄存器与保持型 done；调用方随后撤销 start。
                // 写事务也更新 rd_data，但调用方仅应在成功的读事务中使用该值。
                ST_STOP3: begin
                    sda_low <= 1'b0;                  // SCL 高时 SDA 上升 = STOP
                    rd_data <= rx_shift;
                    done    <= 1'b1;                  // 保持到 start 拉低
                    state   <= ST_IDLE;
                end

                default: state <= ST_IDLE;
                endcase
            end
        end
    end
endmodule
