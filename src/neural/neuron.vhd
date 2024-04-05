-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- neuron.vhd is a part of Innervator.
-- --------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    --use ieee.math_real.MATH_E; -- NOT synthetizable; use as generics!

library config;
    use config.constants.all;
    context config.neural_context;


entity neuron is
    generic (
        g_NEURON_WEIGHTS : neural_array;
        g_NEURON_BIAS    : neural_word;
        -- Sequential (pipeline) controllers
        g_BATCH_SIZE     : positive := 2 -- #Inputs to neuron at a time
    );
    -- NOTE: There are also other types such as 'buffer' and the
    -- lesser-known 'linkage' but they are very situation-specific.
    port (
        inputs : in  neural_array; -- NOTE: Unconstrained
        output : out neural_bit; -- The "Action Potential"
        -- Sequential (pipeline) controllers
        i_clk  : in  std_ulogic; -- Clock
        i_rst  : in  std_ulogic; -- Reset
        i_fire : in  std_ulogic; -- Start/fire up the neuron
        o_busy : out std_ulogic -- Are we done processing the batch?
    );
end entity neuron;

architecture activation of neuron is
    constant NUM_DATA : positive := g_NEURON_WEIGHTS'length;
    
    -- Receiver's Finite-State Machine (FSM)
    type neuron_state_t is (
        idle, busy, done
    );
    signal neuron_state : neuron_state_t := idle;
    
    signal data_index : natural range 0 to NUM_DATA-1 := 0;
    
    
    
    -- Pipeline registers
    signal input_a_reg : neural_word;
    signal input_b_reg : neural_word;
    signal product     : neural_dword;
    signal product_reg : neural_dword;
    
    
    
    
    
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
        -- So, a linear approximation is used instead.
        y <= ZERO when x < LOWER_BOUND else
             ONE  when x > UPPER_BOUND else
             resize(to_ufixed((LINEAR_M * x) + LINEAR_C), y);
        
    end procedure;
begin


    assert g_NEURON_WEIGHTS'length mod g_BATCH_SIZE = 0
        report "Input data's size is not evenly divisble " &
               "by the given batch size."
            severity failure;


    -- NOTE: Combinational (i.e., un-clocked and stateless) logic,
    -- sensitive only to changes in inputs, will be much "faster" and
    -- perform everything in a SINGLE clock cycle.  However, it will
    -- also use a much, much higher number of logic blocks in the FPGA,
    -- meaning that a single neuron with 64 inputs could potentially
    -- take up 10% of a small FPGA's (e.g., Artix-7) LUT blocks.
    --     A workaround is to convert the combination logic to a 
    -- sequential (i.e., clocked and stateful) one, where weighted sums
    -- are calculated in small "batches" in each clock cycle; this
    -- does have the disadvantage of requiring MULTIPLE clock cycles
    -- for the entire calculation to be done (e.g., for 64 inputs and
    -- a 100MHz clock, the combinational approach would take 10ns while
    -- the sequential one, with segments of 2, might take 320ns).
    -- Additionally, if you go with the combination approach while
    -- keeping track of the previous states, you can introduce latches.
    -- Lastly, if you go with the sequential approach, you also need to
    -- have additional communication mechanism with the external logic
    -- to let them know whenever this neuron is done processing its
    -- batch or whenever it should begin processing the given batch;
    -- otherwise, since your sequential process is already clocked and
    -- you can't use the 'input' signal's event in its sensitivity list
    -- you would have to maintain its previous states and compare them.
    process (i_clk, i_rst) is
        -- NOTE: Use 'variable' as opposed to a 'signal' because these
        -- for-loops are supposed to unroll inside a _single_ tick of
        -- the Process, meaning that any subsequent assignments to
        -- a 'singal' accumulator would be DISCARDED; by using
        -- variables, we can resolve this issue.
        --
        -- NOTE: If you are using a very small (i.e., < 4) number of
        -- bits for either the integral or fractional part, you may
        -- consider using a slightly larger multiple of the _word type
        -- (e.g., neural_word or neural_qword) here for the accumulator
        -- to accomodate for the many additions that occur within
        -- the inner for-loop and would otherwise overflow.  After the
        -- activation function/clamping takes place, and the variable
        -- gets its range restricited within [0, 1), we can safely
        -- resize it back to a smaller bit width.
        --     Also, this might result in the synthesizer using
        -- available DSP (dedicated multiplier) blocks on your
        -- FPGA, which would conserve other logic resources.
        variable weighted_sum : neural_dword :=
            to_sfixed(0, neural_dword'high, neural_dword'low);
            
        -- NOTE: Unfortunately, procedures' 'out' parameters
        -- cannot be assigned to 'open', unlike actual entities/
        -- components; use dummies or placeholders as a workaround.
        variable dummy_carry : std_ulogic := '-';
        
        procedure perform_reset is
        begin
            neuron_state <= idle;
        end procedure perform_reset;
    begin

        if not c_RST_SYNC and i_rst = c_RST_POLE then perform_reset;
        elsif rising_edge(i_clk) then
            if c_RST_SYNC and i_rst = c_RST_POLE then perform_reset;
            else
            
                case neuron_state is
                    when idle =>
                        neuron_state <= idle;
                        
                        -- Reset back to default values
                        output       <= (others => '0');
                        o_busy       <= '0';
                        data_index   <= 0;
                        
                        weighted_sum := (others => '0');
                        if i_fire = '1' then
                            neuron_state <= busy;
                        end if;
                    -- ------------------------------------------------
                    
                    when busy =>
                        neuron_state <= busy;
                        
                        o_busy       <= '1';
                    
                        data_left : if 
                            data_index < (NUM_DATA - g_BATCH_SIZE)
                        then
                            -- NOTE: These loops are unrolled
                            -- into actual hardware.
                            for i in 0 to g_BATCH_SIZE - 1 loop
                                -- This is a running accumulator; the
                                -- result of the multiplication of each
                                -- weight by its associated input is
                                -- resized (IF NEEDED) to the size of
                                -- the Accumulator and then added to i
                                
                                
                                
                                
                                input_a_reg <= g_NEURON_WEIGHTS(data_index+i);
                                input_b_reg <= inputs(data_index+i);
                                
                                product <= resize(input_a_reg *  input_b_reg, product);
                                
                                product_reg <= product;
                                
                                /*
                                add_carry(
                                    L      => weighted_sum,
                                    R      => product_reg,
                                    c_in   => '0',
                                    result => weighted_sum,
                                    c_out  => dummy_carry
                                );
                                */
                                
                                
                                weighted_sum := resize(
                                    weighted_sum
                                    +
                                    product_reg,
                                weighted_sum);
                                
                                
                            end loop;
                            
                            data_index <= data_index + g_BATCH_SIZE;
                            
                        else
                            -- Add the final bias to the weighted sum
                            /*add_carry(
                                L      => weighted_sum,
                                R      => resize(g_NEURON_BIAS,
                                    weighted_sum),
                                c_in   => '0',
                                result => weighted_sum,
                                c_out  => dummy_carry
                            );*/
                            
                            weighted_sum := resize(weighted_sum +
                                resize(g_NEURON_BIAS, weighted_sum),
                            weighted_sum);
                            
                            -- Perform activation on the weighted sum
                            activation_function(
                                x => weighted_sum,
                                y => output
                            );
                        
                            data_index   <= 0;
                            neuron_state <= done;
                        end if data_left;
                    -- ------------------------------------------------
    
                    when done =>
                        -- Signal that we're no longer busy
                        -- for (at least) 1 clock cycle
                        o_busy     <= '0';
                        
                        neuron_state <= idle;
                    -- ------------------------------------------------
                        
                    -- Hardening in case of "unknown" states    
                    when others => -- 1-clock-long cleanup phase
                        perform_reset;
                    -- ------------------------------------------------
                end case;
                
            end if;
        end if;
    end process;
            
end architecture activation;


-- --------------------------------------------------------------------
-- END OF FILE: neuron.vhd
-- --------------------------------------------------------------------