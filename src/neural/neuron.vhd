-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- neuron.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;
  
library work;  
    context work.neural_context;

library config;
    use config.constants.all;

library core;

-- TODO: Generically 'type' these, at least in VHDL-2019.
entity neuron is
    generic (
        g_NEURON_WEIGHTS : neural_wvector;
        g_NEURON_BIAS    : neural_word;
        /* Sequential (pipeline) controllers */
        -- Number of inputs to be processed at a time (default = all)
        g_BATCH_SIZE     : positive := g_NEURON_WEIGHTS'length
    );
    -- NOTE: There are also other types such as 'buffer' and the
    -- lesser-known 'linkage' but they are very situation-specific.
    -- NOTE: Apparently, it is better to use Active-High (like o_done
    -- when '1' instead of o_busy '1') internal signals in most FPGAs.
    port (
        -- NOTE: Do NOT name these as mere 'input' or 'output' because
        -- std.textio also defines those, and they can conflict.
        i_inputs : in  neural_bvector (0 to g_NEURON_WEIGHTS'length-1);
        o_output : out neural_bit; -- The "Action Potential"
        /* Sequential (pipeline) controllers */
        i_clk    : in  std_ulogic; -- Clock
        i_rst    : in  std_ulogic; -- Reset
        i_fire   : in  std_ulogic; -- Start/fire up the neuron
        o_done   : out std_ulogic  -- Are we done processing the batch?
    );
    
    constant NUM_INPUTS : positive := inputs'length;
begin

    -- TODO: See if the 'instance_name or _path attributes are
    -- supported in Vivado synthesis; if so, use them here.
    assert g_NEURON_WEIGHTS'length mod g_BATCH_SIZE = 0
        report "Size of input data is not evenly divisble " &
               "by the given batch size."
            severity failure;
            
end entity neuron;


architecture pipelined of neuron is   
    -- The Neuron's Finite-State Machine (FSM)
    type neuron_state_t is (
        idle, busy, done
    );
    type pipeline_substate_t is (
        idle, pre_processing, processing, post_processing, done
    );
    signal neuron_state      : neuron_state_t := idle;
    signal pipeline_substate : pipeline_substate_t := idle;
    
    -- This is the "registered" version of the input signal; given that
    -- our given input itself might reset or become cleared right after
    -- 'i_fire' is set to high, we need to sample and locally store the
    -- input at that time for later use within the processing stages.
    signal inputs_local : i_inputs'subtype;
    
    -- Current iteration number (total number of
    -- iterations = number of data / size of batches).
    signal iter_idx : natural range 0 to NUM_INPUTS;
    
    
    function activation_function(
        x : neural_dword
    ) return neural_bit is
    begin
        -- TODO: Automatically select between activations, as needed.
        return work.activation.sigmoid(x);
    end function activation_function;
    
    
    -- Multiplier-Accumulator ("MAC")
    procedure mac_unit(
        signal value_a   : in  neural_word;
        signal value_b   : in  neural_bit;
        variable sum_in  : in  neural_dword;
        variable sum_out : out neural_dword
    ) is
    begin
        sum_out := resize( -- Current sum
            sum_in -- Previous sum
            + -- Add
            resize(
                value_a
                * -- Multiply
                resize( -- Resize, if needed
                    to_sfixed(value_b),
                value_a),
            sum_in),
        sum_out);     
    end procedure mac_unit;
    
    signal inputs_unreg  : i_inputs'element;
    signal weights_unreg : g_NEURON_WEIGHTS'element;
    signal inputs_reg    : i_inputs'element;
    signal weights_reg   : g_NEURON_WEIGHTS'element;
    
    /*
    procedure register_inputs is new core.pipeliner.registrar
        generic map (2, inputs'element);
        
    procedure register_weights is new core.pipeliner.registrar
        generic map (2, g_NEURON_WEIGHTS'element);  
    */
begin

    --register_inputs(i_clk, inputs_unreg, inputs_reg);
    --register_weights(i_clk, weights_unreg, weights_reg);

    register_inputs : entity core.pipeliner_single
        generic map (1, neural_bit)
        port map (i_clk, inputs_unreg, inputs_reg);
    register_weights : entity core.pipeliner_single
        generic map (1, neural_word)
        port map(i_clk, weights_unreg, weights_reg);

    -- NOTE: This form of pipelining would only fix timing issues,
    -- not resource/logic consumption.  A superior form of pipelining
    -- is now used instead of this; that one fixes the timing and
    -- resource issues at the same time.
    /*
    
    procedure register_input is new core.pipeliner.registrar
        generic map (3, neural_word);
        
    procedure register_output is new core.pipeliner.registrar
        generic map (3, neural_dword);    
    
    -- Pipeline registers
    signal weights_unreg : neural_wvector (g_BATCH_SIZE-1 downto 0);
    signal inputs_unreg  : neural_wvector (g_BATCH_SIZE-1 downto 0);
    -- MAC = Multiply-Accumulate [A <= A + (B * C)] 
    signal products_unreg    : neural_dword;
    
    signal weights_reg : neural_wvector (g_BATCH_SIZE-1 downto 0);
    signal inputs_reg  : neural_wvector (g_BATCH_SIZE-1 downto 0);
    signal products_reg    : neural_dword;    
    
    -- TODO Generically turn pipeline on/off (stackoerflow raticle)
    initialize_pipeline : for i in 0 to g_BATCH_SIZE-1 generate
    
        register_input(i_clk, inputs_unreg(i), inputs_reg(i));
        register_input(i_clk, weights_unreg(i), weights_reg(i));
        register_output(i_clk, products_unreg(i), products_reg(i));
        
    end generate initialize_pipeline;
    */



    -- NOTE: Combinational (i.e., un-clocked and stateless) logic,
    -- sensitive only to changes in inputs, will be much "faster" and
    -- perform everything in a SINGLE clock cycle.  However, it will
    -- also use a much, much higher number of logic blocks in the FPGA,
    -- meaning that a single neuron with 64 inputs could potentially
    -- take up 10% of a small FPGA's (e.g., Artix-7) LUTs.
    --     A workaround is to convert the combination logic to a 
    -- sequential (i.e., clocked and stateful) one, where weighted sums
    -- are calculated in small "batches" in each clock cycle; this
    -- does have the disadvantage of requiring MULTIPLE clock cycles
    -- for the entire calculation to be done (e.g., for 64 inputs and
    -- a 100MHz clock, the combinational approach would take 10ns while
    -- the sequential one, with segments of 2, might take 320+20ns).
    --     Additionally, if you go with the combination approach while
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
        --
        -- NOTE: Somehow, using an initial value here adds a huge
        -- ~3 ns setup timing slack; this should NOT be happening!
        variable weighted_sum : neural_dword; --:=
          --resize(g_NEURON_BIAS, neural_dword'high, neural_dword'low);
            
        -- NOTE: Unfortunately, procedures' 'out' parameters
        -- cannot be assigned to 'open', unlike actual entities/
        -- components; use dummies or placeholders as a workaround.
        -- TODO: Use this whenever IEEE's 'add_carry' gets fixed.
        --variable dummy_carry : std_ulogic;
        
        -- Number of iterations (if batch processing is enabled)
        constant ITER_HIGH : natural := NUM_INPUTS - g_BATCH_SIZE;

        
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
                        o_output        <= to_ufixed(0, o_output);
                        o_done        <= '0';
                        inputs_local  <=
                            (others => to_ufixed(0, inputs_unreg));
                        
                        inputs_unreg  <= to_ufixed(0, inputs_unreg);
                        weights_unreg <= to_sfixed(0, weights_unreg);
                        iter_idx      <= g_BATCH_SIZE;
                        weighted_sum  := 
                            resize(g_NEURON_BIAS, weighted_sum);
                            
                        if i_fire = '1' then
                            inputs_local  <= i_inputs;
                            inputs_unreg  <= i_inputs(0);
                            weights_unreg <= g_NEURON_WEIGHTS(0);
                            
                            neuron_state <= busy;
                        end if;
                    -- -------------------------------------------------
                    
                    when busy =>
                        neuron_state <= busy;
                        
                        -- TODO: Have SUB state-machines here
                        -- TODO: Also pipeline the "P" DSP output
                        a
                        
                        
                        -- TODO: Have a generic switch to toggle
                        -- between computing the activation function
                        -- DURING the last batch iteration (1 clock 
                        -- cycle less latency), or AFTER a clock cycle
                        -- passes, like now (better logic timing).

                        -- NOTE: This loop is unrolled
                        -- into actual hardware.
                        for i in 0 to g_BATCH_SIZE-1 loop
                            -- This is a running accumulator; the
                            -- result of the multiplication of each
                            -- weight by its associated input is
                            -- resized (IF NEEDED) to the size of
                            -- the Accumulator and then added to it

                            -- IEEE's add_carry() seems broken.
                            /*
                            add_carry(
                                L      => weighted_sum,
                                R      => product_reg,
                                c_in   => '0',
                                result => weighted_sum,
                                c_out  => dummy_carry -- IGNORED!
                            );
                            */
                              
                            inputs_unreg  <= inputs_local(iter_idx+i);
                            weights_unreg <=
                                g_NEURON_WEIGHTS(iter_idx+i);                            
                            
                            -- Fused Multiply-Adder
                            /*weighted_sum := resize(
                                weighted_sum
                                + -- Add
                                resize(
                                    weights_reg
                                    * -- Multiply
                                    resize( -- Resize, if needed
                                        to_sfixed(
                                            inputs_reg
                                        ),
                                    g_NEURON_WEIGHTS'element'high,
                                    g_NEURON_WEIGHTS'element'low),
                                weighted_sum),
                            weighted_sum);*/
                            
                            mac_unit(
                                value_a => weights_reg,
                                value_b => inputs_reg,
                                sum_in  => weighted_sum,
                                sum_out => weighted_sum
                            );
                            
                        end loop;
                                 
                        iter_idx <= iter_idx + g_BATCH_SIZE;
                        
                        -- NOTE: Short-circuited to one at compile-time
                        sum_calculated : if
                            -- Not processing in batches (iterate once)
                            (ITER_HIGH  = 0 and iter_idx /= 0) or
                            -- OR: Processing in batches
                            (ITER_HIGH /= 0 and iter_idx >= ITER_HIGH)
                        then
                            --iter_idx     <= 0;
                            neuron_state <= done;
                        end if sum_calculated;
                    -- -------------------------------------------------
    
                    when done =>
                        -- Perform activation on the weighted sum.
                        -- (It is done here to avoid logic/gate delay
                        -- that'd occur in the previous case's branch)
                        o_output       <= 
                            activation_function(weighted_sum);
                            
                        -- Signal that we're no longer busy,
                        -- for (at least) 1 clock cycle
                        o_done       <= '1';
                        
                        -- Go back to the idle state and await new data
                        neuron_state <= idle;
                    -- -------------------------------------------------
                        
                    -- Hardening in case of "unknown" states
                    when others => -- 1-clock-long cleanup phase
                        perform_reset;
                    -- -------------------------------------------------
                end case;
                
            end if;
        end if;
    end process;
            
            
    process (i_clk, i_rst) is
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
                                
                end case;
                
            end if;
        end if;
    end process;
         
end architecture pipelined;


-- ---------------------------------------------------------------------
-- END OF FILE: neuron.vhd
-- ---------------------------------------------------------------------