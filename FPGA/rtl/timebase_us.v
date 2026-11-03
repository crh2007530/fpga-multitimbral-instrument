module timebase_us #(parameter integer CLOCK_HZ=24600000)(
    input wire clk,rst_n,output reg [31:0] time_us);
    reg [31:0] fractional;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin fractional<=0; time_us<=0; end
        else if (fractional>=CLOCK_HZ-1000000) begin
            fractional<=fractional+1000000-CLOCK_HZ; time_us<=time_us+1;
        end else fractional<=fractional+1000000;
    end
endmodule
