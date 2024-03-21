-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- uart_tb.vhd is a part of Innervator.
-- --------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
 
library config;
    use config.constants.all;
 
entity uart_tb is
end uart_tb;
 
architecture simulation of uart_tb is
    constant BAUD       : integer  := 9_600;
    constant BIT_PERIOD : time     := 1 sec / BAUD;    
    
    signal clock     : std_ulogic  := '0';
    signal is_done   : std_ulogic;
    signal data_read : std_logic_vector (7 downto 0) := (others => '0');
    signal serial_in : std_logic := '1';
    
    -- Modified from nandland.com
    procedure send_byte_to_fpga(
               i_byte   : in  std_logic_vector (7 downto 0);
        signal o_serial : out std_logic
    ) is
    begin
        -- Start Bit
        o_serial <= '0';
        wait for BIT_PERIOD;
        
        -- Data Byte
        for i in 0 to 7 loop
            o_serial <= i_byte(i);
            wait for BIT_PERIOD;
        end loop;
        
        -- Stop Bit
        o_serial <= '1';
        wait for BIT_PERIOD;
    end send_byte_to_fpga; 
    
begin
 
    -- Instantiate UART Receiver
    dut : entity work.uart (receiver)
        generic map (CLK_FREQ, BAUD)
        port map (clock, serial_in, is_done, data_read);
    
    clock <= not clock after CLK_PERD;
   
    process begin
        -- Send a command to the UART
        wait until rising_edge(clock);
        send_byte_to_fpga(X"AB", serial_in);
        wait until rising_edge(clock);
        
        --assert false report "Send Finished" severity failure;
    end process;
end simulation;


-- --------------------------------------------------------------------
-- END OF FILE: uart_tb.vhd
-- --------------------------------------------------------------------