// Direction uses ONLY first upward crossings of per-channel 25/50/75% peaks.
// Sample falloff is a frame boundary/rearm condition, never a direction sign.
module rising_order_recognizer #(
    parameter integer MIN_LEVEL=20, MIN_DELTA=8, MIN_PEAK=40,
    parameter integer START_LEVEL=24, RELEASE_LEVEL=32,
    parameter integer FILTER_SAMPLES=1, NEUTRAL_SAMPLES=4,
    parameter integer TIMEOUT_CYCLES=25000000,
    parameter integer ACTIVE_TIMEOUT_CYCLES=100000000,
    parameter integer FRAME_ADDR_BITS=8
) (
    input wire clk,rst_n,clear,valid,
    input wire [7:0] u,d,l,r,
    output reg swipe_up,swipe_down,swipe_left,swipe_right
);
    localparam integer DEPTH=2**FRAME_ADDR_BITS;
    localparam [2:0] COLLECT=0, PREPARE=1, READ_SAMPLE=2, USE_SAMPLE=3,
                     SELECT_AXIS=4, REPORT=5, WAIT_RELEASE=6;
    localparam [2:0] NONE=0, UP=1, DOWN=2, LEFT=3, RIGHT=4;
    reg [2:0] state, direction;
    reg active;
    reg ended_quiet,ended_gap;
    // A new wave can begin while the preceding frame is being scanned. One
    // skid sample covers the current I2C source (sample spacing > scan latency).
    reg deferred_valid;
    reg [31:0] deferred_sample;
    wire [7:0] su=deferred_valid?deferred_sample[31:24]:u;
    wire [7:0] sd=deferred_valid?deferred_sample[23:16]:d;
    wire [7:0] sl=deferred_valid?deferred_sample[15:8]:l;
    wire [7:0] sr=deferred_valid?deferred_sample[7:0]:r;
    wire wait_neutral=(state==WAIT_RELEASE);
    reg [31:0] memory[0:DEPTH-1];
    reg [FRAME_ADDR_BITS:0] count;
    reg [FRAME_ADDR_BITS-1:0] read_index;
    reg [31:0] scan_sample;
    reg [7:0] peak_u,peak_d,peak_l,peak_r;
    reg [8:0] max_ud,max_lr;
    reg [9:0] peak_level;
    reg [31:0] idle_count,active_count,low_count,neutral_count;
    reg frame_overflow /* synthesis syn_preserve=1 */;
    reg [7:0] thresholds[0:11]; // three levels for U, D, L, R respectively
    reg [FRAME_ADDR_BITS-1:0] first_cross[0:11];
    reg [11:0] seen;
    integer i;

    wire [9:0] level={2'b0,su}+{2'b0,sd}+{2'b0,sl}+{2'b0,sr};
    wire [7:0] max_value=((su>sd?su:sd)>(sl>sr?sl:sr))?(su>sd?su:sd):(sl>sr?sl:sr);
    wire [8:0] ud=su>sd?{1'b0,su}-{1'b0,sd}:{1'b0,sd}-{1'b0,su};
    wire [8:0] lr=sl>sr?{1'b0,sl}-{1'b0,sr}:{1'b0,sr}-{1'b0,sl};
    wire released=(level<(peak_level>>2) || max_value<=RELEASE_LEVEL);
    wire peak_qualified=(peak_u>=MIN_PEAK || peak_d>=MIN_PEAK || peak_l>=MIN_PEAK || peak_r>=MIN_PEAK);
    wire finish_low=peak_qualified && released && low_count>=NEUTRAL_SAMPLES-1;

    function [7:0] threshold;
        input [7:0] peak;
        input [1:0] numerator;
        reg [9:0] product;
        begin product=peak*numerator;threshold=product[9:2];if(threshold==0)threshold=1;end
    endfunction
    function [FRAME_ADDR_BITS:0] distance;
        input [FRAME_ADDR_BITS-1:0] a,b;
        begin distance=a>b?{1'b0,a}-{1'b0,b}:{1'b0,b}-{1'b0,a};end
    endfunction
    wire [FRAME_ADDR_BITS+2:0] ud_time={2'b0,distance(first_cross[0],first_cross[3])}+
        {2'b0,distance(first_cross[1],first_cross[4])}+{2'b0,distance(first_cross[2],first_cross[5])};
    wire [FRAME_ADDR_BITS+2:0] lr_time={2'b0,distance(first_cross[6],first_cross[9])}+
        {2'b0,distance(first_cross[7],first_cross[10])}+{2'b0,distance(first_cross[8],first_cross[11])};
    wire [1:0] up_votes={1'b0,(first_cross[0]<first_cross[3])}+{1'b0,(first_cross[1]<first_cross[4])}+{1'b0,(first_cross[2]<first_cross[5])};
    wire [1:0] down_votes={1'b0,(first_cross[0]>first_cross[3])}+{1'b0,(first_cross[1]>first_cross[4])}+{1'b0,(first_cross[2]>first_cross[5])};
    wire [1:0] left_votes={1'b0,(first_cross[6]<first_cross[9])}+{1'b0,(first_cross[7]<first_cross[10])}+{1'b0,(first_cross[8]<first_cross[11])};
    wire [1:0] right_votes={1'b0,(first_cross[6]>first_cross[9])}+{1'b0,(first_cross[7]>first_cross[10])}+{1'b0,(first_cross[8]>first_cross[11])};
    wire axis_vertical=(max_ud>=max_lr+MIN_DELTA) ||
        (!(max_lr>=max_ud+MIN_DELTA) && ud_time>lr_time);
    wire axis_horizontal=(max_lr>=max_ud+MIN_DELTA) ||
        (!(max_ud>=max_lr+MIN_DELTA) && lr_time>ud_time);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=COLLECT;active<=0;ended_quiet<=0;ended_gap<=0;deferred_valid<=0;deferred_sample<=0;
            direction<=NONE;count<=0;read_index<=0;scan_sample<=0;
            peak_u<=0;peak_d<=0;peak_l<=0;peak_r<=0;max_ud<=0;max_lr<=0;peak_level<=0;
            idle_count<=0;active_count<=0;low_count<=0;neutral_count<=0;seen<=0;frame_overflow<=0;
            swipe_up<=0;swipe_down<=0;swipe_left<=0;swipe_right<=0;
            for(i=0;i<12;i=i+1) begin thresholds[i]<=1;first_cross[i]<=0;end
        end else if(clear) begin
            state<=COLLECT;active<=0;ended_quiet<=0;ended_gap<=0;deferred_valid<=0;deferred_sample<=0;
            direction<=NONE;count<=0;read_index<=0;scan_sample<=0;
            peak_u<=0;peak_d<=0;peak_l<=0;peak_r<=0;max_ud<=0;max_lr<=0;peak_level<=0;
            idle_count<=0;active_count<=0;low_count<=0;neutral_count<=0;seen<=0;frame_overflow<=0;
            swipe_up<=0;swipe_down<=0;swipe_left<=0;swipe_right<=0;
            for(i=0;i<12;i=i+1) begin thresholds[i]<=1;first_cross[i]<=0;end
        end else begin
            swipe_up<=0;swipe_down<=0;swipe_left<=0;swipe_right<=0;
            if(state!=COLLECT && state!=WAIT_RELEASE && valid &&
               (ended_quiet || ended_gap) && !deferred_valid)begin
                deferred_sample<={u,d,l,r};deferred_valid<=1;
            end
            case(state)
                COLLECT: begin
                    if(deferred_valid)deferred_valid<=0;
                    if(active)active_count<=active_count+1'b1;
                    if(active && active_count>=ACTIVE_TIMEOUT_CYCLES-1) begin
                        // Discard a stale candidate, never emit a truncated gesture.
                        active<=0;state<=WAIT_RELEASE;neutral_count<=0;idle_count<=0;
                    end else if(valid || deferred_valid) begin
                        idle_count<=0;
                        if(active || (max_value>=START_LEVEL && level>=MIN_LEVEL)) begin
                            active<=1;
                            memory[count[FRAME_ADDR_BITS-1:0]]<={su,sd,sl,sr};count<=count+1'b1;
                            if(!active) begin
                                peak_u<=su;peak_d<=sd;peak_l<=sl;peak_r<=sr;
                                max_ud<=ud;max_lr<=lr;peak_level<=level;active_count<=0;low_count<=0;ended_quiet<=0;ended_gap<=0;
                            end else begin
                                if(su>peak_u)peak_u<=su;if(sd>peak_d)peak_d<=sd;
                                if(sl>peak_l)peak_l<=sl;if(sr>peak_r)peak_r<=sr;
                                if(ud>max_ud)max_ud<=ud;if(lr>max_lr)max_lr<=lr;
                                if(level>peak_level)peak_level<=level;
                                if(released && peak_qualified)low_count<=low_count+1'b1;else low_count<=0;
                            end
                            if(count==DEPTH-1) begin
                                frame_overflow<=1;active<=0;state<=WAIT_RELEASE;neutral_count<=0;
                            end else if(active && finish_low) begin
                                active<=0;state<=PREPARE;ended_quiet<=(max_value<=RELEASE_LEVEL);
                            end
                        end
                    end else if(active) begin
                        if(idle_count>=TIMEOUT_CYCLES-1)begin active<=0;state<=PREPARE;ended_quiet<=0;ended_gap<=1;end
                        else idle_count<=idle_count+1'b1;
                    end
                end
                PREPARE: begin
                    for(i=0;i<3;i=i+1) begin
                        thresholds[i]<=threshold(peak_u,i[1:0]+2'd1);
                        thresholds[i+3]<=threshold(peak_d,i[1:0]+2'd1);
                        thresholds[i+6]<=threshold(peak_l,i[1:0]+2'd1);
                        thresholds[i+9]<=threshold(peak_r,i[1:0]+2'd1);
                    end
                    seen<=0;read_index<=0;direction<=NONE;
                    for(i=0;i<12;i=i+1)first_cross[i]<=0;
                    state<=READ_SAMPLE;
                end
                READ_SAMPLE: begin scan_sample<=memory[read_index];state<=USE_SAMPLE;end
                USE_SAMPLE: begin
                    for(i=0;i<3;i=i+1) begin
                        if(!seen[i] && scan_sample[31:24]>=thresholds[i])begin seen[i]<=1;first_cross[i]<=read_index;end
                        if(!seen[i+3] && scan_sample[23:16]>=thresholds[i+3])begin seen[i+3]<=1;first_cross[i+3]<=read_index;end
                        if(!seen[i+6] && scan_sample[15:8]>=thresholds[i+6])begin seen[i+6]<=1;first_cross[i+6]<=read_index;end
                        if(!seen[i+9] && scan_sample[7:0]>=thresholds[i+9])begin seen[i+9]<=1;first_cross[i+9]<=read_index;end
                    end
                    if({1'b0,read_index}==count-1'b1)state<=SELECT_AXIS;
                    else begin read_index<=read_index+1'b1;state<=READ_SAMPLE;end
                end
                SELECT_AXIS: begin
                    if(count>=3 && (max_ud>=MIN_DELTA || max_lr>=MIN_DELTA)) begin
                        if(axis_vertical && &seen[5:0] && (peak_u>=MIN_PEAK || peak_d>=MIN_PEAK))begin
                            if(up_votes>=FILTER_SAMPLES && up_votes>down_votes)direction<=UP;
                            else if(down_votes>=FILTER_SAMPLES && down_votes>up_votes)direction<=DOWN;
                        end else if(axis_horizontal && &seen[11:6] && (peak_l>=MIN_PEAK || peak_r>=MIN_PEAK))begin
                            if(left_votes>=FILTER_SAMPLES && left_votes>right_votes)direction<=LEFT;
                            else if(right_votes>=FILTER_SAMPLES && right_votes>left_votes)direction<=RIGHT;
                        end
                    end
                    state<=REPORT;
                end
                REPORT: begin
                    swipe_up<=(direction==UP);swipe_down<=(direction==DOWN);
                    swipe_left<=(direction==LEFT);swipe_right<=(direction==RIGHT);
                    neutral_count<=0;
                    if(ended_quiet || ended_gap)begin
                        state<=COLLECT;count<=0;active_count<=0;low_count<=0;
                    end else state<=WAIT_RELEASE;
                end
                WAIT_RELEASE: begin
                    if(valid) begin
                        idle_count<=0;
                        if(max_value<=RELEASE_LEVEL)begin
                            if(neutral_count>=NEUTRAL_SAMPLES-1)begin
                                state<=COLLECT;count<=0;active_count<=0;low_count<=0;neutral_count<=0;
                            end else neutral_count<=neutral_count+1'b1;
                        end else neutral_count<=0;
                    end else if(idle_count>=TIMEOUT_CYCLES-1)begin
                        state<=COLLECT;count<=0;active_count<=0;low_count<=0;neutral_count<=0;
                    end else idle_count<=idle_count+1'b1;
                end
                default:begin state<=COLLECT;count<=0;active<=0;end
            endcase
        end
    end
endmodule
