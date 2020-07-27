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

// Algorithm parameters
localparam                      SIZE_KEY        = 256;
localparam                      SIZE_NPUB       = 128;
localparam                      SIZE_DATA       = 256;

// Design parameters
localparam                      WIDTH_KEY       = SIZE_KEY;
localparam                      WIDTH_DATA      = SIZE_DATA;
localparam                      WORD_KEY        = SIZE_KEY/CCSW;
localparam                      WORD_NPUB       = SIZE_NPUB/CCW;
localparam                      WORD_DATA       = SIZE_DATA/CCW;


assign bdo_valid = 0;


// ========= Main
localparam                      DRYSPONGE_CAPACITYSIZE64    = 9;
localparam                      WIDTH_C                     = 64*DRYSPONGE_CAPACITYSIZE64;
localparam                      WIDTH_X                     = 128;
localparam                      WIDTH_STATE                 = 3;
localparam                      S_INIT                      = 0;
localparam                      S_KS_INIT                   = 1;
localparam                      S_KS                        = 2;
localparam                      S_LOAD                      = 3;
localparam                      S_PROCESS                   = 4;

reg         [WIDTH_C    -1:0]   cc;
reg         [WIDTH_X    -1:0]   xx;

reg         [WIDTH_STATE-1:0]   state;
reg         [WIDTH_STATE-1:0]   nstate;
reg         [4          -1:0]   rnd;
reg         [4          -1:0]   cnt;
reg                             ena_cnt;
reg                             ena_rnd;
reg                             rst_cnt;
reg                             rst_rnd;
reg                             ena_c;
reg                             ena_x;
reg                             sel_c0;
reg                             sel_cx;
reg                             sel_x;
reg                             ld_data;


// ========= Input 
localparam                      S_DI_INIT   = 0;
localparam                      S_DI_KEYCHK = 1;
localparam                      S_DI_LDKEY  = 2;
localparam                      S_DI_LD     = 3;
localparam                      S_DI_WAIT   = 4;
localparam                      HDR_NPUB    = 4'b1101;
localparam                      HDR_PT      = 4'b0100;
reg         [4          -1:0]   st_di;
reg         [4          -1:0]   nst_di;

reg         [WIDTH_KEY  -1:0]   r_key;
reg         [WIDTH_DATA -1:0]   r_data;
reg         [4          -1:0]   r_bdi_type;
reg                             r_bdi_eot;
reg                             r_bdi_eoi;

reg         [4          -1:0]   cnt_di;

reg                             rst_cnt_di;
reg                             ena_cnt_di;
reg                             ena_key;
reg                             ena_data;

reg                             key_rdy;
reg                             bdi_rdy;
wire        [WIDTH_C    -1:0]   gascon_out;



`ifdef SIMULATION
// -------------------------------------------------------------------
// ==== Debug signals
// -------------------------------------------------------------------

wire        [64         -1:0]   dbg_cc[0:DRYSPONGE_CAPACITYSIZE64-1];
wire        [64         -1:0]   dbg_gascon[0:DRYSPONGE_CAPACITYSIZE64-1];
genvar i;
generate 
    for (i=0; i<DRYSPONGE_CAPACITYSIZE64; i=i+1) begin: g_dbg_cc
        assign dbg_cc[i] = cc[WIDTH_C-i*64-1 -: 64];
    end
    for (i=0; i<DRYSPONGE_CAPACITYSIZE64; i=i+1) begin: g_dbg_gascon
        assign dbg_gascon[i] = gascon_out[WIDTH_C-i*64-1 -: 64];
    end
endgenerate

`endif

// -------------------------------------------------------------------
// ==== Datapath
// -------------------------------------------------------------------

gascon_round u_gascon_round(.out(gascon_out), .din(cc), .round(rnd));

// -------------------------------------------------------------------
// ==== Control
// -------------------------------------------------------------------
always @(posedge clk) begin
    if (rst)
        state <= S_INIT;
    else
        state <= nstate;

    if (rst_rnd)
        rnd <= 0;
    else if (ena_rnd)
        rnd <= rnd+1;

    if (ena_c) begin
        // c[0]
        cc[WIDTH_C-64 +:  64] <= (sel_c0) ? r_key[WIDTH_KEY-64 +: 64] : gascon_out[WIDTH_C-64 +: 64];
        
        // c[1] - c[8]
        if (sel_cx) begin
            cc[WIDTH_C-256 +: 192] <= r_key[WIDTH_KEY-256 +: 192];
            cc[WIDTH_C-512 +: 256] <= r_key;
            cc[          0 +:  64] <= r_key[WIDTH_KEY- 64 +: 64];
        end else begin
            cc[          0 +: 512] <= gascon_out[0 +: 512];
        end
    end

    if (ena_x) begin
        xx <= (sel_x) ? gascon_out[WIDTH_C-128 +: 128] : 0;
    end
end

// FSM Core

always @ (state or cnt or st_di)
begin
    nstate  <= state;
    rst_rnd <= 0;
    ena_rnd <= 0;

    ena_cnt <= 0;
    rst_cnt <= 0;

    ena_c   <= 0;
    ena_x   <= 0;
    sel_c0  <= 0;
    sel_cx  <= 0;
    sel_x   <= 0;
    ld_data <= 0;
    
    case(state)
    S_INIT: begin       // Initialization
        rst_rnd <= 1;
        if (st_di == S_DI_LD) 
            nstate  <= S_KS_INIT;
    end

    S_KS_INIT: begin
        ena_c  <= 1;
        sel_c0 <= 1;
        sel_cx <= 1;
        nstate <= S_KS;
    end

    S_KS: begin 
        ena_c  <= 1;
        sel_c0 <= 1;
        sel_cx <= 0;

        ena_x <= 1;
        sel_x <= 1;
        nstate <= S_LOAD;
    end

    S_LOAD: begin
        ld_data <= 1;
        nstate <= S_PROCESS;
    end

    S_PROCESS: begin
        
    end
    endcase
end // FSM Core




// -------------------------------------------------------------------
// FSM Input
// -------------------------------------------------------------------
assign key_ready = key_rdy;
assign bdi_ready = bdi_rdy;

always @(posedge clk) begin
    if (rst_cnt_di)
        cnt_di <= 0;
    else if (ena_cnt_di)
        cnt_di <= cnt_di + 1;

    if (ena_data) begin
        r_data <= {r_data[WIDTH_DATA-CCW-1:0], bdi};
        r_bdi_type <= bdi_type;
        r_bdi_eoi <= bdi_eoi;
        r_bdi_eot <= bdi_eot;
    end

    if (ena_key)
        r_key <= {r_key[WIDTH_KEY-CCSW-1:0], key};

    if (rst)
        st_di <= S_DI_INIT;
    else
        st_di <= nst_di;
end

always @ (st_di or cnt_di 
    or bdi_type or bdi_valid or key_valid
    or ld_data or r_bdi_eoi or r_bdi_eot)
begin
    nst_di       <= st_di;
    rst_cnt_di   <= 0;
    ena_cnt_di   <= 0;    
    ena_key      <= 0;
    ena_data     <= 0;
    bdi_rdy      <= 0;
    key_rdy      <= 0;

    case (st_di)
    S_DI_INIT: begin       // Initialization
        rst_cnt_di <= 1;
        if (bdi_valid || key_valid)
            nst_di  <= S_DI_KEYCHK;
    end

    S_DI_KEYCHK: begin        
        if (!key_update && bdi_valid)
            nst_di <= S_DI_LD;
        else
            nst_di <= S_DI_LDKEY;
    end

    S_DI_LDKEY: begin
        key_rdy <= 1;
        if (key_valid) begin            
            ena_key    <= 1;
            ena_cnt_di <= 1;
            if (cnt_di == WORD_KEY-1) begin          
                nst_di     <= S_DI_LD;
                rst_cnt_di <= 1;
            end
        end
    end

    S_DI_LD: begin
        bdi_rdy <= 1;
        if (bdi_valid) begin
            ena_data   <= 1;
            ena_cnt_di <= 1;
            if (bdi_type == HDR_NPUB && cnt_di == WORD_NPUB-1) begin
                rst_cnt_di <= 1;
                nst_di <= S_DI_WAIT;
            end else if (bdi_type == HDR_PT && cnt_di == WORD_DATA-1) begin
                rst_cnt_di <= 1;
                nst_di <= S_DI_WAIT;
            end
        end
    end

    S_DI_WAIT: begin
        if (ld_data) begin
            if (r_bdi_eoi) begin
                nst_di <= S_DI_INIT;
            end else begin
                nst_di <= S_DI_LD;
            end
        end
    end 
    endcase
end


endmodule