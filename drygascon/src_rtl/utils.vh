function [32-1:0] swap_endian32;
    input [32-1:0] a;

    integer i;
    for (i=0; i<32/8; i=i+1) begin
        swap_endian32[i*8 +: 8] = a[32-8*(i+1) +: 8];
    end
endfunction

function [63:0] swap_endian64;
    input [63:0] a;

    integer i;
    for (i=0; i<64/8; i=i+1) begin
        swap_endian64[i*8 +: 8] = a[64-8*(i+1) +: 8];
    end
endfunction

function [128-1:0] swap_endian128;
    input [128-1:0] a;

    integer i;
    for (i=0; i<128/8; i=i+1) begin
        swap_endian128[i*8 +: 8] = a[128-8*(i+1) +: 8];
    end
endfunction