// This module is taken from:
// Implementations/crypto_aead/drygascon128/add_verilog/drygascon128_1round_cycle/drygascon128_ACC_PIPE_MIX_SHIFT_REG.v 
// source: (sebastien-riou/DryGascon)[https://github.com/sebastien-riou/DryGASCON]

`timescale 1ns / 1ps
`default_nettype none

module birotr(
    input wire [64-1:0] din,
    input wire [ 6-1:0] shift,
    output reg [64-1:0] out
    );
wire [32-1:0] i0 = din[0*32+:32];
wire [32-1:0] i1 = din[1*32+:32];
wire [ 6-1:0] shift2 = shift>>1;
wire [ 6-1:0] shift3 = (shift2 + 1'b1) % 6'd32;
always @* begin
    if(shift & 1'b1) begin
        out[ 0+:32] = (i1>>shift2) | (i1 << (6'd32-shift2));
        out[32+:32] = (i0>>shift3) | (i0 << (6'd32-shift3));
    end else begin
        out[ 0+:32] = (i0>>shift2) | (i0 << (6'd32-shift2));
        out[32+:32] = (i1>>shift2) | (i1 << (6'd32-shift2));
    end
end
endmodule