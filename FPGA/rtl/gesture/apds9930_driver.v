// APDS-9960 driver. Historical module name retained for the Gowin project.
//gesture_u，gesture_d，gesture_l，gesture_r 读到的是 APDS9960 手势 FIFO 中，两个方向光电二极管的原始红外反射计数。
//prox_data 是 APDS9960 接近传感器（Proximity）的原始数据，8 位，来自寄存器 0x9C（PDATA）。

/*它表示的是：

芯片内部红外 LED 发射红外光后，被物体反射回来、被光电二极管接收到的反射光强度*/
module apds9930_driver #(
    parameter integer POWERUP_CYCLES = 500000
) (
    input wire clk, input wire rst_n,
    output reg i2c_start, output reg i2c_rw,
    output reg [7:0] i2c_reg_addr, output reg [7:0] i2c_wr_data,
    input wire [7:0] i2c_rd_data, input wire i2c_done, input wire i2c_error,
    output reg [7:0] prox_data, output reg prox_valid,
    output reg [7:0] gesture_u, output reg [7:0] gesture_d,
    output reg [7:0] gesture_l, output reg [7:0] gesture_r,
    output reg gesture_valid,
    output reg sensor_ready
);
    localparam [1:0] DELAY=0, REQUEST=1, WAIT_DONE=2, RELEASE=3;
    localparam [4:0] STATUS=13, LEVEL=14, U=15, D=16, L=17, R=18,PROX=19,PROX_STATUS=20;
    reg [1:0] state;
    reg [4:0] operation;
    reg [31:0] wait_cnt;
    reg [7:0] data_u, data_d, data_l;
    reg prox_saturated;

    // 手势每组结束后退出，再由 GPENTH=0 自动进入下一轮，给接近引擎更新 PDATA 的机会。
    function [15:0] configuration;
        input [4:0] index;
        begin
            case(index)
                0: configuration=16'h8000; // disable before configuration
                1: configuration=16'h83FF; // WTIME
                2: configuration=16'h8E89; // PPULSE
                3: configuration=16'h8F00; // CONTROL
                4: configuration=16'hA000; // GPENTH
                5: configuration=16'hA1FF; // GEXTH：按组退出，交替运行接近与手势引擎。
                6: configuration=16'hA200; // GCONF1: one dataset threshold
                7: configuration=16'hA341; // GCONF2: 4x, 100 mA, 2.8 ms wait
                8: configuration=16'hA687; // GPULSE: 8 pulses, 16 us
                9: configuration=16'hAA00; // GCONF3: both pairs
               10: configuration=16'hAB04; // exit gesture and explicitly clear FIFO/GFOV
               11: configuration=16'h8045; // PON + PEN + GEN
               12: configuration=16'hAB01; // 启动首轮手势，后续由 GPENTH 自动进入。
                default: configuration=16'h8000;
            endcase
        end
    endfunction
    wire [15:0] config_word = configuration(operation);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=DELAY; operation<=0; wait_cnt<=0;
            i2c_start<=0; i2c_rw<=0; i2c_reg_addr<=0; i2c_wr_data<=0;
            prox_data<=0; prox_valid<=0; prox_saturated<=0;
            gesture_u<=0; gesture_d<=0; gesture_l<=0; gesture_r<=0;
            data_u<=0; data_d<=0; data_l<=0; gesture_valid<=0; sensor_ready<=0;
        end else begin
            prox_valid<=0; gesture_valid<=0;
            case(state)
                DELAY: begin
                    sensor_ready<=0;
                    i2c_start<=0;
                    if(wait_cnt >= POWERUP_CYCLES-1) begin
                        wait_cnt<=0; operation<=0; state<=REQUEST;
                    end else wait_cnt<=wait_cnt+1'b1;
                end
                REQUEST: if(!i2c_done) begin
                    i2c_rw <= (operation >= STATUS);
                    i2c_wr_data <= config_word[7:0];
                    case(operation)
                        STATUS: i2c_reg_addr<=8'hAF;
                        LEVEL:  i2c_reg_addr<=8'hAE;
                        U: i2c_reg_addr<=8'hFC;
                        D: i2c_reg_addr<=8'hFD;
                        L: i2c_reg_addr<=8'hFE;
                        R: i2c_reg_addr<=8'hFF;
                        PROX: i2c_reg_addr<=8'h9C;
                        PROX_STATUS: i2c_reg_addr<=8'h93;
                        default: i2c_reg_addr<=config_word[15:8];
                    endcase
                    i2c_start<=1; state<=WAIT_DONE;
                end
                WAIT_DONE: if(i2c_done) begin
                    i2c_start<=0; state<=RELEASE;
                    if(i2c_error) begin
                        sensor_ready<=0;
                        wait_cnt<=0; operation<=0; state<=DELAY;
                    end else if(operation < STATUS) begin
                        operation<=operation+1'b1;
                        if(operation==STATUS-1) sensor_ready<=1;
                    end
                    else case(operation)
                        STATUS: if(i2c_rd_data[1]) begin
                            sensor_ready<=0;
                            wait_cnt<=0; operation<=0; state<=DELAY;
                        end else operation<=PROX_STATUS;
                        // 只有 PVALID=1 才读新结果；读取 PDATA 会由芯片清除 PVALID。
                        PROX_STATUS: begin
                            prox_saturated<=i2c_rd_data[6];
                            operation<=i2c_rd_data[1]?PROX:LEVEL;
                        end
                        // GVALID can remain high with an empty FIFO; use GFLVL.
                        LEVEL: operation<=(i2c_rd_data!=0)?U:STATUS;
                        U: begin data_u<=i2c_rd_data; operation<=D; end
                        D: begin data_d<=i2c_rd_data; operation<=L; end
                        L: begin data_l<=i2c_rd_data; operation<=R; end
                        R: begin
                            gesture_u<=data_u; gesture_d<=data_d;
                            gesture_l<=data_l; gesture_r<=i2c_rd_data;
                            gesture_valid<=1; operation<=STATUS;
                        end
                        PROX: begin
                            prox_data <= i2c_rd_data;                 // APDS9960 的 8 位 PDATA
                            prox_valid <= !prox_saturated;            // 饱和样本不用于趋势判断。
                            operation <= LEVEL;                       // 接着轮询手势 FIFO。
                        end
                        default: begin operation<=0; state<=DELAY; end
                    endcase
                end
                // Acknowledge start=0 before accepting the next transaction.
                RELEASE: if(!i2c_done) state<=REQUEST;
                default: begin state<=DELAY; i2c_start<=0; wait_cnt<=0; sensor_ready<=0; end
            endcase
        end
    end
endmodule
