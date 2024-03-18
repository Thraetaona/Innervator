-----------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- config.vhd is a part of Innervator.
-----------------------------------------------------------------------


-- NOTE: You NEED to re-declare used libraries AFTER you instantiate
-- the packages here; otherwise, basic types like "std_logic" will not
-- get recognized!  This is because VHDL and Ada's ancient compilers
-- were "one-pass" and did not keep track of contexes.  See:
-- https://insights.sigasi.com/tech/use-and-library-vhdl/
--library work, std, ieee;


package constants is
    constant CLK_FREQ : positive := 100e6;
    constant CLK_PERD : time     := 1 sec / CLK_FREQ;
end package constants;

-- "'guard_bits' defaults to 'fixed_guard_bits,' which defaults
-- to 3. Guard bits are used in the rounding routines. If guard
-- is set to 0, the rounding is automatically turned off.
-- These extra bits are added to the end of the numbers in the
-- division and "to_real" functions to make the numbers more
-- accurate." (Fixed point package user's guide By David Bishop)
library ieee;
package fixed_pkg_for_neural is new ieee.fixed_generic_pkg
    generic map ( -- NOTE: ieee_proposed pre VHDL-08
        fixed_round_style    => ieee.fixed_float_types.fixed_truncate,
        fixed_overflow_style => ieee.fixed_float_types.fixed_saturate,
        fixed_guard_bits     => 0,
        no_warning           => false
    );
    
library core;
package neural_typedefs is new core.fixed_neural_pkg
    generic map (
        INTEGRAL_BITS        => 4, -- NOTE: Signed
        FRACTIONAL_BITS      => 4,
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

    -- NOTE: Xilinx Vivado does not support fixed- or floating-point
    -- packages for use within its simulator, even though it can
    -- synthetize them just fine; as a workaround, use 
    -- 'ieee_proposed' instead of 'ieee'.
    --
    -- SEE: 
    --     docs.xilinx.com/r/en-US/ug900-vivado-logic-simulation/
    --         Fixed-and-Floating-Point-Packages
    --
    --     insights.sigasi.com/tech/list-known-vhdl-metacomment-pragmas

-----------------------------------------------------------------------
-- pragma translate_off
-----------------------------------------------------------------------
    --library ieee_proposed;
    --    use ieee_proposed.fixed_pkg.all;
-----------------------------------------------------------------------
-- pragma translate_on
-----------------------------------------------------------------------
end context neural_context;


-----------------------------------------------------------------------
-- END OF FILE: config.vhd
-----------------------------------------------------------------------