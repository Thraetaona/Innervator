-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- uart.vhd is a part of Innervator.
-- --------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- A simplex (i.e., one-way) async. receiver in the 8-N-1 frame:
-- eight (8) data bits, no (N) parity bit, and one (1) stop bit, plus
-- an implicit start bit; in this case, only 80% is used for the data.
-- When reading is done, 'o_done' will be driven high for 1 clock cycle
entity uart is
    -- In digital communications, "baud" (i.e., symbol rate) is equal
    -- to the bitrate (bit-rate).  However, when the communications is
    -- modulated to analog, a baud _can_ encode more than 1 bit.
    generic (
        CLK_FREQ  : positive;
        BAUD      : positive range positive'low to CLK_FREQ := 9_600
    );
    -- NOTE: 'Buffer' data flows out of the entity, but the entity can
    -- read the signal (allowing for internal feedback); however, the
    -- signal cannot be driven from outside the entity, unlike inputs.
    port (
        i_clk    : in  std_ulogic; -- Internal FPGA clock
        i_serial : in  std_logic; -- External connection (wire)
        o_done   : out std_ulogic; -- FPGA's "done reading" signal
        o_byte   : out std_logic_vector (7 downto 0) -- LSB first
    );
end entity uart;
 

architecture receiver of uart is
    constant TICKS_PER_BIT : integer := integer(CLK_FREQ / BAUD) - 1;
    constant DATA_HIGH     : natural := o_byte'high;

    -- The Finite-State Machine (FSM)
    type uart_rx_state_t is (
        idle, started, reading, stopped, done
    );
    signal uart_state : uart_rx_state_t := idle;
    
    -- Synchronized (from a metastable i_serial) signal.
    signal synced_serial : std_ulogic := '0';
    
    signal tick_cnt  : integer range 0 to TICKS_PER_BIT := 0;
    signal bit_index : integer range 0 to DATA_HIGH := 0;
begin
 
    -- NOTE: This "double-registers" the incoming data, allowing it to
    -- be used in the UART's clock domain; avoids metastabiliy problems
    double_register : entity work.synchronizer
        generic map (NUM_CASCADES => 2) -- Double (2)
        port map (
            clk_in  => i_clk,
            sig_in  => i_serial,
            sig_out => synced_serial
        );    
    

    -- NOTE: As a little history, the reason why the 'start bit' is
    -- checked to be 'active low' as opposed to 'active high' is
    -- because physical cable connections could run far and were also
    -- suspectible to damage along the path; by constantly driving an
    -- 'active high' singal you could know for sure that (long) pauses
    -- meant a disruption in the line, unlike what would otherwise be
    -- interpreted as intentional "silence" in an 'active low' setup.
    receive : process (i_clk) is
    begin
        if rising_edge(i_clk) then

            -- NOTE: There is no need for an 'others' default case,
            -- because we are dealing with enumerated types and not
            -- std_logics; all enumerated cases are accounted for. SEE:
            -- sigasi.com/tech/
            --     vhdl-case-statements-can-do-without-others
            -- Despite this, the 'others' case can still be used to 
            -- harden the state machine (against radiation, maybe)
            -- and make it safer by recovering from unknown values.
            --
            -- NOTE: Always assign a value to signals in a state
            -- machine; otherwise, latches (hard to synth, slow, and
            -- prone to metastability) may be inferred.  Also, since
            -- we cannot really use default values to solve that issue
            -- here, we instead re-assign the same state in branches
            -- that do not result in a change of state.
            case uart_state is
                -- Due to UART being asynchronous, a "start bit" is
                -- utilized by the external transmitter to signal that
                -- the actual data bits are forthcoming; the start bit
                -- is simply a falling edge (from idle high to a low
                -- pulse) immediately followed by user data bits.
                when idle =>
                    uart_state <=
                        started when (synced_serial = '0') else idle;                

                    -- Reset back to default values
                    o_done    <= '0';
                    bit_index <= 0;
                    tick_cnt  <= 0;
                    
                -- ----------------------------------------------------
                
                -- It is important to note that, even after the start
                -- bit it detected, we still re-check the start bit
                -- at its middle (one-half 'bit time') as to make sure
                -- it was really valid.  If not, it is considered a
                -- spurious pulse (noise) and is ignored.
                when started =>
                    uart_state <= started;
                
                    if (tick_cnt < TICKS_PER_BIT / 2) then
                        tick_cnt  <= tick_cnt + 1; -- Not found middle
                    else -- Reached the middle
                        if (synced_serial = '0') then -- Genuine start
                            tick_cnt <= 0; -- Found middle; reset count
                            uart_state <= reading; -- Start reading
                        else -- Spurious pulse; ignore
                            uart_state <= idle;
                        end if;
                    end if;
                -- ----------------------------------------------------
                 
                -- Wait TICKS_PER_BIT clock cycles to sample serial data
                when reading =>
                    uart_state <= reading;
                
                    if (tick_cnt < TICKS_PER_BIT/2) then -- TODO: /2 ??
                        tick_cnt <= tick_cnt + 1;
                    else
                        tick_cnt <= 0;
                        -- NOTE: Data is sent with Least-Significant
                        -- Byte first; holding type has to be 'downto'
                        o_byte(bit_index) <= synced_serial;
                        
                        -- Check if all bits were indeed received
                        if (bit_index < DATA_HIGH) then
                            bit_index <= bit_index + 1;
                        else
                            bit_index  <= 0;
                            uart_state <= stopped;
                        end if;
                    end if;
                -- ----------------------------------------------------

                -- Once the data bits finish, a "stop bit" will
                -- indicate so; the stop bit is normally a
                -- transition back to the idle state or
                -- remaining at the high state for an extra bit time.
                -- A second (optional) stop bit can be configured,
                -- usually to give the receiver time to get ready for
                -- the next frame, but this is uncommon in practice.
                -- Receive Stop bit. Stop bit = 1
                when stopped =>
                    uart_state  <= stopped;
                
                    if (tick_cnt < TICKS_PER_BIT) then
                        tick_cnt <= tick_cnt + 1;
                    else
                        o_done     <= '1';
                        tick_cnt   <= 0;
                        uart_state <= idle;
                    end if;
                -- ----------------------------------------------------
                    
                -- Hardening in case of "unknown" states    
                when others => -- 1-clock-long cleanup phase
                    uart_state <= idle;
                -- ----------------------------------------------------
            end case;
            
        end if;
    end process receive;
   
end architecture receiver;


-- --------------------------------------------------------------------
-- END OF FILE: uart.vhd
-- --------------------------------------------------------------------