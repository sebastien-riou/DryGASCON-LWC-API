`timescale 1ns / 1ps
`default_nettype none

module drygascon #(
    parameter                   CCW         = 32,
    parameter                   CCWdiv8     = 4 ,
    parameter                   CCSW        = 32
) (
    input wire                  clk             ,
    input wire                  rst             ,
    // --PreProcessor==============================================
    // ----!key----------------------------------------------------
    input  wire [CCSW   -1:0]   key             ,
    input  wire                 key_valid       ,
    output wire                 key_ready       ,
    // ----!Data---------------------------------------------------
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


localparam                      D_WIDTH                     = 10;
localparam                      DRYSPONGE_ROUNDS            = 8-1;
localparam                      DRYSPONGE_INIT_ROUNDS       = 12-1;
localparam                      DRYSPONGE_MPR_ROUNDS        = (SIZE_DATA+4+D_WIDTH)/D_WIDTH; // 14
localparam                      DRYSPONGE_KEYSIZE           = 16;
localparam                      DRYSPONGE_CAPACITYSIZE64    = 5;



// Design/derived parameters
localparam                      NW              = DRYSPONGE_CAPACITYSIZE64;
localparam                      WIDTH_KEY       = SIZE_KEY;
localparam                      WIDTH_DATA      = SIZE_DATA;
localparam                      WORD_KEY        = SIZE_KEY/CCSW;
localparam                      WORD_NPUB       = SIZE_NPUB/CCW;
localparam                      WORD_DATA       = SIZE_DATA/CCW;


// ========= Main
localparam                      WIDTH_C                 = 64*NW;
localparam                      WIDTH_X                 = 128;
localparam                      WIDTH_STATE             = 3;
localparam                      S_INIT                  = 0;
localparam                      S_KS                    = 1;
localparam                      S_MIX                   = 2;
localparam                      S_GASCON                = 3;
localparam                      S_TAG_OUT               = 4;
localparam                      S_WAIT_DATA             = 5;
localparam                      S_WAIT                  = 6;

reg         [WIDTH_C    -1:0]   cc;
reg         [WIDTH_X    -1:0]   xx;
reg         [256        -1:0]   rr;

reg         [WIDTH_STATE-1:0]   state;
reg         [WIDTH_STATE-1:0]   nstate;
reg         [4          -1:0]   rnd;
wire        [4          -1:0]   rnd_gascon;
reg                             ena_rnd;
reg                             rst_rnd;
reg                             rst_r;
reg                             ena_c;
reg                             ena_x;
reg                             ena_r;
// reg                             sel_g;
reg         [2          -1:0]   sel_c;
reg                             sel_x;
reg                             do_mix;
reg                             sel_tag;
reg                             sel_pad;

// ========= encoding
localparam                      HDR_AD          = 4'b0001;
localparam                      HDR_PT          = 4'b0100;
localparam                      HDR_CT          = 4'b0101;
localparam                      HDR_HASH_MSG    = 4'b0111;
localparam                      HDR_TAG         = 4'b1000;
localparam                      HDR_HASH_VALUE  = 4'b1001;
localparam                      HDR_KEY         = 4'b1100;
localparam                      HDR_NPUB        = 4'b1101;


// ========= Input
localparam                      S_DI_INIT       = 0;
localparam                      S_DI_KEYCHK     = 1;
localparam                      S_DI_LDKEY      = 2;
localparam                      S_DI_LD         = 3;
localparam                      S_DI_PAD_FULL   = 4;
localparam                      S_DI_PAD        = 5;
localparam                      S_DI_WAIT       = 6;


reg         [4          -1:0]   st_di;
reg         [4          -1:0]   nst_di;

reg         [WIDTH_KEY  -1:0]   r_key;
reg         [WIDTH_DATA -1:0]   r_data;
reg         [4          -1:0]   r_bdi_type;
reg                             r_bdi_eot;
reg                             r_bdi_eoi;
reg                             r_is_msg;
reg         [CCWdiv8    -1:0]   r_bdi_valid_bytes;
reg         [16         -1:0]   r_bdi_valid_bytes_all; // Number of valid bytes in a block
reg                             r_decrypt_in;
reg                             r_hash_in;
reg                             r_msg_decrypt;
reg                             r_msg_hash;

reg         [4          -1:0]   cnt_di;
reg                             rst_cnt_di;
reg                             ena_cnt_di;
reg                             bdi_rdy;
reg                             key_rdy;
reg                             ena_key;
reg                             ena_data;
wire                            data_rdy;
reg                             data_vld;

// ========= Output
localparam                      S_DO_WAIT       = 0;
localparam                      S_DO_OUT        = 1;
localparam                      S_DO_MSGAUTH    = 2;
reg         [2          -1:0]   st_do;
reg         [2          -1:0]   nst_do;

reg                             ena_dout;

// -------------------------------------------------------------------
// ==== Datapath
// -------------------------------------------------------------------
wire                                pad;
wire                                final_domain;
reg         [2              -1:0]   domain;
wire        [4              -1:0]   dsinfo;
wire        [WIDTH_DATA+4   -1:0]   ds_data; // {DSINFO, data}
wire        [WIDTH_DATA     -1:0]   data_sel;
wire        [WIDTH_DATA     -1:0]   dout;
reg         [D_WIDTH        -1:0]   dd;
wire        [WIDTH_C        -1:0]   gascon_in;
wire        [WIDTH_C        -1:0]   gascon_out;
wire        [WIDTH_C        -1:0]   mix_out;
wire        [256            -1:0]   accu_out;

assign pad = ~r_bdi_valid_bytes_all[0];
assign final_domain = r_bdi_eoi;
assign dsinfo = (r_bdi_eot) ? {domain, final_domain, pad} : 0;
assign gascon_in = (do_mix) ? mix_out : cc;


`include "utils.vh"
genvar i;

generate
    for (i=0; i<WIDTH_DATA/8; i=i+1) begin
        assign data_sel[WIDTH_DATA-(i+1)*8 +: 8] =
            (r_bdi_valid_bytes_all[WIDTH_DATA/8-i-1] & r_is_msg & r_decrypt_in) ?
              dout[WIDTH_DATA-(i+1)*8 +: 8] :
            r_data[WIDTH_DATA-(i+1)*8 +: 8];
    end
endgenerate

assign ds_data = {dsinfo, swap_endian128(data_sel)};

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
        HDR_NPUB: domain <= 1;
        HDR_HASH_MSG: domain <= 2;
        HDR_AD  : domain <= 2;
        default:  domain <= 3;
    endcase
end

assign rnd_gascon = (do_mix) ? 0 : rnd;

gascon_round u_gascon_round(.out(gascon_out), .din(gascon_in), .round(rnd_gascon));
mix32        u_mix32(.out(mix_out), .c(cc), .x(xx), .d(dd));
// accumulate
wire [128-1:0] accu_p1;
wire [128-1:0] accu_p2;
assign accu_p1 = gascon_out[WIDTH_C-WIDTH_DATA +: WIDTH_DATA];          // [0..3]
assign accu_p2 = {gascon_out[WIDTH_C-2*WIDTH_DATA +: WIDTH_DATA-32],    // ([4..7] <<< 32)
                  gascon_out[WIDTH_C-WIDTH_DATA-32 +: 32]};
assign accu_out = accu_p1 ^ accu_p2 ^ rr;
assign dout = r_data ^ rr;




// -------------------------------------------------------------------
// ==== Control
// -------------------------------------------------------------------
reg         [WIDTH_DATA     -1:0]   r_dout;
reg         [2              -1:0]   r_dout_words;
reg         [CCWdiv8        -1:0]   r_dout_bytes;
reg                                 r_dout_end;
reg         [4              -1:0]   r_gascon_rounds;
reg                                 r_msg_auth;
reg                                 data_end;
reg         [2              -1:0]   data_size;

reg                                 dout_vld;
reg                                 dout_rdy;
reg                                 flag_tag_check;
reg                                 r_flag_squeeze;


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
            2: cc <= {r_key[WIDTH_KEY-DRYSPONGE_KEYSIZE*8 +: DRYSPONGE_KEYSIZE*8],
                      r_key[WIDTH_KEY-DRYSPONGE_KEYSIZE*8 +: DRYSPONGE_KEYSIZE*8],
                      r_key[WIDTH_KEY-64 +: 64]};
            3: cc <= {{128'h243F6A8885A308D313198A2E03707344},
                      {128'h243F6A8885A308D313198A2E03707344},
                      { 64'h243F6A8885A308D3}};
            default: cc <= 0; // shouldn't be happening
        endcase
    end

    if (rst_r)
        rr <= 0;
    else if (ena_r)
        rr <= accu_out;

    if (ena_x) begin
        case (sel_x)
            0: xx <= r_key[WIDTH_KEY-DRYSPONGE_KEYSIZE*8-WIDTH_X +: WIDTH_X];
            1: xx <= {128'hA4093822299F31D0082EFA98EC4E6C89};
        endcase
    end

    if (data_vld) begin
        data_end  <= final_domain;
    end


    if (dout_vld && dout_rdy) begin
        r_dout       <= (sel_tag) ? rr : dout;
        r_dout_words <= (r_msg_hash | sel_tag) ? 3 : data_size;
        r_dout_bytes <= (sel_tag) ? {4'b1111} : r_bdi_valid_bytes;
        r_dout_end   <= (r_msg_hash) ?
                            r_flag_squeeze : (r_is_msg) ? r_bdi_eot : data_end;
    end else if (ena_dout) begin
        r_dout <= r_dout << CCW;
        r_dout_words <= r_dout_words - 1;
    end

    if (state == S_MIX)
        r_gascon_rounds <= (do_mix && (r_bdi_type == HDR_NPUB)) ? DRYSPONGE_INIT_ROUNDS : DRYSPONGE_ROUNDS;

    if (state == S_INIT) begin
        r_msg_decrypt   <= r_decrypt_in;
        r_msg_hash      <= r_hash_in;
    end

    if (flag_tag_check)
        r_msg_auth <= (rr == r_data) ? 1:0;

    if (state == S_INIT)
        r_flag_squeeze <= 0;
    else if ((state == S_TAG_OUT) & dout_vld)
        r_flag_squeeze <= 1;
end

// FSM Core

always @(*)
begin
    nstate  <= state;
    rst_rnd <= 0;
    ena_rnd <= 0;

    ena_r   <= 0;
    rst_r   <= 0;

    ena_c   <= 0;
    ena_x   <= 0;
    sel_c   <= 0;
    sel_x    <= 0;
    data_vld <= 0;
    do_mix   <= 0;
    dout_vld <= 0;
    flag_tag_check <= 0;

    // output
    sel_tag  <= 0;

    case(state)
    S_INIT: begin       // Initialization
        rst_rnd <= 1;
        rst_r   <= 1;
        if (data_rdy)
            nstate  <= S_KS;
    end

    S_KS: begin
        ena_c  <= 1;
        sel_c  <= (r_hash_in) ? 3:2;

        ena_x <= 1;
        sel_x <= (r_hash_in) ? 1:0;
        nstate <= S_MIX;
    end

    S_MIX: begin
        do_mix <= 1;
        if (data_rdy & (!r_is_msg | dout_rdy | (rnd != 0))) begin
            if (r_is_msg && (rnd == 0))
                dout_vld <= 1;
            ena_c <= 1;
            if (rnd < DRYSPONGE_MPR_ROUNDS-1) begin
                ena_rnd <= 1;
            end else begin
                data_vld <= 1;
                sel_c   <= 1;
                rst_rnd <= 1;
                rst_r   <= 1;
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
            if (data_end)
                nstate <= S_TAG_OUT;
            else if (data_rdy)
                nstate <= S_MIX;
            else
                nstate <= S_WAIT_DATA;
        end
    end

    S_TAG_OUT: begin
        sel_tag <= 1;
        if (r_msg_hash & dout_rdy) begin
            dout_vld <= 1;
            if (r_flag_squeeze) begin
                nstate <= S_INIT;
            end else begin
                rst_r  <= 1;
                nstate <= S_GASCON; // perform second squeeze
            end
        end else if (!r_msg_decrypt & dout_rdy) begin    // encrypt
            dout_vld    <= 1;
            nstate      <= S_INIT;
        end else if (r_msg_decrypt & data_rdy & dout_rdy) begin
            flag_tag_check <= 1;
            data_vld    <= 1;
            nstate      <= S_INIT;
        end
    end

    S_WAIT_DATA: begin
        if (data_rdy)
            nstate <= S_MIX;
    end

    default: begin  // S_WAIT

    end
    endcase
end // FSM Core

// -------------------------------------------------------------------
// FSM Input
// -------------------------------------------------------------------
reg                sel_full_pad;
wire [CCW    -1:0] bdi_pad;
wire [CCWdiv8-1:0] vbytes_sel;
wire [CCWdiv8-1:0] bdi_pad_loc_sel;

assign key_ready = key_rdy;
assign bdi_ready = bdi_rdy;
assign data_rdy = (st_di == S_DI_WAIT) ? 1:0;
assign vbytes_sel = (sel_pad) ? 0 : bdi_valid_bytes;
assign bdi_pad_loc_sel = (sel_pad) ? ((sel_full_pad) ? {4'b1000} : 0) : bdi_pad_loc;

// Input padding logic
generate
    for (i=0; i<CCWdiv8; i=i+1) begin
        assign bdi_pad[CCW-8*(i+1) +: 8] =
            bdi_pad_loc_sel[CCWdiv8-(i+1)] ? 1 :
            (bdi[CCW-8*(i+1) +: 8] & {8{vbytes_sel[CCWdiv8-(i+1)]}});
    end
endgenerate

always @(posedge clk) begin
    if (rst_cnt_di) begin
        cnt_di <= 0;
    end else if (ena_cnt_di) begin
        cnt_di <= cnt_di + 1;
    end

    if (ena_data) begin
        r_data   <= {r_data[WIDTH_DATA-CCW-1:0], bdi_pad};
        r_bdi_valid_bytes_all <= {r_bdi_valid_bytes_all[11:0], vbytes_sel};
        if (!sel_pad | (bdi_rdy & bdi_valid_bytes[3]))
            data_size <= cnt_di;
    end

    if (bdi_rdy)
        r_is_msg <= (bdi_type == HDR_PT || bdi_type == HDR_CT) ? 1:0;

    if (st_di == S_DI_LD && ena_data) begin
        r_bdi_type          <= bdi_type;
        r_bdi_eoi           <= bdi_eoi;
        r_bdi_eot           <= bdi_eot;
        r_bdi_valid_bytes   <= bdi_valid_bytes;
        r_decrypt_in        <= decrypt_in;
        r_hash_in           <= hash_in;
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
    sel_pad      <= 0;
    sel_full_pad <= 0;

    case (st_di)
    S_DI_INIT: begin       // Initialization
        rst_cnt_di <= 1;
        if ((bdi_valid || key_valid) && (st_do == S_DO_WAIT))
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
        if (bdi_valid) begin
            ena_data   <= 1;
            bdi_rdy    <= 1;
            if (cnt_di == WORD_DATA-1)
                nst_di <= S_DI_WAIT;
            else if (bdi_valid_bytes[0]) begin
                if (bdi_eot)
                    nst_di <= S_DI_PAD_FULL;
                ena_cnt_di <= 1;
            end else begin
                ena_cnt_di  <= 1;
                nst_di <= S_DI_PAD;
            end
        end
    end

    S_DI_PAD_FULL: begin
        sel_full_pad <= 1;
        sel_pad    <= 1;
        ena_cnt_di <= 1;
        ena_data   <= 1;
        if (cnt_di == WORD_DATA-1)
            nst_di <= S_DI_WAIT;
        else
            nst_di <= S_DI_PAD;
    end

    S_DI_PAD: begin
        sel_pad    <= 1;
        ena_cnt_di <= 1;
        ena_data   <= 1;
        if (cnt_di == WORD_DATA-1)
            nst_di <= S_DI_WAIT;
    end

    S_DI_WAIT: begin
        if (data_vld) begin
            rst_cnt_di <= 1;
            if ((r_bdi_eoi & !r_decrypt_in)
                || (r_bdi_type == HDR_TAG)
                || (r_bdi_eot & (r_bdi_type == HDR_HASH_MSG)))
                nst_di <= S_DI_INIT;
            else
                nst_di <= S_DI_LD;
        end
    end
    endcase
end

// -------------------------------------------------------------------
// FSM Output
// -------------------------------------------------------------------
reg  msg_auth_vld;
reg  bdo_vld;
wire last;

assign bdo             = r_dout[128-32 +: 32];
assign bdo_valid       = bdo_vld;
assign bdo_type        = "XXXX"; // not implemented. unused feature. See LWC implementer's guide.
assign bdo_valid_bytes = (r_dout_end && (r_dout_words == 0)) ? r_dout_bytes : {4'hF} ;
assign end_of_block    = last;
assign msg_auth_valid  = msg_auth_vld;
assign msg_auth        = r_msg_auth;
assign last            = (r_dout_end && (r_dout_words == 0)) ? 1:0;

always @(posedge clk) begin
    if (rst)
        st_do <= S_DO_WAIT;
    else
        st_do <= nst_do;
end

always @(*) begin
    nst_do <= st_do;
    dout_rdy <= 0;
    ena_dout <= 0;
    msg_auth_vld <= 0;
    bdo_vld  <= 0;

    case (st_do)
    S_DO_WAIT: begin
        dout_rdy <= 1;
        if (flag_tag_check)
            nst_do <= S_DO_MSGAUTH;
        else if (dout_vld)
            nst_do <= S_DO_OUT;
    end

    S_DO_OUT: begin
        bdo_vld <= 1;
        if (bdo_ready) begin
            ena_dout <= 1;
            if (r_dout_words == 0)
                nst_do <= S_DO_WAIT;
        end
    end

    S_DO_MSGAUTH: begin
        msg_auth_vld <= 1;
        if (msg_auth_ready)
            nst_do <= S_DO_WAIT;
    end
    endcase
end

`ifdef SIMULATION
// -------------------------------------------------------------------
// ==== Debug signals
// -------------------------------------------------------------------

wire        [64         -1:0]   dbg_cc[0:NW-1];
wire        [64         -1:0]   dbg_mixout[0:NW-1];
wire        [64         -1:0]   dbg_gasconi[0:NW-1];
wire        [64         -1:0]   dbg_gascono[0:NW-1];
wire        [32         -1:0]   dbg_rr[0:3];
wire        [32         -1:0]   dbg_data[0:3];
wire        [32         -1:0]   dbg_dout[0:3];
wire                            dbg_mix_done;
wire                            dbg_gascon_done;

assign dbg_mix_done = ((rnd == DRYSPONGE_MPR_ROUNDS-1) && (state == S_MIX)) ? 1:0;
assign dbg_gascon_done = ((rnd == r_gascon_rounds-1) && (state == S_GASCON)) ? 1:0;


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
        assign dbg_rr[i] = rr[128-i*32-1 -: 32];
        assign dbg_dout[i]  = r_dout[128-i*32-1 -: 32];
        assign dbg_data[i]  = r_data[128-i*32-1 -: 32];
    end
endgenerate
`endif


endmodule