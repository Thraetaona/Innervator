-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- uart_xcvr.vhd is a part of Innervator.
-- --------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.uart_pkg.all;

library config;
    use config.constants.all;

-- A half- or full-duplex async. receiver/transmitter (in 8-N-1 frame)
architecture transceiver of uart is -- [Structural arch.]
begin

    receiver_component : component work.uart_pkg.uart_rcvr
        generic map (
            g_CLK_FREQ  => g_CLK_FREQ,
            g_BAUD      => g_BAUD
        )
        port map (
            i_clk       => i_clk,
            i_rst       => i_rst,
            
            i_serial    => i_rx_serial,
            o_done      => o_rx_done,
            o_byte      => o_rx_byte
        );
    
    transmitter_component : component work.uart_pkg.uart_xmtr
        generic map (
            g_CLK_FREQ  => g_CLK_FREQ,
            g_BAUD      => g_BAUD
        )
        port map (
            i_clk       => i_clk,
            i_rst       => i_rst,
            
            i_send      => i_tx_send,
            i_byte      => i_tx_byte,
            o_active    => o_tx_active,
            o_done      => o_tx_done,
            o_serial    => o_tx_serial
        );

    -- [Place for other concurrent statements]

end architecture transceiver;


library work;
    use work.all;

-- NOTE: 'configuration' in VHDL is a barely documented and arcane
-- keyword, and the excessive repetation of component/entity ports
-- might also be defeating its purpose.
--     From what I have gathered, components are "idealized"
-- _placeholders_ for future "realized" entities.  In an electronics
-- sense, they are chip sockets for upcoming chips; most of the time
-- they are not useful and merely add an unneeded layer of abstraction.
-- However, they could sometimes be useful for giving a hierarchical
-- organization to "sub-entities."
--     Additionally, components should be declared in an architecture's
-- header and correspond exactly (name- & port-wise) to their entities.
-- They will also require separate instantations in said architecture's
-- body (i.e., structural VHDL), often resulting in lots of duplicated
-- port assignments.
--     It is also possible to use configurations to "bind" a specific
-- instance (or even 'all' instances) of a component to a specific
-- entity-architecture pair or other sub-configurations.  Afterward,
-- you may even instatiate the configuration itself as you would do
-- so with an entity or component.
--
-- NOTE: Here, it is important to note that 'for' does NOT refer to
-- a for-loop and means a literal 'for' (i.e., FOR X, use Y).
--
-- NOTE: You cannot leave ports of type 'input' as 'open' but you can
-- assign 'U', 'X', 'Z', or '-' to them to achieve the same effect;
-- among these, '-' makes the most sense, semantically, but 'Z' seems
-- to be the one replicating the 'open' effect in schematics.
configuration uart_xcvr of uart is -- [config. name] of entity
    for transceiver -- (i.e., the encapsulating architecture)
    
        for all : work.uart_pkg.uart_rcvr -- (i.e., component instance)
            use entity work.uart (receiver)
                generic map (
                    g_CLK_FREQ  => g_CLK_FREQ,
                    g_BAUD      => g_BAUD
                )
                port map (
                    i_clk       => i_clk,
                    i_rst       => i_rst,
                    
                    i_rx_serial => i_serial,
                    o_rx_done   => o_done,
                    o_rx_byte   => o_byte,
                    
                    i_tx_send   => 'Z',
                    i_tx_byte   => (others => 'Z'),
                    o_tx_active => open,
                    o_tx_done   => open,
                    o_tx_serial => open                    
                );
        end for;
        
        for all : work.uart_pkg.uart_xmtr -- (i.e., component instance)
            use entity work.uart (transmitter)
                generic map (
                    g_CLK_FREQ  => g_CLK_FREQ,
                    g_BAUD      => g_BAUD
                )
                port map (
                    i_clk       => i_clk,
                    i_rst       => i_rst,

                    i_rx_serial => 'Z',
                    o_rx_done   => open,
                    o_rx_byte   => open,

                    i_tx_send   => i_send,
                    i_tx_byte   => i_byte,
                    o_tx_active => o_active,
                    o_tx_done   => o_done,
                    o_tx_serial => o_serial
                );
        end for;
           
    end for;
end configuration uart_xcvr;


-- --------------------------------------------------------------------
-- END OF FILE: uart_xcvr.vhd
-- --------------------------------------------------------------------