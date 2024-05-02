-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- activation.vhd is a part of Innervator.
-- --------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    --use ieee.math_real.MATH_E; -- NOT synthetizable; use as generics!
  
library work;  
    context work.neural_context;


-- TODO: Implement more activation functions (e.g., ReLU, etc.)
package activation is

    alias in_type  is neural_dword;
    alias out_type is neural_bit;

    function sigmoid(
        x : in_type
    ) return out_type;
    
end package activation;


package body activation is

    function sigmoid(
        x : in_type
    ) return out_type is
        -- TODO: Automate the generation of these constant look-up
        -- parameters to be done at compile-time, based on their sizes.
        
        -- Boundaries beyond which linear approximation begins erring.
        constant UPPER_BOUND : in_type :=
            to_sfixed(+2.0625, in_type'high, in_type'low);
        constant LOWER_BOUND : in_type :=
            to_sfixed(-2.0625, in_type'high, in_type'low);
            
        constant LINEAR_M : in_type := -- M (the coefficient)
            to_sfixed(0.1875, in_type'high, in_type'low);
        constant LINEAR_C : in_type := -- C (the displacement)
            to_sfixed(0.5, in_type'high, in_type'low);
        
        -- Look-Up constants for when the input value falls beyond
        -- the Linear Approximation's acceptable error range.
        --
        -- NOTE: ZERO and ONE do not correspond to exactly 0.0 and 1.0;
        -- instead, they are a bit "leaky," similar to Sigmoid's output
        constant ZERO : out_type :=
            to_ufixed(0.0625, out_type'high, out_type'low);
        constant ONE  : out_type :=
            to_ufixed(0.9375, out_type'high, out_type'low);
            
        -- A temporary variable is required, because only VHDL-2019
        -- allows conditional assignment (i.e., when...else) in
        -- front of return statements, and we are using VHDL-2008.
        variable result : out_type;
    begin

        -- It is rather hard to implement exponents and logarithms
        -- in an FPGA; it would use too many logic blocks.  Even
        -- approximating Sigmoid using the absolute value would
        -- still require 'x' to be divided, very slowly, by (1 + |x|).
        -- So, a linear approximation is used instead.
        result := ZERO when x < LOWER_BOUND else
                  ONE  when x > UPPER_BOUND else
                  resize(to_ufixed((LINEAR_M * x) + LINEAR_C), result);
        
        return result;
        
    end function sigmoid;
    
end package body activation;

-- --------------------------------------------------------------------
-- END OF FILE: activation.vhd
-- --------------------------------------------------------------------