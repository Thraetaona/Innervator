-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- config.vhd is a part of Innervator.
-- --------------------------------------------------------------------


-- NOTE: You NEED to re-declare used libraries AFTER you instantiate
-- the packages here; otherwise, basic types like "std_logic" will not
-- get recognized!  This is because VHDL and Ada's ancient compilers
-- were "one-pass" and did not keep track of contexes.  See:
-- https://insights.sigasi.com/tech/use-and-library-vhdl/
--library work, std, ieee;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.fixed_float_types.all;
    
package constants is
    /* Compile-Time Data File's Location */
    -- NOTE: You could also use relative paths (../) here, but they
    -- vary between simulators/synthesizers, defeating the purpose.
    constant c_DAT_PATH : string :=
        "C:/Users/Thrae/Desktop/Innervator/data";
    /* FPGA Constrains & Configurations */
    constant c_CLK_FREQ : positive   := 100e6;
    constant c_CLK_PERD : time       := 1 sec / c_CLK_FREQ;
    constant c_RST_SYNC : boolean    := true; -- false = async. reset
    constant c_RST_POLE : std_ulogic := '0'; -- '0' = negative reset
    -- TODO: Have a constant that chooses rising_ or falling_edge?
    --constant c_EDG_RISE 
    /* Internal Fixed-Point Wordings */
    constant c_WORD_INTG   : natural  := 4;
    constant c_WORD_FRAC   : natural  := 4;
    constant c_WORD_SIZE   : positive := c_WORD_INTG + c_WORD_FRAC;
    constant c_GUARD_BITS  : natural  := 0;
    constant c_FIXED_ROUND : fixed_round_style_type    :=
        fixed_truncate;
    constant c_FIXED_OFLOW : fixed_overflow_style_type :=
        fixed_saturate;
    /* UART Parameters */
    -- NOTE: Bitrate = Baud, in the digital world
    constant c_BIT_RATE : positive := 9_600;
    constant c_BIT_PERD : time     := 1 sec / c_BIT_RATE;
end package constants;

-- "'guard_bits' defaults to 'fixed_guard_bits,' which defaults
-- to 3. Guard bits are used in the rounding routines. If guard
-- is set to 0, the rounding is automatically turned off.
-- These extra bits are added to the end of the numbers in the
-- division and "to_real" functions to make the numbers more
-- accurate." (Fixed point package user's guide By David Bishop)
library ieee;
use work.constants.all;
package fixed_pkg_for_neural is new ieee.fixed_generic_pkg
    generic map ( -- NOTE: ieee_proposed pre VHDL-08
        fixed_round_style    => c_FIXED_ROUND,
        fixed_overflow_style => c_FIXED_OFLOW,
        fixed_guard_bits     => c_GUARD_BITS,
        no_warning           => false
    );
    
library neural;
use work.constants.all;
package neural_typedefs is new neural.fixed_neural_pkg
    generic map (
        INTEGRAL_BITS        => c_WORD_INTG, -- NOTE: Signed
        FRACTIONAL_BITS      => c_WORD_FRAC,
        FIXED_PKG_INSTANCE   => work.fixed_pkg_for_neural
    );
-- After instanation, you may use the Packages above as follows:
-- use work.fixed_pkg_for_neural.all, work.neural_typedefs.all;
--
-- Alternatively, you may use their bundle as a context 
-- (defined near the end of this file).

-- NOTE: IEEE's official fixed-point package has a bug (in
-- IEEE 1076-2008, a.k.a. VHDL-08), where to_ufixed(sfixed) isn't
-- defined in the Package's header file, while its parallel
-- to_sfixed(ufixed) is.  So, the solution is to copy-paste the
-- decleration of said function from fixed_generic_pkg-body.vhdl
-- into our local library.
-- SEE: https://gitlab.com/IEEE-P1076/VHDL-Issues/-/issues/269
library ieee;
    use ieee.std_logic_1164.all; -- Added to fix ModelSim's errors

library work;
    use work.fixed_pkg_for_neural.all, work.neural_typedefs.all;

package fixed_generic_pkg_bugfix is
    function to_ufixed(
        arg : UNRESOLVED_sfixed
    ) return UNRESOLVED_ufixed;
end package fixed_generic_pkg_bugfix;

package body fixed_generic_pkg_bugfix is
    -- null array constants
    constant NAUF : UNRESOLVED_ufixed (0 downto 1) :=
        (others => '0');
    
    -- Special version of "minimum" to do some
    -- boundary checking with errors
    function mine(l, r : INTEGER) return INTEGER is
    begin 
        if (L = INTEGER'low or R = INTEGER'low) then
            report fixed_generic_pkg_bugfix'instance_name
                & " Unbounded number passed, was a literal used?"
                severity error;
            return 0;
        end if;
        
        return minimum (L, R);
    end function mine;     

    -- converts an sfixed into a ufixed.  The output is the same
    -- length as the input, because abs("1000") = "1000" = 8.
    function to_ufixed(
        arg : UNRESOLVED_sfixed
    ) return UNRESOLVED_ufixed is
        constant left_index  : INTEGER := arg'high;
        constant right_index : INTEGER := mine(arg'low, arg'low);
        variable xarg        :
            UNRESOLVED_sfixed (left_index+1 downto right_index);
        variable result      :
            UNRESOLVED_ufixed (left_index downto right_index);    
    begin
        if arg'length < 1 then
            return NAUF;
        end if;
        
        xarg   := abs(arg);
        result := UNRESOLVED_ufixed (
            xarg (left_index downto right_index)
        );
        
        return result;
        
    end function to_ufixed;
end package body fixed_generic_pkg_bugfix;

-- After instanation, you may use the Packages above as follows:
-- use work.fixed_pkg_for_neural.all, work.neural_typedefs.all;
--
-- Alternatively, you may use their bundle as a context:
context neural_context is -- VHDL-2008 feature
    library config;
        use config.fixed_pkg_for_neural.all,
            config.neural_typedefs.all;
        use config.fixed_generic_pkg_bugfix.all; -- REQUIRED!
end context neural_context;

-- NOTE: Unfortunately, even if I play by Vivado Simulator's rules by
-- placing the VHDL-93 compatibility version of ieee's fixed_pkg into
-- a local directory AND commenting-out all homographes of std_logic_
-- vectors AND removing all references to 'line' datatypes, it still
-- finds a way to crash abruptly in other areas (e.g., File I/O),
-- without any log whatsoever, in simulation; working with Vivado's
-- Simulator is pointless as even a ModelSim version from 8 years ago
-- (as of 2024) far outperforms it.

-- --------------------------------------------------------------------
-- rtl_synthesis off
-- pragma translate_off
-- --------------------------------------------------------------------

-- NOTE: Here, in simulation, we OVERWRITE the previous declaration;
-- this is done because there is no other way to detect whether the
-- code is being simulated and skip synth's code, in the latter case we
-- also need to use a custom version of IEEE's fixed_pkg due to Vivado.
/*
context neural_context is
    library ieee_proposed;
        use ieee_proposed.fixed_pkg.all;
    -- NOTE: Xilinx Vivado does not support fixed- or floating-point
    -- packages for use within its simulator, even though it can
    -- synthetize them just fine; as a workaround, use 
    -- a LOCAL 'ieee_proposed' instead of 'ieee'.
    --
    -- SEE: 
    --     docs.xilinx.com/r/en-US/ug900-vivado-logic-simulation/
    --         Fixed-and-Floating-Point-Packages
    --
    --     insights.sigasi.com/tech/list-known-vhdl-metacomment-pragmas
    library config;
        use config.neural_typedefs.all;
        use config.fixed_generic_pkg_bugfix.all; -- REQUIRED!
end context neural_context;
*/

-- --------------------------------------------------------------------
-- pragma translate_on
-- rtl_synthesis on
-- --------------------------------------------------------------------


-- --------------------------------------------------------------------
-- END OF FILE: config.vhd
-- --------------------------------------------------------------------