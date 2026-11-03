// Q1.15 envelope, sample-counted linear ramps, no CPU. Retrigger starts
// attack at current envelope level, releases from current level.
module adsr_env #(
    parameter integer ATTACK_STEP=137, // ~5 ms @ 48046.875 Hz
    parameter integer DECAY_STEP=7,    // ~39 ms to sustain 19660
    parameter [15:0] SUSTAIN_LEVEL=19660,
    parameter integer RELEASE_STEP=9  // <=76 ms from full scale
)(input wire clk,rst_n,sample_ce,note_on,note_off,
    output reg [15:0] level,output wire active,output reg [2:0] state);
    localparam IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
    assign active=(state!=IDLE);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin level<=0; state<=IDLE; end
        else if (note_on) state<=ATTACK;
        else if (note_off && active) state<=RELEASE;
        else if (sample_ce) case (state)
            IDLE: level<=0;
            ATTACK: if (level>=32767-ATTACK_STEP) begin level<=32767;state<=DECAY;end
                else level<=level+ATTACK_STEP[15:0];
            DECAY: if (level<=SUSTAIN_LEVEL+DECAY_STEP) begin level<=SUSTAIN_LEVEL;state<=SUSTAIN;end
                else level<=level-DECAY_STEP[15:0];
            SUSTAIN: level<=SUSTAIN_LEVEL;
            RELEASE: if (level<=RELEASE_STEP) begin level<=0;state<=IDLE;end
                else level<=level-RELEASE_STEP[15:0];
            default: begin level<=0; state<=IDLE; end
        endcase
    end
endmodule
