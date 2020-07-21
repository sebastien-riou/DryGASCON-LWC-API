`timescale 1ns / 1ps
`default_nettype none

module gascon256 #(
    parameter                   CCW         = 32,
    parameter                   CCWdiv8     = 8 ,
    parameter                   CCSW        = 32    
) (
    input wire                  clk             ,
    input wire                  rst             ,
    // --PreProcessor===============================================
    // ----!key----------------------------------------------------
    input  wire [CCSW   -1:0]   key             ,
    input  wire                 key_valid       ,
    output wire                 key_ready       ,
    // ----!Data----------------------------------------------------
    input  wire [CCW    -1:0]   bdi             ,
    input  wire                 bdi_valid       ,
    output wire                 bdi_ready       ,
    input  wire [CCWdiv8-1:0]   bdi_pad_loc     ,
    input  wire [CCWdiv8-1:0]   bdi_valid_bytes ,
    input  wire [3      -1:0]   bdi_size        ,
    input  wire                 bdi_eot         ,
    input  wire                 bdi_eoi         ,
    input  wire [4      -1:0]   bdi_type        ,
    input  wire                 decrypt_in      ,
    input  wire                 key_update      ,
    input  wire                 hash_in         ,
    // --!Post Processor=========================================
    output wire [CCW    -1:0]   bdo             ,
    output wire                 bdo_valid       ,
    input  wire                 bdo_ready       ,
    output wire [4      -1:0]   bdo_type        ,
    output wire [CCWdiv8-1:0]   bdo_valid_bytes ,
    output wire                 end_of_block    ,
    output wire                 msg_auth_valid  ,
    input  wire                 msg_auth_ready  ,
    output wire                 msg_auth
);

assign key_ready = 1;
assign bdi_ready = 1;
assign bdo_valid = 1;


endmodule