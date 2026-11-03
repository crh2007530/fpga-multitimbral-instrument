`timescale 1ns/1ps
// 整机仿真：模拟开漏 I2C 从机，检查配置顺序、首次 NACK 重试、重复 START 和 STOP。
// 输入 88 组 FIFO 样本覆盖四方向，最后保持 GVALID=1/GFLVL=0 验证空 FIFO 不发布样本。
module tb_joint_apds;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    tri1 sda;
    wire scl, left_led, right_led;
    wire strip_data, uart_tx;
    wire [5:0] diag_events;
    wire diag_ready,diag_valid;
    wire [7:0] diag_prox;
    wire [31:0] diag_errors,diag_recoveries;
    always @(negedge clk) if(rst_n) begin
        if(diag_events!=={dut.far_detected,dut.near_detected,dut.swipe_right,dut.swipe_left,dut.swipe_down,dut.swipe_up}) $fatal(1,"diagnostic event mapping");
    end
    reg slave_low=0;
    assign sda=slave_low?1'b0:1'bz;
    apds9960_joint #(.CLK_HZ(100000), .I2C_HZ(10000),
        .LED_HOLD_CYCLES(100)) dut(.clk(clk),.rst_n(rst_n),.sda(sda),.scl(scl),.gesture_near(left_led),.gesture_far(right_led),.dout(strip_data),.uart_tx(uart_tx),.diagnostic_events(diag_events),.diagnostic_ready(diag_ready),.diagnostic_prox_valid(diag_valid),.diagnostic_prox(diag_prox),.diagnostic_errors(diag_errors),.diagnostic_recoveries(diag_recoveries));
    integer init_index=0, sample_index=0, reads=0;
    integer left_events=0, right_events=0, valid_count=0;
    integer up_events=0, down_events=0;
    integer uart_events=0;
    integer prox_sent=-1, prox_samples=0, near_events=0, far_events=0;
    reg nack_once=1;
    reg [7:0] address, pointer, value;
    reg [15:0] expected [0:12];

    // 从机在 SCL 上升沿读取主机发送的 8 位，按最高位到最低位组装字节。
    task receive_byte(output reg [7:0] b);
        integer i;
        begin
            for(i=7;i>=0;i=i-1) begin @(posedge scl); #1; b[i]=sda; end
        end
    endtask
    // 从机在 SCL 低电平改变 SDA，nack=0 拉低应答，nack=1 释放表示拒绝。
    task acknowledge(input bit nack);
        begin
            @(negedge scl); slave_low=!nack;
            @(posedge scl);
            @(negedge scl); slave_low=0;
        end
    endtask
    // 模拟从机逐位输出读数据，末尾释放 SDA 并核对主机发送 NACK。
    task transmit_byte(input reg [7:0] b);
        integer i;
        begin
            for(i=7;i>=0;i=i-1) begin
                slave_low=!b[i]; @(posedge scl); @(negedge scl);
            end
            slave_low=0;
            @(posedge scl); #1;
            if(sda!==1) $fatal(1,"Single-byte read must end with master NACK");
            @(negedge scl);
        end
    endtask
    // 只把 SCL 高电平期间 SDA 的下降沿识别为 START，过滤普通数据跳变。
    task await_start;
        begin : find_start
            forever begin
                @(negedge sda);
                if(scl===1) disable find_start;
            end
        end
    endtask
    // 按当前寄存器地址及测试阶段返回模拟传感器数据；读取 R 后推进样本索引。
    function [7:0] sensor_value(input reg [7:0] regnum);
        integer motion,position;
        begin
            motion=sample_index/22;position=sample_index%22;
            case(regnum)
                // 每个索引最多生成一次 PVALID，读 PDATA 后清除，模拟真实新样本握手。
                8'h93: sensor_value=(prox_sent!=sample_index)?
                    ((sample_index==10)?8'h42:8'h02):0;
                8'h9C: sensor_value=(sample_index<5)?40+10*sample_index:
                    (sample_index<10)?90-10*(sample_index-5):
                    (sample_index==10)?255:20;
                8'hAF: sensor_value=1; // deliberately high even when FIFO empty
                8'hAE: sensor_value=(sample_index<88)?1:0;
                8'hFC: sensor_value=(position>=6 || motion<2)?20:
                    ((motion==2 && position<3)||(motion==3 && position>=3))?100:30;
                8'hFD: sensor_value=(position>=6 || motion<2)?20:
                    ((motion==2 && position<3)||(motion==3 && position>=3))?30:100;
                8'hFE: sensor_value=(position>=6 || motion>=2)?20:
                    ((motion==0 && position<3)||(motion==1 && position>=3))?100:30;
                8'hFF: sensor_value=(position>=6 || motion>=2)?20:
                    ((motion==0 && position<3)||(motion==1 && position>=3))?30:100;
                default: begin sensor_value=0; $fatal(1,"Unexpected register %h",regnum); end
            endcase
        end
    endfunction

    initial begin
        expected[0]=16'h8000; expected[1]=16'h83ff; expected[2]=16'h8e89;
        expected[3]=16'h8f00; expected[4]=16'ha000; expected[5]=16'ha1ff;
        expected[6]=16'ha200; expected[7]=16'ha341; expected[8]=16'ha687;
        expected[9]=16'haa00; expected[10]=16'hab04;
        expected[11]=16'h8045; expected[12]=16'hab01;
        #40; rst_n=1;
        forever begin
            await_start(); receive_byte(address);
            if(address!==8'h72) $fatal(1,"Wrong device/write address %h",address);
            if(nack_once) begin
                acknowledge(1); nack_once=0;
            end else begin
                acknowledge(0); receive_byte(pointer); acknowledge(0);
                if(init_index<13) begin
                    receive_byte(value);
                    if({pointer,value}!==expected[init_index])
                        $fatal(1,"Initialization %0d: got %h expected %h",init_index,{pointer,value},expected[init_index]);
                    init_index=init_index+1; acknowledge(0);
                end else begin
                    // A read must use a repeated START without an intervening STOP.
                    @(posedge scl);
                    @(sda);
                    if(sda!==0 || scl!==1) $fatal(1,"Missing repeated START");
                    receive_byte(address);
                    if(address!==8'h73) $fatal(1,"Wrong device/read address");
                    acknowledge(0); transmit_byte(sensor_value(pointer)); reads=reads+1;
                    if(pointer==8'h9C) prox_sent=sample_index;
                    if(pointer==8'hFF) sample_index=sample_index+1;
                end
            end
            @(posedge sda);
            if(scl!==1) $fatal(1,"Missing STOP");
        end
    end
    always @(posedge clk) begin
        #1;
        if(dut.swipe_left) left_events=left_events+1;
        if(dut.swipe_right) right_events=right_events+1;
        if(dut.swipe_up) up_events=up_events+1;
        if(dut.swipe_down) down_events=down_events+1;
        if(dut.u_logger.event_push) uart_events=uart_events+1;
        if(dut.prox_valid) begin
            prox_samples=prox_samples+1;
            if(dut.prox_data==255) $fatal(1,"Saturated PDATA published");
        end
        if(dut.near_detected) near_events=near_events+1;
        if(dut.far_detected) far_events=far_events+1;
        if(dut.swipe_right && sample_index<22) $fatal(1,"First motion must be LEFT");
        if(dut.swipe_left && sample_index>=22) $fatal(1,"Second motion must be RIGHT");
        if(dut.gesture_valid) begin
            valid_count=valid_count+1;
            if(sample_index<=44 && {dut.gesture_u,dut.gesture_d}!==16'h1414)
                $fatal(1,"Non-atomic FIFO dataset");
        end
    end
    initial begin
        wait(sample_index==88);
        repeat(5000) @(posedge clk);
        if(left_events!=1 || right_events!=1 || up_events!=1 || down_events!=1 || valid_count!=88)
            $fatal(1,"events L=%0d R=%0d U=%0d D=%0d valid=%0d",left_events,right_events,up_events,down_events,valid_count);
        if(uart_events!=4)$fatal(1,"Recognition pulses did not reach UART event queue");
        if(left_led || right_led) $fatal(1,"LED hold did not expire");
        if(near_events!=1 || far_events!=1 || prox_samples!=88)
            $fatal(1,"Proximity pipeline near=%0d far=%0d samples=%0d",near_events,far_events,prox_samples);
        if(!diag_ready || diag_errors!=1 || diag_recoveries!=0)$fatal(1,"diagnostic status/error mapping");
        $display("PASS diagnostic APDS: initialization, NACK retry, repeated START, 88 FIFO datasets, all four directions, empty FIFO, LED expiry");
        $finish;
    end
    initial begin #5000000; $fatal(1,"System timeout"); end
endmodule
