-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- math.vhd is a part of Innervator.
-- ---------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
  
library neural;  
    context neural.neural_context;


-- TODO: Implement more activation functions (e.g., ReLU, etc.)
package math is

    -- Returns the index of the highest number in an unsigned array.
    -- TODO: What if two numbers are equal?
    -- TODO: Maybe provide a pipelined/multi-cycle variant.
    function arg_max(
        values : neural_bvector
    ) return natural;
    
end package math;


package body math is

    function arg_max(
        values : neural_bvector
    ) return natural is
        variable max_index   : natural;
        variable current_max : neural_bvector'element;
    begin
    
        current_max := (others => '0');

        for i in values'range loop
            if values(i) > current_max then
                max_index := i;
                current_max := values(i);
            end if;
        end loop;
        
        return max_index;
    end function arg_max;
    
end package body math;

-- ---------------------------------------------------------------------
-- END OF FILE: math.vhd
-- ---------------------------------------------------------------------