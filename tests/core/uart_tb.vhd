-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- uart_tb.vhd is a part of Innervator.
-- --------------------------------------------------------------------

-- NOTE: The project really lacks testbenches, even though it works.


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
 
library config;
    use config.constants.all;
 
entity uart_tb is
end uart_tb;
 
architecture simulation of uart_tb is
    constant TEST_BYTE  : std_logic_vector (7 downto 0) := X"41";
    
    signal clock     : std_ulogic  := '0';
    signal serial_in : std_logic := '1';
    signal is_done   : std_ulogic := '0';
    signal data_read : std_logic_vector (7 downto 0) :=
        (others => '0');
    signal led : std_logic_vector (3 downto 0) := (others => '0');
    -- Modified from nandland.com
    procedure send_byte_to_fpga(
               i_byte   : in  std_logic_vector (7 downto 0);
        signal o_serial : out std_logic
    ) is
    begin
        -- Start Bit
        o_serial <= '0';
        wait for c_BIT_PERD;
        
        -- Data Byte
        for i in 0 to 7 loop
            o_serial <= i_byte(i);
            wait for c_BIT_PERD;
        end loop;
        
        -- Stop Bit
        o_serial <= '1';
        wait for c_BIT_PERD;
    end send_byte_to_fpga; 

begin
 
    -- Instantiate UART Receiver     
    dut : configuration work.uart_xcvr
        generic map (c_CLK_FREQ, c_BIT_RATE)
        port map (
            i_clk       => clock,
            i_rst       => '-',
            
            i_rx_serial => serial_in,
            o_rx_done   => is_done,
            o_rx_byte   => data_read,
            
            i_tx_send   => '-',
            i_tx_byte   => (others => '-'),
            o_tx_active => open,
            o_tx_done   => open,
            o_tx_serial => open
        );

    clock <= not clock after c_CLK_PERD;
   
    process begin
        -- Send a command to the UART
        wait until rising_edge(clock);
        send_byte_to_fpga(TEST_BYTE, serial_in);
        wait until rising_edge(clock);
        
        --assert false report "Finished Sending" severity failure;
    end process;
    

    process (clock) begin
        if rising_edge(clock) then
        
            if (is_done = '1') then 
        
                if (data_read = X"41") then
                    led(3) <= '1';
                    led(1) <= '1';
                elsif (data_read = X"62") then
                    led(3) <= '0';
                    led(1) <= '0';
                end if;
                
            end if;
            
        end if;
    end process;

/*
    process (clock) begin
        if rising_edge(clock) then
        
            if (is_done = '1') then 
                --assert
        
                if (data_read = TEST_BYTE) then
                    --assert
                end if;
    
            end if;
            
        end if;
    end process;
*/

end simulation;


-- --------------------------------------------------------------------
-- END OF FILE: uart_tb.vhd
-- --------------------------------------------------------------------
