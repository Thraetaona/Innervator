-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- synchronizer.vhd is a part of Innervator.
-- --------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;

-- Metastability occurs in flip-flops when the input signal changes
-- too close to the clock edge, violating "setup and hold" times;
-- this leaves the flip-flop in an unresolved state where the
-- output can be unpredictable and could potentially cause errors
-- in connected logic.  To mitigate this, "cascading" multiple
-- flip-flops at the input is a common solution; it provides
-- additional time for the metastable signal to settle into a
-- stable 0 or 1 before being utilized elsewhere in the circuit.
entity synchronizer is
    generic (
        NUM_CASCADES : natural := 3
    );
    port (
        clk_in  : in  std_ulogic;
        sig_in  : in  std_ulogic;
        sig_out : out std_ulogic
    );
end entity synchronizer;
 
architecture rtl of synchronizer is
    constant CASCADES_HIGH : natural := NUM_CASCADES - 1; -- Loop count

    -- NOTE: I initially wanted to place this vector as individual
    -- values inside the for-generate loop, but you cannot refer back
    -- to a previous iteration of for-generate to access (i-1); the
    -- solution was to declare it as a vector here.  SEE:
    -- https://groups.google.com/g/comp.lang.vhdl/c/rm97yoJwcWc
    signal cascaded_regs : std_ulogic_vector
        (CASCADES_HIGH downto 0) := (others => '0');
begin

    cascade_chain : for i in 0 to CASCADES_HIGH generate
        cascade_register : process (clk_in) begin
            if rising_edge(clk_in) then
                -- If it is the first instance, then we must use
                -- the actual input signal; no previously cascaded
                -- registers can exist before i=0.
                cascaded_regs(i) <=
                    sig_in when (i = 0) else cascaded_regs(i-1);
            end if;
        end process cascade_register;
    end generate cascade_chain;

    sig_out <= cascaded_regs(CASCADES_HIGH);

end architecture rtl;


-- --------------------------------------------------------------------
-- END OF FILE: synchronizer.vhd
-- --------------------------------------------------------------------