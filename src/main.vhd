-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- 
-- Innervator: Hardware Acceleration for Neural Networks
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
-- American teletypewriters could sometimes write upto only 72, and
-- older code (e.g., FORTRAN, Ada, COBOL, Assembler, etc.) used to
-- be hand-written on a "code form" in corporations like IBM; said
-- code form typically reserved the first 72 columns for statements,
-- 8 for serial numbers, and the remainder for comments, which was
-- finally turned into a physical punch card with 80 columns.
--     Even in modern times, the 72 limit can still be beneficial:
-- you can easily quote a 72-character line over e-mail without
-- requiring word-wrapping or horizontal scrolling.
--     As a sidenote, the reason that some guidelines, like PEP 8
-- (Style Guide for Python Code), recommended 79 characters (i.e.,
-- not 80) was that the 80th character in a 80x24 terminal might
-- have been a bit hard to read.

-- Thanks to yet another arcane bug within Vivado 2024, in which it
-- completely breaks apart when you try to access attributes of this
-- constant within the same declaratory region (even though it is
-- perfectly valid VHDL and ModelSim also has no problems with it),
-- we have no choice but to declare it in a "separate" area:
library work;
    use work.constants.all;
library neural;  
    context neural.neural_context;
    use     neural.file_parser.all;
package attribute_bugfix is
    constant debug_NETWORK_OBJECT : network_layers :=
        parse_network_from_dir(c_DAT_PATH);
end package attribute_bugfix;


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
        i_clk  : in std_ulogic;
        i_rst  : in std_ulogic;
        i_uart : in std_logic;
        o_uart : out std_logic;
        o_led  : out std_logic_vector (3 downto 0)
    );
begin
end entity neural_processor;
    
architecture structural of neural_processor is
    alias NETWORK_OBJECT is work.attribute_bugfix.debug_NETWORK_OBJECT;

    -- Number of layers in network (excluding the input data themself)
    constant NUM_LAYERS  : positive :=
        NETWORK_OBJECT'length;
    -- Number of neurons in the first (i.e., input) layer
    constant NUM_INPUTS  : positive :=
        NETWORK_OBJECT(NETWORK_OBJECT'low).dims.cols;
    -- Number of neurons in the last (i.e., output) layer
    constant NUM_OUTPUTS : positive :=
        NETWORK_OBJECT(NETWORK_OBJECT'high).dims.rows;


    -- Synchronized/deglitched ports
    signal i_rst_synced    : std_ulogic;
    signal i_uart_synced   : std_ulogic;
    -- In case the reset button requires inverting
    signal i_rst_corrected : std_ulogic;
    -- Synchronized buttons
    signal i_rst_debounced : std_ulogic;

    
    /* UART signals */
    signal byte_read_done  : std_ulogic := '0';
    signal byte_read_value : std_logic_vector (7 downto 0) :=
        (others => '0');
    
    -- The input array that will be received via UART from a computer.
    signal input_data          : neural_bvector (0 to NUM_INPUTS-1) :=
        (others => (others => '0'));
    signal input_data_count    : natural range 0 to NUM_INPUTS := 0;
    signal input_data_received : std_ulogic := '0';

    -- UART Transmitter signals
    signal result_ready : std_ulogic;
    signal result_byte  : std_logic_vector (7 downto 0);

    signal network_done       : std_ulogic := '0';
    signal network_outputs    : neural_bvector (0 to NUM_OUTPUTS-1);
    -- TODO: Have an actual function to binary-encode decimals.
    signal network_prediction : unsigned (3 downto 0); -- Arg-Max'ed
begin
    -- TODO: Print network metadata here (though Vivado has assert bugs)
    --assert false
    --    report natural'image(NETWORK_OBJECT'element.weights'length)
    --        severity failure;

    /*
        Port Setup
    */
    
    -- Synchronize/deglitch the incoming data, allowing it to be used
    -- in our own clock domain, avoiding metastabiliy problems.
    synchronize_input_ports : block
    begin
        sync_reset   : entity core.synchronizer
            generic map (g_NUM_STAGES => c_SYNC_NUM)
            port map (
                i_clk    => i_clk,
                i_signal => i_rst,
                o_signal => i_rst_synced
            );
        sync_uart_in : entity core.synchronizer
            generic map (g_NUM_STAGES => c_SYNC_NUM)
            port map (
                i_clk    => i_clk,
                i_signal => i_uart,
                o_signal => i_uart_synced
            ); 
    end block synchronize_input_ports;

    -- Invert the reset button; even if the FPGA board has a negative
    -- reset, the FPGA might work "better" with positive resets,
    -- internally. (more info in config.vhd)
    -- TODO: Investigate if the reset will have skew, in this case
    invert_reset : if c_RST_INVT generate
        i_rst_corrected <= not i_rst_synced;
    else generate -- Else, don't invert
        i_rst_corrected <= i_rst_synced;
    end generate invert_reset;

    -- Remove the bouncing "noise" from input buttons
    debounce_buttons : block
    begin
        debounce_reset : entity core.debouncer
            generic map (g_TIMEOUT_MS => c_DBNC_LIM)
            port map (
                i_clk    => i_clk,
                i_button => i_rst_corrected,
                o_button => i_rst_debounced
            );
    end block debounce_buttons;
    


    /*
        Part Instantiations
    */

    uart_transceiver : configuration core.uart_xcvr
        generic map (
            g_CLK_FREQ => c_CLK_FREQ,
            g_BAUD     => c_BIT_RATE
        )
        port map (
            i_clk       => i_clk,
            i_rst       => i_rst_debounced,
            -- The Receiver Component
            i_rx_serial => i_uart_synced,
            o_rx_done   => byte_read_done,
            o_rx_byte   => byte_read_value,
            -- TODO: Implement the UART Transmitter, too.
            i_tx_send   => result_ready,
            i_tx_byte   => result_byte,
            o_tx_active => open, -- Unused
            o_tx_done   => open, -- Unused
            o_tx_serial => o_uart
        );


    -- TODO: Eventually, have the option to select between using LUTRAM
    -- (which is, confusingly, also known as DistRAM or DRAM) and BRAM,
    -- the dedicated---but single/dual channel---block ram on FPGAs.
    -- TODO: Also, maybe have this in a separate entity?
    receive_data : process (i_clk)
        procedure perform_reset is
        begin
            input_data          <= (others => (others => '0'));
            input_data_count    <= 0;
            input_data_received <= '0';
        end procedure perform_reset;
    begin
        if not c_RST_SYNC and i_rst_debounced = c_RST_POLE
            then perform_reset;
        elsif rising_edge(i_clk) then
            if c_RST_SYNC and i_rst_debounced = c_RST_POLE
                then perform_reset;
            else
                input_data_received <= '0';
                
                data_remain : if (input_data_count < NUM_INPUTS) then
                    byte_read : if (byte_read_done = '1') then 
                    
                        input_data(input_data_count) <=
                            to_ufixed(byte_read_value,
                                input_data'element'high,
                                input_data'element'low
                            );
                        
                        input_data_count <= input_data_count + 1;
                    end if byte_read;
                else -- All of the data got received
                    input_data_received <= '1';
                    input_data_count    <= 0;
                end if data_remain;
                
            end if;  
        end if;
    end process receive_data;


    neural_engine : entity neural.network
        generic map (
            g_NETWORK_PARAMS  => NETWORK_OBJECT,
            g_BATCH_SIZE      => c_BATCH_SIZE,
            g_PIPELINE_STAGES => c_PIPE_STAGE
        )
        port map (
            i_inputs  => input_data,
            o_outputs => network_outputs,
            i_clk     => i_clk,
            i_rst     => i_rst_debounced,
            i_fire    => input_data_received,
            o_done    => network_done
        );


    -- NOTE: Unlike popular beliefs, subprograms (like functions)
    -- CAN be concurrently called outside of processes.
    -- TODO: Pipeline and clock this later.
    network_prediction <= to_unsigned(
        neural.math.arg_max(network_outputs),
        network_prediction'length
    );
    
    -- TODO: Transfer the data back using the UART as opposed to LEDs
    -- and also check network_done first.
    o_led(3) <= network_prediction(3);
    o_led(2) <= network_prediction(2);
    o_led(1) <= network_prediction(1);
    o_led(0) <= network_prediction(0);
    /*
    transmit_result : process (i_clk)
        procedure perform_reset is
        begin
            
        end procedure perform_reset;
    begin
        if not c_RST_SYNC and i_rst_debounced = c_RST_POLE
            then perform_reset;
        elsif rising_edge(i_clk) then
            if c_RST_SYNC and i_rst_debounced = c_RST_POLE
                then perform_reset;
            else

            end if;  
        end if;
    end process transmit_result;
    */

end architecture structural;


-- ---------------------------------------------------------------------
-- END OF FILE: main.vhd
-- ---------------------------------------------------------------------