-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- uart_rcvr.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;

library config;
    use config.constants.all;

-- A simplex async. receiver (in 8-N-1 frame)
architecture receiver of uart is -- [RTL arch.]
    -- Receiver's Finite-State Machine (FSM)
    type uart_rx_state_t is (
        idle, started, reading, done
    );
    signal uart_rx_state : uart_rx_state_t := idle;
    
    -- Synchronized signal (from a metastable input signal).
    signal synced_serial : std_ulogic;
    
    signal tick_cnt  : natural range 0 to TICKS_PER_BIT := 0;
    signal bit_index : natural range 0 to DATA_HIGH := 0;
begin

    -- NOTE: The input signal is assumed to have been synchronized/
    -- deglitched beforehand, at the top module.
    synced_serial <= i_rx_serial; -- CONCURRENT assignment
     

    -- NOTE: As a little history, the reason why the 'start bit' is
    -- checked to be 'active low' as opposed to 'active high' is
    -- because physical cable connections could run far and were also
    -- suspectible to damage along the path; by constantly driving an
    -- 'active high' singal you could know for sure that (long) pauses
    -- meant a disruption in the line, unlike what would otherwise be
    -- interpreted as intentional "silence" in an 'active low' setup.
    receive : process (i_clk, i_rst) is
        procedure perform_reset is
        begin
            uart_rx_state <= idle;
        end procedure perform_reset;
    begin
    
        if not c_RST_SYNC and i_rst = c_RST_POLE then perform_reset;
        elsif rising_edge(i_clk) then
            if c_RST_SYNC and i_rst = c_RST_POLE then perform_reset;
            else
                -- NOTE: There is no need for an 'others' default case,
                -- because we are dealing with enumerated types and not
                -- std_logics; all enumerated cases are accounted for.
                -- SEE: sigasi.com/tech/
                --          vhdl-case-statements-can-do-without-others
                -- Despite this, the 'others' case can still be used to
                -- harden the state machine (against radiation, maybe)
                -- and make it safer by recovering from unknown values.
                --
                -- NOTE: Always assign a value to signals in a state
                -- machine; otherwise, latches (hard to synth, slow, &
                -- prone to metastability) may be inferred. Also, since
                -- we cannot really use default values to solve that
                -- issue here, we instead re-assign the same state in
                -- branches that do not result in a change of state.
                case uart_rx_state is
                    -- Due to UART being asynchronous, a "start bit" is
                    -- utilized by the external transmitter to signal
                    -- that the actual data bits are forthcoming; the
                    -- start bit is simply a falling edge (from idle
                    -- high to a low pulse) immediately followed by
                    -- user data bits.
                    when idle =>
                        uart_rx_state <= idle;
                        
                        -- Reset back to default values
                        o_rx_done <= '0';
                        o_rx_byte <= (others => '0');
                        bit_index <= 0;
                        tick_cnt  <= 0;       
                        
                        if synced_serial = '0' then
                            uart_rx_state <= started;
                        end if;
                    -- -------------------------------------------------
                    
                    -- It is important to note that, even after the
                    -- start bit it detected, we still re-check the
                    -- start bit at its middle (one-half 'bit time')
                    -- as to make sure it was really valid.  If not,
                    -- it is considered a spurious pulse (noise)
                    -- and is ignored.
                    --     Also, by waiting for the mid-point and
                    -- only then moving to the next state, we'd
                    -- also be shifting future data reads (sampling)
                    -- to their respective mid-points.
                    when started =>
                        uart_rx_state <= started;
                    
                        if (tick_cnt < TICKS_PER_BIT / 2) then
                            tick_cnt <= tick_cnt + 1; -- Not middle
                        else -- Reached the middle
                            if (synced_serial = '0') then -- Real start
                                tick_cnt <= 0; -- Found mid; reset cnt
                                uart_rx_state <= reading; -- Begin read
                            else -- Spurious pulse; ignore
                                uart_rx_state <= idle;
                            end if;
                        end if;
                    -- -------------------------------------------------
                     
                    when reading =>
                        uart_rx_state <= reading;
                    
                        if (tick_cnt < TICKS_PER_BIT) then
                            tick_cnt <= tick_cnt + 1;
                        else
                            tick_cnt <= 0;
                            -- NOTE: Data is sent with Least-Sig. Byte
                            -- first; holding type should be 'downto'
                            o_rx_byte(bit_index) <= synced_serial;
                            
                            -- Check if more bits remain to be received
                            if (bit_index < DATA_HIGH) then
                                bit_index <= bit_index + 1;
                            else
                                bit_index     <= 0;
                                uart_rx_state <= done;
                            end if;
                        end if;
                    -- -------------------------------------------------
    
                    -- Once the data bits finish, a "stop bit" will
                    -- indicate so; the stop bit is normally a
                    -- transition back to the idle state or remaining
                    -- at the high state for an extra bit time.
                    -- A second (optional) stop bit can be configured,
                    -- usually to give the receiver time to get ready
                    -- for the next frame, but that is uncommon.
                    --     Considering how we already know the frame's
                    -- size beforehand, it might seem unnecessary to
                    -- even have a stop bit.  However, the UART
                    -- does not depend on the start bit itself, for
                    -- synchronization, but the falling _edge_ between
                    -- the previous stop bit AND the start bit.
                    -- There might not be such an edge without both
                    -- the start and stop bits.
                    when done =>
                        uart_rx_state <= done;
                        
                        if (tick_cnt < TICKS_PER_BIT) then
                            tick_cnt <= tick_cnt + 1;
                        else
                            -- TODO: Error-check the stop bit as an
                            -- extra protection against de-syncing.
                            --if (synced_serial /= '1') then
                            --    perform_reset;
                            --end if;
                            
                            o_rx_done     <= '1';
                            tick_cnt      <= 0;
                            uart_rx_state <= idle;
                        end if;
                    -- -------------------------------------------------
                        
                    -- Hardening in case of "unknown" states    
                    when others => -- 1-clock-long cleanup phase
                        perform_reset;
                    -- -------------------------------------------------
                end case;
                
            end if;
        end if;
    end process receive;
   
end architecture receiver;


-- ---------------------------------------------------------------------
-- END OF FILE: uart_rcvr.vhd
-- ---------------------------------------------------------------------