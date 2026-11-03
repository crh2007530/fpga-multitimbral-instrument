// APDS9960 rising-order swipe recognition plus independent proximity trends.
module gesture_recognition #(
    parameter integer MIN_LEVEL=20,
    parameter integer MIN_DELTA=8,
    parameter integer MIN_PEAK=40,
    parameter integer FILTER_SAMPLES=1,
    parameter integer NEUTRAL_SAMPLES=4,
    parameter integer TIMEOUT_CYCLES=25000000,
    parameter integer ACTIVE_TIMEOUT_CYCLES=100000000,
    parameter integer PROX_MIN_LEVEL=30,
    parameter integer PROX_TREND_DELTA=3,
    parameter integer PROX_TREND_SAMPLES=3
)(
    input wire clk,rst_n,
    input wire [7:0] gesture_u,gesture_d,gesture_l,gesture_r,
    input wire gesture_valid,
    output wire swipe_left,swipe_right,swipe_up,swipe_down,
    input wire clear,
    input wire [7:0] prox_data,
    input wire prox_valid,
    output reg near_detected /* synthesis syn_preserve=1 */,
    output reg far_detected /* synthesis syn_preserve=1 */
);
    // 接近趋势单独处理，不能与 gesture_valid 构成互斥分支，否则同拍手势样本会丢失。
    reg [7:0] prox_previous;
    reg prox_have_previous;
    reg [1:0] prox_direction, prox_reported;
    reg [31:0] prox_count, prox_idle_count;
    wire prox_rising=(prox_data>prox_previous &&
        ({1'b0,prox_data}-{1'b0,prox_previous})>=PROX_TREND_DELTA &&
        prox_data>=PROX_MIN_LEVEL);
    wire prox_falling=(prox_data<prox_previous &&
        ({1'b0,prox_previous}-{1'b0,prox_data})>=PROX_TREND_DELTA &&
        prox_previous>=PROX_MIN_LEVEL);
    wire [1:0] prox_motion=prox_rising?2'd1:prox_falling?2'd2:2'd0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            prox_previous<=0; prox_have_previous<=0;
            prox_direction<=0; prox_reported<=0; prox_count<=0; prox_idle_count<=0;
            near_detected<=0; far_detected<=0;
        end else if(clear) begin
            prox_previous<=0; prox_have_previous<=0;
            prox_direction<=0; prox_reported<=0; prox_count<=0; prox_idle_count<=0;
            near_detected<=0; far_detected<=0;
        end else begin
            near_detected<=0; far_detected<=0;
            if(prox_valid) begin
                prox_previous<=prox_data; prox_have_previous<=1; prox_idle_count<=0;
                if(!prox_have_previous || prox_motion==0) begin
                    prox_direction<=0; prox_count<=0;
                    if(prox_data<PROX_MIN_LEVEL) prox_reported<=0;
                end else begin
                    if(prox_direction!=prox_motion) begin
                        prox_direction<=prox_motion; prox_count<=1;
                    end else if(prox_count<PROX_TREND_SAMPLES)
                        prox_count<=prox_count+1'b1;
                    if(prox_reported!=prox_motion &&
                       (PROX_TREND_SAMPLES<=1 ||
                        (prox_direction==prox_motion && prox_count>=PROX_TREND_SAMPLES-1))) begin
                        near_detected<=(prox_motion==1);
                        far_detected<=(prox_motion==2);
                        prox_reported<=prox_motion;
                    end
                end
            end else if(prox_idle_count<TIMEOUT_CYCLES-1)
                prox_idle_count<=prox_idle_count+1'b1;
            else begin
                prox_have_previous<=0; prox_direction<=0; prox_reported<=0; prox_count<=0;
            end
        end
    end
    rising_order_recognizer #(
        .MIN_LEVEL(MIN_LEVEL),.MIN_DELTA(MIN_DELTA),.MIN_PEAK(MIN_PEAK),
        .FILTER_SAMPLES(FILTER_SAMPLES),.NEUTRAL_SAMPLES(NEUTRAL_SAMPLES),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES),.ACTIVE_TIMEOUT_CYCLES(ACTIVE_TIMEOUT_CYCLES)
    ) u_rising (
        .clk(clk),.rst_n(rst_n),.clear(clear),.valid(gesture_valid),
        .u(gesture_u),.d(gesture_d),.l(gesture_l),.r(gesture_r),
        .swipe_up(swipe_up),.swipe_down(swipe_down),
        .swipe_left(swipe_left),.swipe_right(swipe_right)
    );
endmodule
