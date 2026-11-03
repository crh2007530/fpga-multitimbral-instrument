`timescale 1ns/1ps
// Open drain I2C primitive. op: 0 START/repeated START, 1 STOP,
// 2 WRITE byte, 3 READ byte, 4 nine-clock bus clear + STOP.
module i2c_byte_master #(
    parameter integer QUARTER_CYCLES=62,
    parameter integer TIMEOUT_CYCLES=24600
) (
    input wire clk, rst_n, req,
    input wire [2:0] op,
    input wire [7:0] tx_data,
    input wire read_ack,
    output wire ready,
    output reg done, error, nack,
    output reg [7:0] rx_data,
    inout wire scl, sda
);
    reg scl_low, sda_low, busy;
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    assign ready = !busy;
    reg [1:0] scl_sync, sda_sync;
    reg [2:0] command;
    reg [7:0] tx, rx;
    reg ack;
    reg [3:0] bit_no, phase;
    reg [15:0] quarter_count;
    reg [31:0] watchdog;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync<=3; sda_sync<=3;
        end else begin
            scl_sync<={scl_sync[0],scl}; sda_sync<={sda_sync[0],sda};
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_low<=0; sda_low<=0; busy<=0; done<=0; error<=0;
            nack<=0; rx_data<=0; quarter_count<=0; watchdog<=0;
            command<=0; tx<=0; rx<=0; ack<=0; bit_no<=0; phase<=0;
        end else begin
            done<=0;
            if (!busy) begin
                if (req) begin
                    busy<=1; command<=op; tx<=tx_data; ack<=read_ack;
                    bit_no<=0; phase<=0; rx<=0; nack<=0; error<=0;
                    watchdog<=0; quarter_count<=0;
                end
            end else if (watchdog==TIMEOUT_CYCLES-1) begin
                busy<=0; done<=1; error<=1; scl_low<=0; sda_low<=0;
            end else begin
                watchdog<=watchdog+1;
                if (quarter_count==QUARTER_CYCLES-1) begin
                    quarter_count<=0;
                    case (command)
                    0: case (phase)
                        0: begin sda_low<=0; phase<=1; end
                        1: begin scl_low<=0; phase<=2; end
                        2: if (scl_sync[1] && sda_sync[1]) phase<=3;
                        3: phase<=4; // >= 5 us repeated START setup
                        4: begin sda_low<=1; phase<=5; end
                        5: phase<=6;
                        6: begin scl_low<=1; busy<=0; done<=1; end
                    endcase
                    1: case (phase)
                        0: begin scl_low<=1; sda_low<=1; phase<=1; end
                        1: begin scl_low<=0; phase<=2; end
                        2: if (scl_sync[1]) phase<=3;
                        3: begin sda_low<=0; phase<=4; end
                        4: phase<=5;
                        5: begin busy<=0; done<=1; end
                    endcase
                    2,3,4: case (phase)
                        0: begin
                            scl_low<=1;
                            if (command==4) sda_low<=0;
                            else if (bit_no==8)
                                sda_low <= (command==3) && ack;
                            else sda_low <= (command==2) && !tx[7-bit_no];
                            phase<=1;
                        end
                        1: begin scl_low<=0; phase<=2; end
                        2: if (scl_sync[1]) begin
                            if (command==3 && bit_no<8) rx<={rx[6:0],sda_sync[1]};
                            if (command==2 && bit_no==8) nack<=sda_sync[1];
                            phase<=3;
                        end
                        3: begin
                            scl_low<=1;
                            if (bit_no==8) begin
                                sda_low<=0;
                                if (command==4) begin command<=1; phase<=0; end
                                else begin busy<=0; done<=1; rx_data<=rx; end
                            end else begin bit_no<=bit_no+4'd1; phase<=0; end
                        end
                    endcase
                    default: begin busy<=0; done<=1; error<=1; end
                    endcase
                end else quarter_count<=quarter_count+16'd1;
            end
        end
    end
endmodule
