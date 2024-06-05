-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- debouncer.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;

library config;
    use config.constants.all;

-- Background: When you press a physical button, the metal contacts
-- don't make a perfect, clean contact instantly; instead, they might
-- "bounce" against each other several times, over a few milliseconds,
-- before settling into a closed state.  Additionally, Microcontrollers
-- and FPGAs are incredibly fast, and they can detect each of those
-- tiny bounces as if they were separate button presses; this could
-- lead to a single button press being interpreted as multiple presses.
--     There are many ways to resolve this matter, and they could be 
-- done using hardware approaches (e.g., using a resister-capacitor)
-- or software-based ones.  In a software approach, we could detect
-- a button transition and sample it again at a later point in time,
-- which is at least a few milliseconds long (like 10 ms); if the
-- button's state had remained the same (i.e., it was "stable"), we
-- output that the button was "pressed" once. 
--     Be aware that other problems arising from external, wired
-- interfaces might still apply: we had better accounted for
-- metastability and asynchnorized clock domains.
entity debouncer is
    generic (
        -- Timeout in milliseconds
        g_TIMEOUT_MS : time := 30 ms
    );
    port (
        i_clk     : in  std_ulogic;
        i_button  : in  std_ulogic;
        o_button  : out std_ulogic
    );
end entity debouncer;

architecture behavioral of debouncer is
    -- Logically, we are supposed to divide the time by 1000,
    -- but VHDL simulators just don't like it when you perform
    -- integer math with physical units like time.
    constant timeout_ticks  : positive :=
         (g_TIMEOUT_MS / ms) * (c_CLK_FREQ / 1000);
    signal timeout_count  : natural range 0 to timeout_ticks-1 := 0;
    
    signal previous_state : std_ulogic := '0';
begin

    process (i_clk) is
    begin
        if rising_edge(i_clk) then
            if (i_button /= previous_state and
                timeout_count < timeout_ticks-1)
            then
                -- If there's been a change in the button's state, we
                -- begin to track it as long as it hasn't stayed
                -- "stable" (i.e., unchanged) over the given timeout.
                timeout_count <= timeout_count + 1;
            elsif timeout_count = timeout_ticks-1 then
                -- Otherwise, for the duration of the timeout, the
                -- button did not change and can be registered.
                previous_state <= i_button;
            else
                -- No change in button state; keep waiting.
                timeout_count <= 0;     
            end if;
        end if;
    end process;
  
    o_button <= previous_state;
    
end architecture behavioral;

-- ---------------------------------------------------------------------
-- END OF FILE: debouncer.vhd
-- ---------------------------------------------------------------------