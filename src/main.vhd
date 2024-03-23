-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- 
-- Innervator: Hardware Acceleration for Artificial
--     Neural Networks in FPGA using VHDL.
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
-- --------------------------------------------------------------------

-- TODO: move inside config?
library utils;
    package network_parser is new utils.file_parser
        generic map (
            g_NETWORK_DIR => "C:/Users/Thrae/Desktop/Innervator/" & "data"
        );
        
    use work.network_parser.all;


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.fixed_pkg_for_neural.all, work.neural_typedefs.all;
    use work.network_params.all;
    use work.constants.all;
    
library core;

library neural;


entity network is
    port (
        g_mClk100Mhz: in std_ulogic;
        uart_txd_in : in std_logic;
        led: out std_logic_vector (3 downto 0)
    );
end network;
    
architecture test of network is 
	--signal clk_target: std_ulogic := '0';
	signal result: neural_bit;
    --constant test_value : neural_bit := to_ufixed(0.5, neural_bit'high, neural_bit'low);
	
	
	--constant TEST_WEIGHTS : neural_array := ("00100111","10001110");
	--constant TEST_BIAS : neural_word := "00010011";
	--signal TEST_DATA    : neural_array (0 to 1) := ("00000110","00000100");
	
	constant TEST_WEIGHTS : neural_array := ("00000111","00001110","00010000","00010011","00011001","00011010","00010101","00010000","11110101","11110011","00000000","00010000","00000010","11111001","00000011","11111011","00001101","11110010","00000100","00001000","11110111","11011101","11101100","00000010","11111101","00001111","00000100","00000000","11111000","00000011","11110010","00001100","11111101","11111001","00000111","00000100","00000010","00000001","00000011","00010000","11111101","11110100","11110010","11111111","11110000","00001101","00000110","00000101","00001010","11110101","00000001","00011001","00000000","11110010","00000100","00000100","11111101","11110010","00010100","00010011","11111000","11110011","00000101","00000100");
    constant TEST_BIAS : neural_word := "00110011";
	signal TEST_DATA    : neural_array (0 to 63) := ("00000110","00000000","00000010","00001100","00001011","00001100","00001000","00000011","00000101","00000100","00000000","00001100","00000010","00001100","00000011","00000101","00000110","00000100","00000101","00001100","00001111","00000100","00000011","00000101","00000100","00001110","00001011","00001001","00000100","00001110","00000101","00001010","00001100","00000010","00001101","00000010","00001111","00000010","00001100","00001110","00001001","00001000","00001110","00000000","00000110","00001011","00001100","00001101","00001001","00000101","00000011","00000010","00001100","00000110","00001110","00000111","00001011","00001111","00001010","00001111","00000100","00001100","00001101","00001101");
    attribute dont_touch : string;
    attribute keep_hierarchy : string;
    attribute keep : string;
    attribute mark_debug : string;

    --attribute dont_touch of TEST_WEIGHTS : constant is "true";
    --attribute dont_touch of TEST_BIAS : constant is "true";	
    attribute dont_touch of TEST_DATA : signal is "true";	
    --attribute keep_hierarchy of TEST_DATA : signal is "yes";
    --attribute keep of TEST_DATA : signal is "true";
    
    
    --attribute mark_debug of result : signal is "true";	
    
    
    
    
    constant NETWORK_OBJECT : constr_params_arr_t := parse_network_from_dir(DAT_PATH);
    --attribute dont_touch of test_result : constant is "true";	
    
    --assert false report natural'image(num_layers) severity failure;
    --assert false report "Rows: " & natural'image(test_dims(0).rows) severity failure;
    --assert false report "Cols: " & natural'image(test_dims(0).cols) severity failure;
    --assert false report real'image(to_real(weight_mat(1)(63))) severity failure;
    
    

    
    signal is_done : std_ulogic := '0';
    signal data_read : std_logic_vector (7 downto 0);
    
    
begin
    --led(0) <= '1';


    assert false report real'image(to_real(NETWORK_OBJECT(1).weights(3)(5))) severity failure;



    rx_serial : entity core.uart (receiver)
        generic map (CLK_FREQ, BIT_RATE)
        port map (g_mClk100Mhz, uart_txd_in, is_done, data_read);




    led(3) <= '0';
    led(1) <= '0';


    process (g_mClk100Mhz) begin
        if rising_edge(g_mClk100Mhz) then
        
            if (is_done = '1') then 
        
                if (data_read = X"41") then
                    led(3) <= '1';
                    led(1) <= '1';
                end if;
    
            end if;
            
        end if;
    end process;











/*
    testing : entity neural.neuron
        generic map (TEST_WEIGHTS, TEST_BIAS)
        port map (TEST_DATA, result);

    
    
    led(1) <= '1' when result <= 0.5 else '0';

    process (g_mClk100Mhz) begin
        if rising_edge(g_mClk100Mhz) then
        
            if (result >= 0.5) then
                led(3) <= '1';
            end if;
    
        end if;
    end process;
*/
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
   
   
/*
    process (g_mClk100Mhz) begin
        if rising_edge(g_mClk100Mhz) then

        

        end if;
    end process;
*/



/*
process
  variable currentLayer : layer_parameters;
begin
  for i in LayerIds'range loop
    case LayerIds(i) is
      when Layer1 =>
        currentLayer := LAYER_1;
      when Layer2 =>
        currentLayer := LAYER_2;
      when others =>
        null;  -- Add more cases as needed
    end case;

    -- Now you can use currentLayer.weights in your calculations
  end loop;
end process;
*/
    


/*
    prescaler : entity work.srl_prescaler
        generic map (100e6, 1e5)
        port map (g_mClk100Mhz, CLK_1Hz);
   
    led(0) <= CLK_1Hz;

    clock_counter : entity work.naive_counter
        port map (g_mClk100Mhz, clk_target);
	
	led(2) <= clk_target;
*/

end test;