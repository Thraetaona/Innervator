-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- uart.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;

-- A hierarchical interface for a full- or half-Duplex asynchronous
-- receiver/transmitter in the 8-N-1 frame: eight (8) data bits,
-- no (N) parity bit, and one (1) stop bit, plus an implicit start
-- bit; in this case, only 80% of the throughput is used for the data.
entity uart is
    -- In digital communications, "baud" (i.e., symbol rate) is equal
    -- to the bitrate (bit-rate).  However, when the communications is
    -- modulated to analog, a baud _can_ encode more than 1 bit.
    generic (
        -- TODO: Take data length as a generic.
        g_CLK_FREQ : positive := 100e6;
        g_BAUD     : positive range positive'low to g_CLK_FREQ := 9_600
    );
    -- NOTE: 'Buffer' data flows out of the entity, but the entity can
    -- read the signal (allowing for internal feedback); however, the
    -- signal cannot be driven from outside the entity, unlike inputs.
    port (
        -- UART-Rx/Tx (Receive/Transmit) Shared Ports
        i_clk       : in  std_ulogic; -- Internal FPGA clock
        i_rst       : in  std_ulogic; -- Reset
        -- UART-Rx (Receive) Ports
        i_rx_serial : in  std_logic; -- External connection (wire)
        o_rx_done   : out std_ulogic; -- "Done Reading" signal
        o_rx_byte   : out std_ulogic_vector (7 downto 0); -- LSB first
        -- UART-Tx (Transmit) Ports
        i_tx_send   : in  std_ulogic; -- "Start Sending" signal
        i_tx_byte   : in  std_ulogic_vector (7 downto 0); -- LSB first
        o_tx_active : out std_ulogic; -- Half-Duplex transmitters ONLY
        o_tx_done   : out std_ulogic; -- "Done Transmitting" signal
        o_tx_serial : out std_logic -- External connection (wire)
    );
    
    -- NOTE: constants here are applied to ALL architectures
    constant TICKS_PER_BIT : positive :=
        positive(g_CLK_FREQ / g_BAUD) - 1;
    constant DATA_HIGH     : natural  := o_rx_byte'high;
begin
end entity uart;


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- UART's standalone sub-components (i.e., UART-RCVR and -XMTR)
package uart_pkg is
	component uart_rcvr
        generic (
            g_CLK_FREQ : positive;
            g_BAUD     : positive
        );
        port (
            i_clk      : in  std_ulogic;
            i_rst      : in  std_ulogic;
            
            i_serial   : in  std_logic;
            o_done     : out std_ulogic;
            o_byte     : out std_ulogic_vector (7 downto 0)
        );
	end component uart_rcvr;
	
	component uart_xmtr
        generic (
            g_CLK_FREQ : positive;
            g_BAUD     : positive
        );
        port (
            i_clk      : in  std_ulogic;
            i_rst      : in  std_ulogic;

            i_send     : in  std_ulogic;
            i_byte     : in  std_ulogic_vector (7 downto 0);
            o_active   : out std_ulogic;
            o_done     : out std_ulogic;
            o_serial   : out std_logic
        );
	end component uart_xmtr;
end package uart_pkg;


-- ---------------------------------------------------------------------
-- END OF FILE: uart.vhd
-- ---------------------------------------------------------------------