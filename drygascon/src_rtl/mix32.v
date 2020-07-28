`timescale 1ns / 1ps
`default_nettype none

module mix32
#(
    parameter CW            = 5,    // DRYSPONGE_CAPACITYSIZE64
    parameter XW32          = 4     // 
) (
    input  wire [64*CW-1:0]   c,
    input  wire [32*XW32-1:0] x,
    input  wire [CW*2 -1:0]   d,
    output wire [64*CW-1:0]   out
);

`include "utils.vh"

wire [64-1:0] cc                [0:CW-1];
wire [64-1:0] oo                [0:CW-1];
wire [2 -1:0] idx               [0:CW-1];
wire [32-1:0] xx                [0:XW32-1];
reg  [32-1:0] xw                [0:CW-1];


genvar i;
generate
    for (i=0; i<XW32; i=i+1) begin
        assign xx[i] = x[32*XW32-32*(i+1) +: 32];
    end
    for (i=0; i<CW; i=i+1) begin
        // Format input/output to array
        assign cc[i] = c[64*CW-64*(i+1) +: 64];
        assign out[64*CW-64*(i+1) +: 64] = oo[i];

        // Core operation
        assign idx[i] = d[2*i +: 2];

        always@* begin
            case (idx[i])
            0: xw[i] <= xx[0];
            1: xw[i] <= xx[1];
            2: xw[i] <= xx[2];
            3: xw[i] <= xx[3];
            endcase
        end
        
        assign oo[i] = cc[i] ^ {xw[i], 32*{1'b0}};
    end
endgenerate

endmodule