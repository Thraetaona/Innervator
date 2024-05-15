-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- pipeliner.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


-- For background, sometimes operations/logic inside a process might
-- take too long, due to the limitations of the physical world, and
-- therefore not be ready within a single clock cycle; this is referred
-- to as "timing violation" in FPGA design, and it is especially
-- prevalent when using too many combination logic and/or having too
-- fast of a clock (e.g., 500MHz -> 2 ns).  So, a workaround is to
-- "delay" (i.e., spread) the processing of data over multiple clock
-- cycles; this is done by assigning inputs/outputs to one or more
-- "register" signals, which makes said ins/outs reach the outside
-- entities by multiple clock cycles (e.g., 50 ns instead of 10 ns)
-- as to give the FPGA fabric more time to complete the operations
-- we ask it to.  Also, certain built-in blocks, such as DSPs, will
-- "pull in" our externally registered (pipelined) signals and have
-- the same delaying effect.
--     Another type of delay is "routing" delay, which is actually
-- more common nowadays and in newer FPGAs.  Routing delay refers
-- to the actual, physicel delay caused by electricity moving too
-- "slowly" in an internal FPGA route (i.e., wire), and it is often
-- caused when you try to access specific hard-macro components
-- (e.g., a DSP or BRAM) that only exists in a specific location
-- of your FPGA chip, while you have too much logic depend on that,
-- which, in turn, makes it physically impossible for the router to
-- place them all next to said hard-macro instantiation.  The solution
-- is exactly the same: convert the routed path to a "multi-cycle"
-- clock using flip-flop chains.
--     Note that delaying does imply that external users have to
-- "wait" for the processing to be finished before they can supply
-- new data to us; while the old data is going through flip-flop
-- chains, new data could follow after just a single clock cycle.
-- If the data D1 is given at nanosecond 0 and D2 at 10, then
-- (in a double-registering pipeline), output O1 would be returned
-- at nanosecond 20 AND O2 would STILL appear at 30.  In other words,
-- we didn't have to wait for O1 to be fully done before passing D2,
-- and you could think of it as a car assembly line.
--     Be aware that timing violations do not 100% mean that your
-- design won't work in practice.  Synthesis tools account for all
-- extremities when calculating timing violations; they consider
-- worst-case scenarios and ascertain that your described logic will
-- finish under those circumstances within the allocated clock cycle.
-- If you proceed with having tiny timing errors, your design might
-- work just fine, but the moment your FPGA package gets too heated
-- or too cold (for example), it'll have a higher tendency to fail.
--     Also, this closely relates to a "synchronizer," which also
-- uses delay lines to solve a different problem (metastability).
--     Lastly, you might have to enable "retiming" optimizations in
-- your synthesis tools so that they may take advantage of pipelining.

library ieee;
    use ieee.std_logic_1164.all;

-- NOTE: Currently, there is a language inconsistency (reported by me)
-- in VHDL that disallows output ports from being able to use
-- "aggregated" expressions (i.e., tuples) such as (1, 2, 3) or
-- (A, B, C):
--     https://gitlab.com/IEEE-P1076/VHDL-Issues/-/issues/311
--
-- had they been allowed, the entity could have been used like so:
--
--    -- Here, we expect that the entity constructs a "trit vector"
--    -- type internally, using it to denote its input/output signals.
--    test_instance : entity work.pipeliner
--        generic map (2, trit)
--        port map (
--            (alpha, beta, gamma), -- This works, as of VHDL-08.
--            (alpha_reg, beta_reg, gamma_reg) -- EXPRESSION ERROR!
--        );
--
-- However, because dis-aggregation is not done on 'out' ports, and
-- because arrays cannot be constructed based on a base type in VHDL
-- versions earlier than 2019, the next interface could have been this:
--
--    -- trit_vector is defined by us earlier in the Architecture.
--    test_instance : entity work.pipeliner
--        generic map (2, trit_vector, 3)
--        port map (
--            (alpha, beta, gamma), -- This works, as of VHDL-08.
--            o_signals(0) => alpha_reg,
--            o_signals(1) => beta_reg,
--            o_signals(2) => gamma_reg
--        );
--
-- Sadly, you cannot "convince" VHDL's strong typing system that the
-- generically provided type is, in fact, an array that you can index
-- over; this means that the next alternative was either "dividing" the
-- interface to take/return one signal at a time, or continue with 
-- tuples but provide a duplicate overload for every single array type.
--
-- NOTE: The aforementioned topic also applies equally to generic
-- subprograms (i.e., generically typed procedures) with the difference
-- being that they cannot have indexed/composite port assignments
-- whatsoever; the compiler complains about non-static (?) ports.
--
-- NOTE: Subprograms (like procedures) can take generic arguments,
-- similar to entities.  However, a nuanced difference is that an
-- entity's  'generic(...);' and 'port(...);' clauses are statements
-- (hence the semicolon; after them), while 'generic(...)' and 
-- 'parameter(...)' are NOT statements and do not have semicolons.
-- This also means that we cannot declare constants in-between the
-- 'procedure' and 'is' keywords, unlike entities.
package pipeliner is
    procedure registrar
        generic (
            constant g_NUM_STAGES :
                in natural range 2 to natural'high := 3;
            type     t_ARG_TYPE
        )
        parameter (
            signal i_clk    : in  std_ulogic;
            signal i_signal : in  t_ARG_TYPE;
            signal o_signal : out t_ARG_TYPE
        );

end package pipeliner;

-- Instantiate in the following format:
--
--     procedure register_signal is new core.pipeliner.registrar
--         generic map (3, std_logic_vector);
--
--     register_signal(i_clk, sig_unreg, sig_reg);
-- 
package body pipeliner is

    -- Works on a single signal at a time
    procedure registrar -- Singular
        generic (
            constant g_NUM_STAGES :
                in natural range 2 to natural'high := 3;
            type     t_ARG_TYPE
        )
        parameter (
            signal i_clk    : in  std_ulogic;
            signal i_signal : in  t_ARG_TYPE;
            signal o_signal : out t_ARG_TYPE
        )
    is
        type t_arg_arr is array (natural range <>) of t_ARG_TYPE;
        -- NOTE: Even though this is a variable, and variables are 
        -- purported to update their values immediately, these are,
        -- in reality, no different from normal signals in this case.
        -- Unlike simulation, hardware is not 100% perfect and a
        -- daisy-chain of variables mean that the following variables
        -- would be longer "wires" connecting them to preceding ones,
        -- meaning that there could be a delay (albeit very tiny)
        -- between the time it takes for the preceding variables to
        -- update their own values and the time it takes for variables
        -- later in the chain to take effect of said updates.
        --     I find a lot of tutorials and beginners' guides very
        -- misleading as a result of this; had such pitfalls been
        -- mentioned, variables would not be treated so arcanely.
        --     Also, since variables could effectively be used to
        -- replicate signals' delayed assignment behavior in synthesis,
        -- one cannot help but wonder why VHDL just doesn't let us
        -- declare signals directly in the first place; the reason
        -- is rather arbitrary and lies in (now-ancient) design
        -- choices of VHDL and Ada.
        variable pipeline_regs : t_arg_arr (g_NUM_STAGES-2 downto 0);
        
        -- Synthesis tools will often replace a series of flip-flops
        -- with better primitives, like shift-registers, that "achieve"
        -- the same delaying effect.  However, we might sometimes WANT
        -- to use flip-flops specifically, so we can turn off that
        -- optimization by using vendor-specific attribute definitions:
        attribute shreg_extract      : string;
        attribute register_balancing : string;
        attribute syn_allow_retiming : boolean;
        attribute shreg_extract of pipeline_regs : variable is "no";
        attribute register_balancing of Sig_out : signal is ATTR_REG_BALANCING;
        attribute syn_allow_retiming of Sig_out : signal is true;
        -- Also, note that avoiding the usage of explicit reset signals
        -- may also result in the same shift-register (SRL) conversion.
        --     ednasia.com/coding-consideration-for-pipeline-flip-flops
    begin    
        pipeline_regs(0) := i_signal when rising_edge(i_clk);
        
        for i in 1 to g_NUM_STAGES-2 loop
            pipeline_regs(i) :=
                pipeline_regs(i - 1) when rising_edge(i_clk);
        end loop;
        
        o_signal <= pipeline_regs(pipeline_regs'high);
    end procedure registrar;


    -- NOTE: The rationale behind using array types was to
    -- replicate the same "variadic" number of parameters
    -- that we have in C.
    --
    -- TODO: Whenever VHDL-2019 is widespread, make this take
    -- in a base type and construct its array ITSELF; this
    -- way, users won't have to define an otherwise-unused
    -- array type just to pass it to this entity, and they can
    -- use a single entity instantiation for multiple signals.
    --
    -- https://gitlab.com/IEEE-P1076/VHDL-Issues/-/issues/311
    /*
    procedure register_signals -- Plural
        generic (
            constant g_NUM_STAGES :
                in natural range 2 to natural'high := 3;
            
            type t_ELEMENT is private;
            type t_ARRAY is array (natural) of t_ELEMENT
        )
        parameter (
            signal i_clk     : in  std_ulogic;
            signal i_signals : in  t_ARRAY (0 downto 0);
            signal o_signals : out t_ARRAY (0 downto 0)
        )
    is
        -- NOTE: We subtract by 2 because the incoming (input) signal
        -- itself also counts; when we talk about "double registering"
        -- signals, we know that there already WAS a flip-flop register
        -- (i.e., the 'in' signal) and we need to add just 1 more to it
        constant NUM_ELEMS : positive := i_signals'length;
        -- Constrained subtypes of the array's elements.
        subtype t_CONSTRAINED is t_ARG_TYPE (i_signals'element'range);
        
        procedure register_custom_typed is new registrar
            generic map (g_NUM_STAGES, t_CONSTRAINED);
    begin
        -- Compile-time assertions will go here to ascertain
        -- that the 'input' and 'output' are of equal lengths.
        --assert i_signals'length = o_signals'length
            --report "Aggregated input/output tuples " &
            --       "are not equal in size."
                --severity failure;
    
        per_signal : for i in 0 to NUM_ELEMS-1 loop
            register_custom_typed(i_clk, i_signals(i), o_signals(i));
        end loop per_signal;
    end procedure register_signals;
    */

end package body pipeliner;


library ieee;
    use ieee.std_logic_1164.all;

entity pipeliner_single is
    generic (
        g_NUM_STAGES : natural range 1 to natural'high := 3;
        type arg_type
    );
    port (
        i_clk    : in  std_ulogic;
        i_signal : in  arg_type;
        o_signal : out arg_type
    );

    type arg_arr_type is array (natural range <>) of arg_type;
end entity pipeliner_single;
 
architecture behavioral of pipeliner_single is
    constant STAGES_HIGH : natural := g_NUM_STAGES - 1;
    signal pipeline_regs : arg_arr_type
        (STAGES_HIGH downto 1);
begin
    -- Delaying by 1 clock cycle means we will not have
    -- to place any "additional" flip-flops in the middle.
    single_pipeline : if g_NUM_STAGES = 1 generate
        o_signal <= i_signal;
    else generate
    
        pipeline_chain : for j in 1 to STAGES_HIGH generate
            pipeline_register : process (i_clk) begin
                if rising_edge(i_clk) then
                    pipeline_regs(j) <= i_signal when (j = 1)
                        else pipeline_regs(j-1);
                end if;
            end process pipeline_register;
        end generate pipeline_chain;
    
        o_signal <= pipeline_regs(STAGES_HIGH);
    
    end generate;
end architecture behavioral;



-- ---------------------------------------------------------------------
-- END OF FILE: pipeliner.vhd
-- ---------------------------------------------------------------------