`timescale 1ns / 1ps
`default_nettype none

module drygascon #(
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
localparam                      SIZE_DATA       = 128;


localparam                      DRYSPONGE_ROUNDS            = 8-1;
localparam                      DRYSPONGE_INIT_ROUNDS       = 12-1;
localparam                      DRYSPONGE_KEYSIZE           = 16;
localparam                      DRYSPONGE_CAPACITYSIZE64    = 5;
localparam                      D_WIDTH                     = 10;


// Design/derived parameters
localparam                      NW              = DRYSPONGE_CAPACITYSIZE64;
localparam                      WIDTH_KEY       = SIZE_KEY;
localparam                      WIDTH_DATA      = SIZE_DATA;
localparam                      WORD_KEY        = SIZE_KEY/CCSW;
localparam                      WORD_NPUB       = SIZE_NPUB/CCW;
localparam                      WORD_DATA       = SIZE_DATA/CCW;
localparam                      ROUNDS_MIX      = (SIZE_DATA+4+D_WIDTH)/D_WIDTH;


assign bdo_valid = 0;


// ========= Main
localparam                      WIDTH_C                     = 64*NW;
localparam                      WIDTH_X                     = 128;
localparam                      WIDTH_STATE                 = 3;
localparam                      S_INIT                      = 0;
// localparam                      S_KS_INIT                   = 1;
localparam                      S_KS                        = 2;
localparam                      S_MIX                       = 3;
localparam                      S_GASCON                    = 4;
// localparam                      S_LOAD                      = 3;
localparam                      S_PROCESS                   = 5;

reg         [WIDTH_C    -1:0]   cc;
reg         [WIDTH_X    -1:0]   xx;
reg         [256        -1:0]   rr;

reg         [WIDTH_STATE-1:0]   state;
reg         [WIDTH_STATE-1:0]   nstate;
reg         [4          -1:0]   rnd;
wire        [4          -1:0]   rnd_gascon;
reg         [4          -1:0]   cnt;
reg                             ena_cnt;
reg                             ena_rnd;
reg                             rst_cnt;
reg                             rst_rnd;
reg                             rst_r;
reg                             ena_c;
reg                             ena_x;
reg                             ena_r;
// reg                             sel_g;
reg         [2          -1:0]   sel_c;
reg                             sel_x;
reg                             do_mix;



// ========= Input 
localparam                      S_DI_INIT   = 0;
localparam                      S_DI_KEYCHK = 1;
localparam                      S_DI_LDKEY  = 2;
localparam                      S_DI_LD     = 3;
localparam                      S_DI_WAIT   = 4;
localparam                      HDR_AD      = 3'b001;
localparam                      HDR_PT      = 3'b010;
localparam                      HDR_NPUB    = 3'b110;

reg         [4          -1:0]   st_di;
reg         [4          -1:0]   nst_di;

reg         [WIDTH_KEY  -1:0]   r_key;
reg         [WIDTH_DATA -1:0]   r_data;
reg         [3          -1:0]   r_bdi_type;
reg                             r_bdi_eot;
reg                             r_bdi_eoi;

reg         [4          -1:0]   cnt_di;

reg                             rst_cnt_di;
reg                             ena_cnt_di;
reg                             ena_key;
reg                             ena_data;

reg                             key_rdy;
reg                             bdi_rdy;
wire                            data_rdy;
reg                             data_vld;
wire        [WIDTH_C    -1:0]   gascon_in;
wire        [WIDTH_C    -1:0]   gascon_out;
wire        [WIDTH_C    -1:0]   mix_out;
wire        [256        -1:0]   accu_out;



`ifdef SIMULATION
// -------------------------------------------------------------------
// ==== Debug signals
// -------------------------------------------------------------------

wire        [64         -1:0]   dbg_cc[0:NW-1];
wire        [64         -1:0]   dbg_mixout[0:NW-1];
wire        [64         -1:0]   dbg_gasconi[0:NW-1];
wire        [64         -1:0]   dbg_gascono[0:NW-1];
wire        [64         -1:0]   dbg_rr[0:NW-2];

genvar i;
generate 
    for (i=0; i<NW; i=i+1) begin: g_dbg_cc
        assign dbg_cc[i] = cc[WIDTH_C-i*64-1 -: 64];
    end
    for (i=0; i<NW; i=i+1) begin: g_dbg_gascon
        assign dbg_gascono[i] = gascon_out[WIDTH_C-i*64-1 -: 64];
        assign dbg_gasconi[i] = gascon_in[WIDTH_C-i*64-1 -: 64];
        assign dbg_mixout[i] = mix_out[WIDTH_C-i*64-1 -: 64];
    end
    for (i=0; i<4; i=i+1) begin: g_dbg_rr
        assign dbg_rr[i] = rr[256-i*64-1 -: 64];
    end
endgenerate
`endif

// -------------------------------------------------------------------
// ==== Datapath
// -------------------------------------------------------------------

wire                                pad;
wire                                final_domain;
reg         [2              -1:0]   domain;
wire        [4              -1:0]   dsinfo;
wire        [WIDTH_DATA+4   -1:0]   ds_data;
reg         [D_WIDTH        -1:0]   dd;

assign pad = 0;
assign final_domain = r_bdi_eoi;
assign dsinfo = {pad, final_domain, domain};
assign gascon_in = (do_mix) ? mix_out : cc;


`include "utils.vh"
assign ds_data = {dsinfo, swap_endian128(r_data)};

integer ii;
always @(*) begin         // dd mux
    case (rnd)
        0      : dd <= ds_data[0*D_WIDTH +: D_WIDTH];
        1      : dd <= ds_data[1*D_WIDTH +: D_WIDTH];
        2      : dd <= ds_data[2*D_WIDTH +: D_WIDTH];
        3      : dd <= ds_data[3*D_WIDTH +: D_WIDTH];
        4      : dd <= ds_data[4*D_WIDTH +: D_WIDTH];
        5      : dd <= ds_data[5*D_WIDTH +: D_WIDTH];
        6      : dd <= ds_data[6*D_WIDTH +: D_WIDTH];
        7      : dd <= ds_data[7*D_WIDTH +: D_WIDTH];
        8      : dd <= ds_data[8*D_WIDTH +: D_WIDTH];
        9      : dd <= ds_data[9*D_WIDTH +: D_WIDTH];
        10     : dd <= ds_data[10*D_WIDTH +: D_WIDTH];
        11     : dd <= ds_data[11*D_WIDTH +: D_WIDTH];
        12     : dd <= ds_data[12*D_WIDTH +: D_WIDTH];
        default: dd <= {8*{1'b0},
                        ds_data[WIDTH_DATA+2 +: 2]} ;
    endcase
end

always @(*) begin     // DOMAIN
    case(r_bdi_type)
        // HDR_HASH: domain <= 1;
        HDR_NPUB: domain <= 2;
        HDR_AD  : domain <= 2;
        default:  domain <= 3;
    endcase
end

assign rnd_gascon = (do_mix) ? 0 : rnd;

gascon_round u_gascon_round(.out(gascon_out), .din(gascon_in), .round(rnd_gascon));
mixsx32v2    u_mix32(.out(mix_out), .c(cc), .x(xx), .d(dd));
accumulate   u_accumulate(.out(accu_out), .din(cc[0+:256]), .r(rr));




// -------------------------------------------------------------------
// ==== Control
// -------------------------------------------------------------------
reg         [4              -1:0]   r_gascon_rounds;

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
        case (sel_c)
            0: cc <= gascon_out;
            1: cc <= mix_out;
            3: cc <= {r_key[WIDTH_KEY-DRYSPONGE_KEYSIZE*8 +: DRYSPONGE_KEYSIZE*8], 
                      r_key[WIDTH_KEY-DRYSPONGE_KEYSIZE*8 +: DRYSPONGE_KEYSIZE*8], 
                      r_key[WIDTH_KEY-64 +: 64]};
            default: cc <= 0;   // unused -- placeholder
        endcase
    end

    if (rst_r)
        rr <= 0;
    else if (ena_r)
        rr <= accu_out;    

    if (ena_x) begin        
        case (sel_x)
            0: xx <= 0;
            1: xx <= r_key[WIDTH_KEY-DRYSPONGE_KEYSIZE*8-WIDTH_X +: WIDTH_X];
        endcase
    end

    if (state == S_MIX)
        r_gascon_rounds <= (do_mix && (r_bdi_type == HDR_NPUB)) ? DRYSPONGE_INIT_ROUNDS : DRYSPONGE_ROUNDS; 
end

// FSM Core

always @(*)
begin
    nstate  <= state;
    rst_rnd <= 0;
    ena_rnd <= 0;

    ena_cnt <= 0;
    rst_cnt <= 0;

    ena_r   <= 0;
    rst_r   <= 0;

    ena_c   <= 0;
    ena_x   <= 0;
    sel_c   <= 0;
    // sel_g   <= 0;
    sel_x    <= 0;
    data_vld <= 0;
    do_mix   <= 0;
    // do_gascon <= 0;
    
    case(state)
    S_INIT: begin       // Initialization
        rst_rnd <= 1;
        rst_r   <= 1;
        if (data_rdy) 
            nstate  <= S_KS;
    end

    S_KS: begin 
        ena_c  <= 1;
        sel_c  <= 3;
        // sel_g  <= 1;

        ena_x <= 1;
        sel_x <= 1;
        nstate <= S_MIX;
    end

    S_MIX: begin
        do_mix <= 1;
        if (data_rdy) begin
            ena_c <= 1;
            if (rnd < ROUNDS_MIX-1) begin
                ena_rnd <= 1;
            end else begin
                sel_c   <= 1;
                rst_rnd <= 1;                
                nstate  <= S_GASCON;
            end
        end
    end

    S_GASCON: begin        
        // do_gascon <= 1;
        ena_c <= 1;
        ena_r <= 1;
        if (rnd < r_gascon_rounds-1) begin
            ena_rnd <= 1;
        end else begin
            rst_rnd <= 1;
            nstate  <= S_PROCESS;
        end
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
assign data_rdy = (st_di == S_DI_WAIT) ? 1:0;

always @(posedge clk) begin
    if (rst_cnt_di)
        cnt_di <= 0;
    else if (ena_cnt_di)
        cnt_di <= cnt_di + 1;

    if (ena_data) begin
        r_data <= {r_data[WIDTH_DATA-CCW-1:0], bdi};
        r_bdi_type <= bdi_type[3:1];
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

always @ (*)
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
            if ((bdi_type[3:1] == HDR_NPUB) && 
                (cnt_di == WORD_NPUB-1)) 
            begin
                rst_cnt_di <= 1;
                nst_di <= S_DI_WAIT;
            end else if ((bdi_type[3:1] == HDR_PT) && 
                         (cnt_di == WORD_DATA-1))
            begin
                rst_cnt_di <= 1;
                nst_di <= S_DI_WAIT;                
            end
        end
    end

    S_DI_WAIT: begin
        if (data_vld) begin
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