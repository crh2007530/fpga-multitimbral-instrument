`timescale 1ns/1ps
// TTP229-BSF default active-low serial interface (not I2C).
// 50 kHz, 16 clocks, 8 ms idle (>2 ms resets bit position), 1 s startup.
// Only keys 1..3 are interpreted. Works with first keys of 8/16-key mode.
module ttp229_pitch #(
    parameter integer HALF_CYCLES=500, GAP_CYCLES=400000, START_CYCLES=50000000
)(input wire clk,rst_n,input wire sdo,output reg scl,
  output reg [7:0] keys,output reg frame_valid,output reg [1:0] pitch_mode,
  output reg [31:0] scan_count,output reg [15:0] full_keys,output wire sdo_level);
    reg [1:0] sync;
    reg [31:0] count;
    reg [1:0] state;
    reg [3:0] bit_index;
    reg [15:0] shift;
    reg [7:0] previous;
    reg have_previous;
    assign sdo_level=sync[1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) sync<=2'b11;
        else sync<={sync[0],sdo};
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            scl<=1;count<=START_CYCLES-1;state<=0;bit_index<=0;shift<=0;
            keys<=0;frame_valid<=0;pitch_mode<=0;previous<=0;have_previous<=0;
            scan_count<=0;full_keys<=0;
        end else begin
            frame_valid<=0;
            if(count!=0) count<=count-1'b1;
            else case(state)
                0: begin scl<=0;bit_index<=0;state<=1;count<=HALF_CYCLES-1;end
                1: begin // Data has settled after falling edge; sample before rising.
                    shift[bit_index]<=~sync[1];scl<=1;state<=2;count<=HALF_CYCLES-1;
                end
                2: begin
                    if(bit_index==15) begin
                        keys<=shift[7:0];frame_valid<=1;
                        full_keys<=shift;scan_count<=scan_count+1'b1;
                        // Reject ambiguous multi-key/shorted-low input; two matching frames.
                        if(have_previous && previous==shift[7:0]) case(shift[7:0])
                            8'h01:pitch_mode<=1; // C4
                            8'h02:pitch_mode<=0; // original C5
                            8'h04:pitch_mode<=2; // C6
                            default: ; // release retains selection; no touch-generated note
                        endcase
                        previous<=shift[7:0];have_previous<=1;
                        state<=0;count<=GAP_CYCLES-1;
                    end else begin
                        bit_index<=bit_index+1'b1;scl<=0;state<=1;count<=HALF_CYCLES-1;
                    end
                end
                default: begin state<=0;scl<=1;count<=GAP_CYCLES-1;end
            endcase
        end
    end
endmodule
