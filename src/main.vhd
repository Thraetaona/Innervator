-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- 
-- Innervator: Hardware Acceleration for Artificial
--     Neural Networks in FPGAs using VHDL.
-- 
-- Copyright (C) 2024  Fereydoun Memarzanjany
-- 
-- This hardware-descriptive model is free hardware design dual-
-- licensed under the GNU LGPL or CERN OHL v2 Weakly Reciprocal: you
-- can redistribute it and/or modify it under the terms of the...
--     * GNU Lesser General Public License as published by
--       the Free Software Foundation, either version 3 of the License,
--       or (at your option) any later version; OR
--     * CERN Open Hardware Licence Version 2 - Weakly Reciprocal.
-- 
-- This is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
-- 
-- You should have received a copy of the GNU Lesser General
-- Public License and the CERN Open Hardware Licence Version
-- 2 - Weakly Reciprocal along with this.  If not, see...
--     * <https://spdx.org/licenses/LGPL-3.0-or-later.html>; and
--     * <https://spdx.org/licenses/CERN-OHL-W-2.0.html>.
-- 
-- ---------------------------------------------------------------------


-- NOTE: All of the source files herein conform to the RFC 678
-- plaintext document standard, as well as the Ada 95 Quality and
-- Style Guide 2.1.9 (Source Code Line Length); it is good readability
-- practice to limit a line of code's columns to 72 characters (which
-- include only the printable characters, not line endings or cursors).
--     I specifically chose 72 (and not some other limit like 80/132)
-- to ensure maximal compatibility with older technology, terminals,
-- paper hardcopies, and e-mails.  While some other guidelines permit
-- more than just 72 characters, it is still important to note that
-- American teletypewriters could sometimes write upto only 72.
--     Even in modern times, the 72 limit can still be beneficial:
-- you can easily quote a 72-character line over e-mail without
-- requiring word-wrapping or horizontal scrolling.
--     As a sidenote, the reason that some guidelines, like PEP 8
-- (Style Guide for Python Code), recommended 79 characters (i.e.,
-- not 80) was that the 80th character in a 80x24 terminal might
-- have been a bit hard to read.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.constants.all;
    
library core;

library neural;  
    context neural.neural_context;
    use     neural.file_parser.all;


    

    
entity neural_processor is
    port (
        g_mClk100Mhz : in std_ulogic;
        uart_txd_in  : in std_logic;
        uart_rxd_out : out std_logic;
        ck_rst       : in std_ulogic;
        led: out std_logic_vector (3 downto 0)
    );
begin
end entity neural_processor;
    
architecture structural of neural_processor is 
    constant NETWORK_OBJECT : network_layers :=
        parse_network_from_dir(c_DAT_PATH);
        
    constant NUM_LAYERS  : positive :=
        2;
    -- Number of neurons in the first (i.e., input) layer.
    constant NUM_INPUTS  : positive :=
        64;
    -- Number of neurons in the last (i.e., output) layer.
    constant NUM_OUTPUTS : positive :=
        10;



	--signal clk_target: std_ulogic := '0';
	signal result: neural_bit;
    --constant test_value : neural_bit := to_ufixed(0.5, neural_bit'high, neural_bit'low);
	
	
	--constant TEST_WEIGHTS : neural_vector := ("00100111","10001110");
	--constant TEST_BIAS : neural_word := "00010011";
	signal TEST_DATA2    : neural_bvector (0 to 1) := ("01100000","01000000");
	
	constant TEST_WEIGHTS2 : neural_wmatrix := (("10100111","10001110"),("00100111","10001110"));
	constant TEST_BIAS2 : neural_wvector := ("00011011","00010011");
    signal result2: neural_bvector (0 to 1);
	
	constant TEST_WEIGHTS : neural_vector := ("00000111","00001110","00010000","00010011","00011001","00011010","00010101","00010000","11110101","11110011","00000000","00010000","00000010","11111001","00000011","11111011","00001101","11110010","00000100","00001000","11110111","11011101","11101100","00000010","11111101","00001111","00000100","00000000","11111000","00000011","11110010","00001100","11111101","11111001","00000111","00000100","00000010","00000001","00000011","00010000","11111101","11110100","11110010","11111111","11110000","00001101","00000110","00000101","00001010","11110101","00000001","00011001","00000000","11110010","00000100","00000100","11111101","11110010","00010100","00010011","11111000","11110011","00000101","00000100");
    constant TEST_BIAS : neural_word := "00110011";

    -- digit 9
    signal TEST_DATA    : neural_bvector (0 to 63) := ("00000000","00000000","01110111","11111111","10011010","10001001","00100010","00000000","00000000","01010101","11111111","11101111","11111111","11111111","01000100","00000000","00000000","10001001","11101111","00000000","01100110","11111111","01000100","00000000","00000000","00010001","11111111","11111111","11111111","11111111","01100110","00000000","00000000","00000000","00000000","01000100","01000100","11011110","10001001","00000000","00000000","00000000","00000000","00000000","00000000","11011110","10001001","00000000","00000000","00000000","11001101","10011010","10111100","11111111","01110111","00000000","00000000","00000000","01110111","11111111","11101111","01110111","00000000","00000000");
    -- digit 3
    --signal TEST_DATA    : neural_bvector (0 to 63) := ("00000000","00000000","10101011","11111111","11111111","10111100","01000100","00000000","00000000","00010001","10101011","01010101","01110111","11111111","10101011","00000000","00000000","00000000","00000000","00010001","11101111","11101111","00000000","00000000","00000000","00000000","00000000","10111100","11011110","00000000","00000000","00000000","00000000","00000000","00000000","01010101","11111111","01010101","00000000","00000000","00000000","00000000","00000000","00010001","10101011","11101111","00000000","00000000","00000000","00000000","00000000","00100010","01110111","11111111","00110011","00000000","00000000","00000000","01100110","10111100","11111111","10001001","00000000","00000000");
    
    
    attribute dont_touch : string;
    attribute keep_hierarchy : string;
    attribute keep : string;
    attribute mark_debug : string;

    --attribute dont_touch of TEST_WEIGHTS : constant is "true";
    --attribute dont_touch of TEST_BIAS : constant is "true";	
    attribute keep of TEST_DATA : signal is "true";
    attribute keep of TEST_DATA2 : signal is "true";	
    --attribute keep_hierarchy of TEST_DATA : signal is "yes";
    --attribute keep of TEST_DATA : signal is "true";
    
    
    --attribute mark_debug of result : signal is "true";	
    
    
    
    
    

    
    signal byte_read_done  : std_ulogic := '0';
    signal byte_read_value : std_logic_vector (7 downto 0) := (others => '0');

    signal not_rst : std_ulogic := '0';
    
    procedure register_signal is new core.pipeliner.registrar
        generic map (2, std_ulogic);
        --generic map (2, std_logic_vector (7 downto 0));
        
    --procedure single_procedure is new core.pipeliner.delay_single
    --    generic map (3, std_logic_vector (7 downto 0));
        
    signal reg_ck_rst : std_ulogic := '0';
    
    
    signal in_rst  : std_logic_vector (7 downto 0);
    signal out_rst : std_logic_vector (7 downto 0);
    
    signal in_rst2  : std_logic_vector (7 downto 0);
    signal out_rst2 : std_logic_vector (7 downto 0);
    
    
    signal network_done : std_ulogic := '0';
    
    signal network_outputs     : neural_bvector (0 to NUM_OUTPUTS-1);
    -- TODO: Have an actual function to binary-encode decimals.
    signal network_prediction  : unsigned (3 downto 0); -- Arg-Max'ed
begin

    -- TODO: Assert here to check if the NETWORK_OBJECT is valid or not
    --assert false
        --report natural'image(NETWORK_OBJECT'element.weights'length)
            --severity failure;

/*
    testing : entity neural.neuron
        generic map (TEST_WEIGHTS, TEST_BIAS, 2)
        port map (TEST_DATA, result, g_mClk100Mhz, ck_rst, '1', neuron_done);
*/
    
/*
    test_layer : entity neural.layer (dense)
        generic map (TEST_WEIGHTS2, TEST_BIAS2)
        port map (TEST_DATA2, result2, g_mClk100Mhz, ck_rst, '1', neuron_done);
*/

-- TODO: Synchronize all input signals here and debounce the RST button
-- TODO: Invert the RST signal based on config.vhd, because Artix-7 can
-- work better with active-high resets (internally).
-- TODO: Investigate if the reset will have skew, in this case?
/*
    double_register : entity work.synchronizer
        generic map (NUM_CASCADES => 2) -- Double (2)
        port map (
            clk_in  => i_clk,
            sig_in  => i_rx_serial,
            sig_out => synced_serial
        );
*/


    uart_transceiver : configuration core.uart_xcvr
        generic map (
            g_CLK_FREQ => c_CLK_FREQ,
            g_BAUD     => c_BIT_RATE
        )
        port map (
            i_clk       => g_mClk100Mhz,
            i_rst       => ck_rst,
            -- The Receiver Component
            i_rx_serial => uart_txd_in,
            o_rx_done   => byte_read_done,
            o_rx_byte   => byte_read_value,
            -- TODO: Implement the UART Transmitter, too.
            i_tx_send   => 'Z',
            i_tx_byte   => (others => 'Z'),
            o_tx_active => open,
            o_tx_done   => open,
            o_tx_serial => open
        );


    neural_engine : entity neural.network
        generic map (
            g_NETWORK_PARAMS => NETWORK_OBJECT,
            g_BATCH_SIZE     => c_BATCH_SIZE
        )
        port map (
            i_inputs  => TEST_DATA,
            o_outputs => network_outputs,
            i_clk     => g_mClk100Mhz,
            i_rst     => ck_rst,
            i_fire    => '1',
            o_done    => network_done
        );


    -- NOTE: Unlike popular beliefs, subprograms (like functions)
    -- CAN be concurrently called outside of processes.
    network_prediction <= to_unsigned(
        neural.math.arg_max(network_outputs),
        network_prediction'length
    );
    
    -- TODO: Transfer the data back using the UART as opposed to LEDs
    -- and also check network_done first.
    led(3) <= network_prediction(3);
    led(2) <= network_prediction(2);
    led(1) <= network_prediction(1);
    led(0) <= network_prediction(0);
    
    
    
    
    --led(1) <= '1' when result <= 0.5 else '0';
/*
    process (g_mClk100Mhz) begin
        if rising_edge(g_mClk100Mhz) then
        
            if (network_done = '1') then 
            
                if (result >= 0.5) then
                    led(3) <= '1';
                elsif (result < 0.5) then
                    led(3) <= '0';
                end if;
    
            end if;
            
        end if;
    end process;



    process (g_mClk100Mhz) begin
        if rising_edge(g_mClk100Mhz) then
                
            if (is_done = '1') then 
                if (data_read = x"41") then
                    led(1) <= '1';
                elsif (data_read = x"62") then
                    led(1) <= '0';  
                end if;


            end if;
            
        end if;
    end process;
*/



/*
    in_rst(0) <= ck_rst;
    in_rst2(1) <= ck_rst;
    
    register_signal(
        g_mClk100Mhz,
        i_signal => ck_rst,
        o_signal => reg_ck_rst
    );
    
    --register_signal(
    --    g_mClk100Mhz,
    --    i_signal => in_rst2,
    --    o_signal => out_rst2
    --);
    
    process (g_mClk100Mhz) begin
        if rising_edge(g_mClk100Mhz) then
            
            
            
            if (reg_ck_rst = '1') then
                led(0) <= '1';
            elsif (reg_ck_rst = '0') then
                led(0) <= '0';
            end if;
        
        end if;
    end process;

*/




end architecture structural;


-- ---------------------------------------------------------------------
-- END OF FILE: main.vhd
-- ---------------------------------------------------------------------