-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- neuron.vhd is a part of Innervator.
-- --------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    --use ieee.math_real.MATH_E; -- NOT synthetizable; use as generics!

library config;
    context config.neural_context;


entity neuron is
    generic (
        NEURON_WEIGHTS : neural_array;
        NEURON_BIAS    : neural_word
    );
    -- NOTE: There are also other types such as 'buffer' and the
    -- lesser-known 'linkage' but they are very situation-specific.
    port (
        inputs : in neural_array; -- NOTE: Unconstrained
        output : out neural_bit -- The "Action Potential"
    );

    --attribute dont_touch : string;
    --attribute dont_touch of neuron : entity is "true";
end entity neuron;

architecture activation of neuron is

    -- Being a procedure instead of a pure function will help save a
    -- an intermediate signal/variable from having to be used.
    procedure activation_function(
        variable x : in neural_dword;
        signal   y : out neural_bit
    ) is 
        -- TODO: Automate the generation of these constant look-up
        -- parameters to be done at compile-time, based on their sizes.
        
        -- Boundaries beyond which linear approximation begins erring.
        constant UPPER_BOUND : neural_dword :=
            to_sfixed(+2.0625, neural_dword'high, neural_dword'low);
        constant LOWER_BOUND : neural_dword :=
            to_sfixed(-2.0625, neural_dword'high, neural_dword'low);
            
        constant LINEAR_M : neural_dword := -- M (the coefficient)
            to_sfixed(0.1875, neural_dword'high, neural_dword'low);
        constant LINEAR_C : neural_dword := -- C (the displacement)
            to_sfixed(0.5, neural_dword'high, neural_dword'low);
        
        -- Look-Up constants for when the input value falls beyond
        -- the Linear Approximation's acceptable error range.
        -- NOTE: ZERO and ONE do not correspond to exactly 0.0 and 1.0;
        -- instead, they are a bit "leaky," similar to Sigmoid's output  
        constant ZERO : neural_bit :=
            to_ufixed(0.0625, neural_bit'high, neural_bit'low);
        constant ONE  : neural_bit :=
            to_ufixed(0.9375, neural_bit'high, neural_bit'low);
    begin

        -- It is rather hard to implement exponents and logarithms
        -- in an FPGA; it would use too many logic blocks.  Even
        -- approximating Sigmoid using the absolute value would
        -- still require 'x' to be divided, very slowly, by (1 + |x|).
        y <= ZERO when x < LOWER_BOUND else
             ONE  when x > UPPER_BOUND else
             resize(to_ufixed((LINEAR_M * x) + LINEAR_C), y);
        
    end procedure;
begin

    -- Combinational (i.e., un-clocked and stateless) logic
    -- sensitive only to changes in inputs.
    process (inputs) is
        -- NOTE: Use 'variable' as opposed to a 'signal' because these
        -- for-loops are supposed to run inside a _single_ tick of
        -- the Process, meaning that any subsequent assignments to
        -- a 'singal' accumulator would be DISCARDED; by using
        -- variables, we can resolve this issue.
        --
        -- NOTE: If you are using a very small (i.e., < 4) number of
        -- bits for either the integral or fractional part, you may
        -- consider using a slightly larger multiple of the _word 
        -- type (e.g., neural_word or neural_qword) here, for the 
        -- accumulator, to accomodate for the many additions that occur
        -- within the inner for-loop and would otherwise overflow.
        -- After the activation function/clamping takes place, and
        -- the variable gets its range restricited within [0, 1),
        -- we can safely resize it back to a smaller bit width.
        variable weighted_sum : neural_dword :=
            to_sfixed(0, neural_dword'high, neural_dword'low);
            
        -- NOTE: Unfortunately, procedures' 'out' parameters
        -- cannot be assigned to 'open', unlike actual entities/
        -- components; use dummies or placeholders as a workaround.
        variable dummy_carry : std_ulogic := '-';
    begin
        for i in 0 to inputs'high loop
            -- This is a running accumulator in which the result 
            -- of the multiplication of each [weight by an associated 
            -- input] is resized (IF NEEDED) to the size of the
            -- Accumulator and then added to it.
            /*add_carry(
                L      => weighted_sum,
                R      => resize(NEURON_WEIGHTS(i) * inputs(i), weighted_sum),
                c_in   => '0',
                result => weighted_sum,
                c_out  => dummy_carry
            );*/  
            weighted_sum := resize(weighted_sum +
                resize(NEURON_WEIGHTS(i) * inputs(i), weighted_sum),
            weighted_sum);
            
        end loop;
        
        -- Add the final bias
        /*add_carry(
            L      => weighted_sum,
            R      => resize(NEURON_BIAS, weighted_sum),
            c_in   => '0',
            result => weighted_sum,
            c_out  => dummy_carry
        );*/
        weighted_sum := resize(weighted_sum +
            resize(NEURON_BIAS, weighted_sum),
        weighted_sum);
        
        activation_function(
            x => weighted_sum,
            y => output
        );

    end process;
    
end architecture activation;


-- --------------------------------------------------------------------
-- END OF FILE: neuron.vhd
-- --------------------------------------------------------------------