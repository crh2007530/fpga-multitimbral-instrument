`timescale 1ns/1ps
module tb_max_volume;
    reg clk=0;always #20.325203252 clk=~clk;
    reg rst=0,injecting=1,inject_valid=1,measure=0;
    reg signed [15:0] injected=0;
    reg [63:0] raw=0;
    reg [1:0] mode=0;
    wire loud_bclk,loud_lr,loud_din,loud_xsmt;
    wire quiet_bclk,quiet_lr,quiet_din,quiet_xsmt;
    wire [15:0] loud_underruns,quiet_underruns;
    pcm_pressure_poly8 #(.WARMUP_FRAMES(8),.DYNAMIC_PITCH(1),.MASTER_SHIFT(2)) loud(
        .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.pitch_mode(mode),
        .bclk(loud_bclk),.lrclk(loud_lr),.din(loud_din),.xsmt(loud_xsmt),.underruns(loud_underruns));
    pcm_pressure_poly8 #(.WARMUP_FRAMES(8),.DYNAMIC_PITCH(1),.MASTER_SHIFT(-2)) reference(
        .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.pitch_mode(mode),
        .bclk(quiet_bclk),.lrclk(quiet_lr),.din(quiet_din),.xsmt(quiet_xsmt),.underruns(quiet_underruns));
    genvar ch;
    generate for(ch=0;ch<8;ch=ch+1) begin: injection
        initial begin
            force loud.notes[ch].note.pcm=injected;
            force loud.notes[ch].note.pcm_valid=inject_valid;
            force reference.notes[ch].note.pcm=injected;
            force reference.notes[ch].note.pcm_valid=inject_valid;
            wait(!injecting);
            release loud.notes[ch].note.pcm;release loud.notes[ch].note.pcm_valid;
            release reference.notes[ch].note.pcm;release reference.notes[ch].note.pcm_valid;
        end
    end endgenerate
    task vector;
        input signed [15:0] pcm;
        input signed [15:0] expected;
        begin
            @(negedge clk);injected=pcm;repeat(4) @(negedge clk);
            if(loud.mixed_pcm!==expected) $fatal(1,"limit input=%0d got=%0d expected=%0d",pcm,loud.mixed_pcm,expected);
        end
    endtask
    integer ix=0,frames=0,linear=0,positive_clips=0,negative_clips=0,j;
    reg aligned=0,last_lr=0;
    reg [15:0] ll=0,lr=0,ql=0,qr=0;
    integer lsample,qsample,difference;
    always @(posedge loud_bclk) if(rst && measure) begin
        if(loud_lr!==quiet_lr || loud_bclk!==quiet_bclk) $fatal(1,"I2S clocks");
        if(last_lr && !loud_lr) begin ix=0;aligned=1;end
        if(aligned) begin
            if(ix>=1 && ix<=16) begin ll[16-ix]=loud_din;ql[16-ix]=quiet_din;end
            if(ix>=33 && ix<=48) begin lr[48-ix]=loud_din;qr[48-ix]=quiet_din;end
            if(ix==63) begin
                if(ll!==lr || ql!==qr) $fatal(1,"stereo mismatch");
                lsample=$signed(ll);qsample=$signed(ql);frames=frames+1;
                if(qsample>=2048) begin
                    if(lsample!==32767) $fatal(1,"positive wrap/clamp");positive_clips=positive_clips+1;
                end else if(qsample<=-2049) begin
                    if(lsample!==-32768) $fatal(1,"negative wrap/clamp");negative_clips=negative_clips+1;
                end else begin
                    difference=lsample-qsample*16;
                    if(difference<0 || difference>15) $fatal(1,"gain old=%0d new=%0d difference=%0d",qsample,lsample,difference);
                    if(qsample!=0) linear=linear+1;
                end
            end
            ix=(ix+1)%64;
        end
        last_lr=loud_lr;
    end
    initial begin
        #1000;rst=1;
        vector(0,0);vector(1,32);vector(-1,-32);
        vector(1023,32736);vector(1024,32767);vector(1025,32767);
        vector(-1023,-32736);vector(-1024,-32768);vector(-1025,-32768);
        vector(8192,32767);vector(-8192,-32768);
        vector(32767,32767);vector(-32768,-32768);
        @(negedge clk);inject_valid=0;injected=123;
        repeat(4) @(negedge clk);if(loud.mixed_pcm!==16'sh8000 || loud.mixed_valid!==0) $fatal(1,"invalid input must hold PCM");
        @(negedge clk);rst=0;injecting=0;
        repeat(20) @(negedge clk);rst=1;raw={8{8'd32}};measure=1;
        wait(frames>=512);@(negedge clk);raw={8{8'd255}};mode=2;
        wait(frames>=1024);measure=0;
        if(linear<50 || positive_clips<10 || negative_clips<10) $fatal(1,"coverage linear=%0d clips=%0d/%0d",linear,positive_clips,negative_clips);
        if(loud_underruns!==0 || quiet_underruns!==0) $fatal(1,"underrun");
        $display("PASS MAX VOLUME: signed boundary/extreme vectors, saturation without wrap, actual I2S gain 16x old (rounding <16 LSB), stereo, middle/high banks, clips +%0d/-%0d, linear=%0d, no underrun",positive_clips,negative_clips,linear);
        $finish;
    end
    initial begin #50000000;$fatal(1,"volume timeout");end
endmodule
