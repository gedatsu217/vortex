
`include "VX_platform.vh"

module VX_countones #(
    parameter N = 10
) (
    input wire [N-1:0]       valids,
    output reg [$clog2(N):0] count    
);
    always @(*) begin
        count = 0;
        for (integer i = N-1; i >= 0; i = i - 1) begin
            if (valids[i]) begin
                count = count + 1;
            end
        end
    end

endmodule