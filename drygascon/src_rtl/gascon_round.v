`timescale 1ns / 1ps
`default_nettype none

module gascon_round
#(
    parameter CAPACITY              = 9     // DRYSPONGE_CAPACITYSIZE64
) (
    input  wire [64*CAPACITY-1:0] din,
    input  wire [4                          -1:0] round,
    output wire [64*CAPACITY-1:0] out
);

genvar i;
wire [7:0] round_constant;
assign round_constant = (((4'hf - round)<<4) | round);

// ===== add_constant
wire [64-1:0] din_array         [0:CAPACITY-1];
wire [64-1:0] add_constant      [0:CAPACITY-1];

generate
    for (i=0; i<CAPACITY; i=i+1) begin: g_add_constant
        assign din_array[i] = din[64*CAPACITY-64*(i+1) +: 64];

        if (i == CAPACITY/2)
            assign add_constant[i] = din_array[i] ^ round_constant;
        else
            assign add_constant[i] = din_array[i];
    end
endgenerate

// ===== sbox
wire [64-1:0]  sbox_stage0  [0:CAPACITY-1];
generate
    for (i=0; i<CAPACITY; i=i+2) begin: g_sbox0
        assign sbox_stage0[i] = add_constant[i] ^ add_constant[(CAPACITY+i-1)%CAPACITY];
        if (i+1 < CAPACITY)
            assign sbox_stage0[i+1] = add_constant[i+1];
    end
endgenerate

wire [64-1:0]  t            [0:CAPACITY-1];
wire [64-1:0]  sbox_stage1  [0:CAPACITY-1];
generate    
    for (i=0; i<CAPACITY; i=i+1) begin: g_sbox1
        assign t[i]           =  (~sbox_stage0[i]) & sbox_stage0[(i+1)%CAPACITY];
        assign sbox_stage1[i] =  sbox_stage0[i] ^ t[(i+1)%CAPACITY];
    end
endgenerate

wire [64-1:0]  sbox_stage2  [0:CAPACITY-1];
generate
    for (i=0; i<CAPACITY; i=i+2) begin: g_sbox2
        assign sbox_stage2[i] = sbox_stage1[(i+1)%CAPACITY] ^ sbox_stage1[i];
        if (i+1 < CAPACITY)
            assign sbox_stage2[i+1] = sbox_stage1[i+1];
    end
endgenerate

wire [64-1:0]  sbox  [0:CAPACITY-1];
generate 
    for (i=0; i<CAPACITY; i=i+1) begin: g_sbox
        if (i == CAPACITY/2)
            assign sbox[i] = ~sbox_stage2[i];
        else
            assign sbox[i] = sbox_stage2[i];
    end
endgenerate

// ===== linlayer
wire [6*CAPACITY -1:0]     rot_lut0 = {6'd43,6'd09,6'd53,6'd31,6'd07,6'd10,6'd01,6'd61,6'd19};
wire [6*CAPACITY -1:0]     rot_lut1 = {6'd50,6'd46,6'd58,6'd26,6'd40,6'd17,6'd06,6'd38,6'd28};

wire [64-1:0]  lin_layer_r0  [0:CAPACITY-1];
wire [64-1:0]  lin_layer_r1  [0:CAPACITY-1];
wire [64-1:0]  lin_layer     [0:CAPACITY-1];

generate
    for (i=0; i<CAPACITY; i=i+1) begin: g_linlayer
        birotr u_birotr0(.out(lin_layer_r0[i]), .din(sbox[i]), .shift(rot_lut0[i*6+:6]));
        birotr u_birotr1(.out(lin_layer_r1[i]), .din(sbox[i]), .shift(rot_lut1[i*6+:6]));
        assign lin_layer[i] =  sbox[i] ^ lin_layer_r0[i] ^ lin_layer_r1[i];

        assign out[64*CAPACITY-64*(i+1) +: 64] = lin_layer[i];
    end
endgenerate

endmodule