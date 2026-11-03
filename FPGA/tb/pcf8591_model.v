`timescale 1ns/1ps
// Wire-level behavioral peripheral, no use of DUT state. Conversion result
// register starts with 0x80 / deliberately stale 0xee on each new read.
module pcf8591_model #(parameter [6:0] ADDRESS=7'h48)(
    inout wire scl,sda,input wire present,
    input wire [31:0] analog_codes,output reg [31:0] transactions);
    reg drive_low=0;
    assign sda=drive_low ? 1'b0 : 1'bz;
    reg [7:0] b,control;
    reg got_ack;
    integer k;
    task receive_byte;
        output [7:0] result;
        integer j;
        begin
            result=0;
            for(j=0;j<8;j=j+1) begin @(posedge scl);result={result[6:0],sda};end
        end
    endtask
    task acknowledge;
        begin
            @(negedge scl);drive_low=1;
            @(posedge scl);@(negedge scl);drive_low=0;
        end
    endtask
    task send_byte;
        input [7:0] value;
        output accepted;
        integer j;
        begin
            for(j=7;j>=0;j=j-1) begin
                drive_low=!value[j];@(posedge scl);@(negedge scl);
            end
            drive_low=0;@(posedge scl);accepted=!sda;@(negedge scl);
        end
    endtask
    initial begin
        transactions=0;control=0;
        forever begin
            @(negedge sda);
            if(scl===1'b1) begin
                receive_byte(b);
                if(present && b[7:1]==ADDRESS) begin
                    acknowledge();
                    if(!b[0]) begin
                        receive_byte(control);
                        if(control!==8'h44) $fatal(1,"PCF control must be 44: %h",control);
                        acknowledge();
                    end else begin
                        send_byte(8'hee,got_ack);
                        if(!got_ack) $fatal(1,"Dummy byte was NACKed");
                        for(k=0;k<4;k=k+1) begin
                            send_byte(analog_codes[k*8+:8],got_ack);
                            if(got_ack !== (k!=3)) $fatal(1,"PCF data ACK mismatch ch%0d",k);
                        end
                        transactions=transactions+1;
                    end
                end
            end
        end
    end
endmodule
