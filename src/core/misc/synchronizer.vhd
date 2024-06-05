-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- synchronizer.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


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
--     This is called "synchronizing" or "de-glitching."
--
-- NOTE: A good portion of this synchronization also overlaps with
-- "pipelining," because both use a series of clocked flip-flops.
-- However, a good reason to separate them is to (hopefully) have
-- the synthesization tool lay out pipelines or synchronizers
-- close to their own respective groups.  Also, the synchronizer
-- might be extended later on (maybe to support multiple clocks)
-- and separating them early-on would be beneficial, in that case.
--
-- TODO: Have a variadic variant for std_(u)logic VECTORS.
entity synchronizer is
    generic (
        g_NUM_STAGES : positive := 2
    );
    port (
        i_clk     : in  std_ulogic;
        i_signal  : in  std_ulogic;
        o_signal  : out std_ulogic
    );
end entity synchronizer;
 
architecture behavioral of synchronizer is
    -- Synthesis tools will often replace a series of flip-flops
    -- with better primitives, like shift-registers, that "achieve"
    -- the same delaying effect.  However, we might sometimes WANT
    -- to use flip-flops specifically, so we can turn off that
    -- optimization by using vendor-specific attribute definitions.
    --
    -- Also, note that avoiding the usage of explicit reset signals
    -- may also result in the same shift-register (SRL) conversion.
    --     ednasia.com/coding-consideration-for-pipeline-flip-flops
        
    /* Xilinx Vivado/XST */
    -- Disable the conversion of flip-flops to to shift-registers
    attribute shreg_extract : string;
    -- Specifies that registers receive async. data.
    attribute async_reg     : boolean; -- Also implies DONT_TOUCH.
    
    -- TODO: See if we should apply this to the input/output?
    -- Input
    attribute shreg_extract of i_signal : signal is "no";
    attribute async_reg     of i_signal : signal is true;
    -- Output
    attribute shreg_extract of o_signal : signal is "no";
    attribute async_reg     of o_signal : signal is true;
begin

    -- NOTE: Concurrent assignments mean that there is no
    -- delay involved; both wires "connect" and act as one.
    --
    -- "Delaying" by 1 stage means that we will not have
    -- to place any additional flip-flops in the middle.
    -- The reason is that the unregistered i_signal
    -- would also have a propagation delay of 1 whenever
    -- something is assigned to it.
    single_pipeline : if g_NUM_STAGES = 1 generate
        o_signal <= i_signal; -- CONCURRENT assignment
    -- Otherwise, implement actual delay with flip-flops.
    else generate
        -- NOTE: We subtract by 2 because the incoming (input)
        -- signal itself also counts; so, when we talk about "double
        -- registering" something, we know that there already WAS
        -- a flip-flop register (i.e., the 'in' signal) and
        -- we need to add just 1 more to it.
        constant STAGES_HIGH : natural := g_NUM_STAGES - 2;
    
        -- NOTE: I initially wanted to place this vector as individual
        -- values inside the for-generate loop, but you cannot refer
        -- back to a previous iteration of for-generate to access (i-1);
        -- the solution was to declare it as a vector here.  SEE:
        -- https://groups.google.com/g/comp.lang.vhdl/c/rm97yoJwcWc
        signal sync_regs : std_ulogic_vector
            (0 to STAGES_HIGH) := (others => '0');
            
        attribute shreg_extract of sync_regs : signal is "no";
        attribute async_reg     of sync_regs : signal is true;
    begin
        cascade_chain : for i in 0 to STAGES_HIGH generate
            cascade_register : process (i_clk) begin
                if rising_edge(i_clk) then
                    -- If it is the first instance, then we must use
                    -- the actual input signal; no previously cascaded
                    -- registers can exist before i=0.
                    sync_regs(i) <=
                        i_signal when i = 0 else sync_regs(i-1);
                end if;
            end process cascade_register;
        end generate cascade_chain;
        
        o_signal <= sync_regs(STAGES_HIGH); -- CONCURRENT assignment
    end generate;

end architecture behavioral;


-- ---------------------------------------------------------------------
-- END OF FILE: synchronizer.vhd
-- ---------------------------------------------------------------------