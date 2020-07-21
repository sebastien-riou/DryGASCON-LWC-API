--! Wrapper module for verilog core

library ieee;
use ieee.std_logic_1164.all;
use work.design_pkg.all;

entity CryptoCore is
    Port (
        clk             : in   STD_LOGIC;
        rst             : in   STD_LOGIC;
        --PreProcessor===============================================
        ----!key----------------------------------------------------
        key             : in   STD_LOGIC_VECTOR (CCSW     -1 downto 0);
        key_valid       : in   STD_LOGIC;
        key_ready       : out  STD_LOGIC;
        ----!Data----------------------------------------------------
        bdi             : in   STD_LOGIC_VECTOR (CCW     -1 downto 0);
        bdi_valid       : in   STD_LOGIC;
        bdi_ready       : out  STD_LOGIC;
        bdi_pad_loc     : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_valid_bytes : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
        bdi_eot         : in   STD_LOGIC;
        bdi_eoi         : in   STD_LOGIC;
        bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
        decrypt_in      : in   STD_LOGIC;
        key_update      : in   STD_LOGIC;
        hash_in         : in   std_logic;
        --!Post Processor=========================================
        bdo             : out  STD_LOGIC_VECTOR (CCW      -1 downto 0);
        bdo_valid       : out  STD_LOGIC;
        bdo_ready       : in   STD_LOGIC;
        bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
        bdo_valid_bytes : out  STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        end_of_block    : out  STD_LOGIC;
        msg_auth_valid  : out  STD_LOGIC;
        msg_auth_ready  : in   STD_LOGIC;
        msg_auth        : out  STD_LOGIC
    );
end CryptoCore;

architecture behavioral of CryptoCore is

    component gascon256
        generic (
            CCW             : integer := 32;
            CCWdiv8         : integer := 8;
            CCSW            : integer := 32
        );
        port (
            clk             : in   STD_LOGIC;
            rst             : in   STD_LOGIC;
            --PreProcessor===============================================
            ----!key----------------------------------------------------
            key             : in   STD_LOGIC_VECTOR (CCSW     -1 downto 0);
            key_valid       : in   STD_LOGIC;
            key_ready       : out  STD_LOGIC;
            ----!Data----------------------------------------------------
            bdi             : in   STD_LOGIC_VECTOR (CCW     -1 downto 0);
            bdi_valid       : in   STD_LOGIC;
            bdi_ready       : out  STD_LOGIC;
            bdi_pad_loc     : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
            bdi_valid_bytes : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
            bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
            bdi_eot         : in   STD_LOGIC;
            bdi_eoi         : in   STD_LOGIC;
            bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
            decrypt_in      : in   STD_LOGIC;
            key_update      : in   STD_LOGIC;
            hash_in         : in   std_logic;
            --!Post Processor=========================================
            bdo             : out  STD_LOGIC_VECTOR (CCW      -1 downto 0);
            bdo_valid       : out  STD_LOGIC;
            bdo_ready       : in   STD_LOGIC;
            bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
            bdo_valid_bytes : out  STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
            end_of_block    : out  STD_LOGIC;
            msg_auth_valid  : out  STD_LOGIC;
            msg_auth_ready  : in   STD_LOGIC;
            msg_auth        : out  STD_LOGIC
        );
    end component gascon256;

begin

    u_core: gascon256
    generic map (
        CCW             => CCW      ,
        CCWdiv8         => CCWdiv8  ,
        CCSW            => CCSW
    )
    port map (
        clk             => clk              ,
        rst             => rst              ,
        key             => key              ,
        key_valid       => key_valid        ,
        key_ready       => key_ready        ,
        bdi             => bdi              ,
        bdi_valid       => bdi_valid        ,
        bdi_ready       => bdi_ready        ,
        bdi_pad_loc     => bdi_pad_loc      ,
        bdi_valid_bytes => bdi_valid_bytes  ,
        bdi_size        => bdi_size         ,
        bdi_eot         => bdi_eot          ,
        bdi_eoi         => bdi_eoi          ,
        bdi_type        => bdi_type         ,
        decrypt_in      => decrypt_in       ,
        hash_in              => hash_in          ,
        key_update      => key_update       ,
        bdo             => bdo              ,
        bdo_valid       => bdo_valid        ,
        bdo_ready       => bdo_ready        ,
        bdo_type        => bdo_type         ,
        bdo_valid_bytes => bdo_valid_bytes  ,
        end_of_block    => end_of_block     ,
        msg_auth_valid  => msg_auth_valid   ,
        msg_auth_ready  => msg_auth_ready   ,
        msg_auth        => msg_auth        
    );

end architecture behavioral;