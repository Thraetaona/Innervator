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
        g_NEURON_WEIGHTS  : neural_wvector;
        g_NEURON_BIAS     : neural_word;
        /* Sequential (pipeline) controllers */
        -- Number of inputs to be processed at a time (default = all)
        g_BATCH_SIZE      : positive := g_NEURON_WEIGHTS'length;
        -- Number of pipeline stages/cycle delays (defualt = none)
        g_PIPELINE_STAGES : natural := 0
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
    
    constant NUM_INPUTS : positive := i_inputs'length;
begin

    -- TODO: See if the 'instance_name or _path attributes are
    -- supported in Vivado synthesis; if so, use them here.
    assert g_NEURON_WEIGHTS'length mod g_BATCH_SIZE = 0
        report "Size of input data is not evenly divisble " &
               "by the given batch size."
            severity failure;
            
end entity neuron;


-- TODO: While anything with registers and flip-flops can be called
-- a pipeline, it might still not be very appropriate to call this
-- a pipelined neuron, because the actual registers are used to
-- resolve routing delays and, essentially, function as multi-cycle
-- paths.  (Revamp this to actually function like a pipeline.)
architecture pipelined of neuron is
    -- TODO: For UNJUSTIFIED reasons, you cannot declare a signal
    -- within a process' decleratory section, and yet variables can
    -- be FUNCTIONALLY the same, in case of counters.  While you
    -- could use 'block' clauses to wrap the process and have
    -- "locally scoped" signals that way, it is still going to add
    -- an extra indention nest, and it is not very ideal.
    -- TODO: Decide if we want to move these otherwise-local signals
    -- to become variables in their respective processes.  (One dis-
    -- advantage is that simulators might not show them in waveforms.)
    
    -- This is the pipeline's propagation delay counter.  For example,
    -- in a pipeline with 3 stages, the "external" input will take 
    -- 3 clock cycles to arrive "inside" the pipelined processor,
    -- and said processor's output (back to the external source)
    -- would also take 3 clock cycles to reach.
    --     Hence, we need to wait (i.e., count each cycle) until the
    -- data is fully loaded into the pipeline, in both directions.
    --     This might need a re-design to be more clear; the reason
    -- it starts at 1 is that the first batch in the pipeline will
    -- have already gotten filled in the "pre-processing" stage.
    signal pipe_delay : natural range 0 to g_PIPELINE_STAGES-1 := 1;
    -- Current iteration number (total number of
    -- iterations = number of data / size of batches).
    --
    -- Because the pipeline is always "ahead" of the processing
    -- multiplier by the number of stages (in clock cycles), 
    -- two separate indices are used to keep track.
    signal pipe_iter_idx : natural range 0 to NUM_INPUTS := 0;
    signal proc_iter_idx : natural range 0 to NUM_INPUTS := 0;
    
    -- The Neuron's Finite-State Machine (FSM)
    type neuron_state_t is (
        idle, initializing, processing, finalizing, activating, done
    );
    signal neuron_state : neuron_state_t := idle;
    
    -- This is the "localized" version of the input signal; given that
    -- our given input itself might reset or become cleared right after
    -- 'i_fire' is set to high, we need to sample and locally store the
    -- input at that time for later use within the processing stages.
    signal inputs_local  : i_inputs'subtype;
    -- These are the unregistered input and registered output signals.
    -- TODO: Somehow use 'subtype and 'element to derive these
    -- Input data (DSP input 1)
    signal inputs_unreg     : neural_bvector (0 to g_BATCH_SIZE-1);
    signal inputs_reg       : neural_bvector (0 to g_BATCH_SIZE-1);
    -- Weights (DSP input  2)
    signal weights_unreg    : neural_wvector (0 to g_BATCH_SIZE-1);
    signal weights_reg      : neural_wvector (0 to g_BATCH_SIZE-1);
    -- Internal DSP multiplier (product) pipeline
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
    signal products_unreg   : neural_dvector (0 to g_BATCH_SIZE-1);
    signal products_reg     : neural_dvector (0 to g_BATCH_SIZE-1);
    -- Multiplied-Accumulated weighted sum (DSP output)
    signal outputs_unreg    : neural_dvector (0 to g_BATCH_SIZE-1);
    signal outputs_reg      : neural_dvector (0 to g_BATCH_SIZE-1);
    -- The activation function (not batched)
    signal activation_unreg : neural_bit;
    signal activation_reg   : neural_bit;
    
    function activation_function(
        x : neural_dword
    ) return neural_bit is
    begin
        -- TODO: Automatically select between activations, as needed.
        return work.activation.sigmoid(x);
    end function activation_function;
    
    
    -- Yet another VHDL annoyance:
    --     stackoverflow.com/questions/31044965/
    --         procedure-call-in-loop-with-non-static-signal-name
    -- In short, procedures cannot take elements from array
    -- signals, such as test_sig(i), even if the index is
    -- static.  For that reason, we have to take indices
    -- rather than pre-indexed array elements.
    --
    -- Multiplier-Accumulator ("MAC")
    procedure multiply_accumulate(
        constant idx        : in  natural;
        signal   mul_a      : in  neural_wvector;
        signal   mul_b      : in  neural_bvector;
        signal   acc_in     : in  neural_dvector;
        signal   acc_out    : out neural_dvector;
        signal   prod_unreg : out neural_dvector;
        signal   prod_reg   : in  neural_dvector
    ) is
        variable products  : neural_dword;
        variable summation : neural_dword;
        
        -- NOTE: Unfortunately, procedures' 'out' parameters
        -- cannot be assigned to 'open', unlike actual entities/
        -- components; use dummies or placeholders as a workaround.
        variable dummy_carry : std_ulogic;
    begin
        products := resize(
            mul_a(idx)
            * -- Multiply
            resize( -- Resize, if needed
                to_sfixed(mul_b(idx)),
            mul_a(idx)),
        acc_in(idx));
        
        prod_unreg(idx) <= products;
        
        add_carry(
            L      => acc_in(idx),
            R      => prod_reg(idx),
            c_in   => '0',
            result => summation,
            c_out  => dummy_carry -- IGNORED!
        );    
            
        acc_out(idx) <= summation;
    end procedure multiply_accumulate;
    
    -- These cause simulation/synthesis mismatch
    /*
    procedure register_inputs is new core.pipeliner.registrar
        generic map (2, inputs'element);
        
    procedure register_weights is new core.pipeliner.registrar
        generic map (2, g_NEURON_WEIGHTS'element);  
    */
begin
    -- NOTE: This form of pipelining would only fix timing issues
    -- related to physical routing, not resource/logic consumption.
    --
    -- When g_PIPELINE_STAGES is 0, the _reg output and _unreg
    -- input get concurrently connected (with no delay).
    no_pipeline : if g_PIPELINE_STAGES = 0 generate
        create_pipeline : for i in 0 to g_BATCH_SIZE-1 generate
            inputs_reg(i)   <= inputs_unreg(i);
            weights_reg(i)  <= weights_unreg(i);
            products_reg(i) <= products_unreg(i);
            outputs_reg(i)  <= outputs_unreg(i);
        end generate create_pipeline;
        
        activation_reg      <= activation_unreg;
        
    else generate
        create_pipeline : for i in 0 to g_BATCH_SIZE-1 generate
            register_inputs   : entity core.pipeliner_single
                generic map (g_PIPELINE_STAGES, neural_bit)
                port map (i_clk, inputs_unreg(i), inputs_reg(i));
            register_weights  : entity core.pipeliner_single
                generic map (g_PIPELINE_STAGES, neural_word)
                port map(i_clk, weights_unreg(i), weights_reg(i));
            register_products : entity core.pipeliner_single
                generic map (g_PIPELINE_STAGES, neural_dword)
                port map(i_clk, products_unreg(i), products_reg(i));
            register_outputs  : entity core.pipeliner_single
                generic map (g_PIPELINE_STAGES, neural_dword)
                port map(i_clk, outputs_unreg(i), outputs_reg(i));
        end generate create_pipeline;
        
        register_activation   : entity core.pipeliner_single
            generic map (g_PIPELINE_STAGES, neural_bit)
            port map(i_clk, activation_unreg, activation_reg);
            
    end generate;

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
    --
    -- TODO: Improve the pipelining to actually overlap and be
    -- continuously fed from the input data. 
    neuron_loop : process (i_clk, i_rst) is
        -- NOTE: Use 'variable' as opposed to a 'signal' because these
        -- for-loops are supposed to unroll inside a _single_ tick of
        -- the Process, meaning that any subsequent assignments to
        -- a 'singal' accumulator would be DISCARDED; by using
        -- variables, we can resolve this issue.
        --
        -- NOTE: Somehow, using an initial value here adds a huge
        -- ~3 ns setup timing slack; this should NOT be happening!
        variable weighted_sum : neural_dword; --:=
          --resize(g_NEURON_BIAS, neural_dword'high, neural_dword'low);
        
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
                        neuron_state  <= idle;
                        
                        -- Reset back to default values
                        proc_iter_idx <= 0;
                        pipe_iter_idx <= g_BATCH_SIZE; -- 0 in the loop
                        pipe_delay    <= 1; -- 1 delay's accounted here

                        o_output      <= to_ufixed(0, o_output);
                        o_done        <= '0';
                        
                        weighted_sum  := -- Start with the Bias
                            resize(g_NEURON_BIAS, weighted_sum);
                            
                        inputs_local  <= (others =>
                            to_ufixed(0, inputs_local'element'high,
                                inputs_local'element'low)
                            );
                        -- Because we will be "adding" these before
                        -- they are truly filled with calculated
                        -- values, we initialize them to a known
                        -- (i.e., 0) value at first.
                        products_unreg <= (others =>
                            to_sfixed(0, products_unreg'element'high,
                                products_unreg'element'low)
                            );
                        outputs_unreg  <= (others =>
                            to_sfixed(0, outputs_unreg'element'high,
                                outputs_unreg'element'low)
                            );
                        /*
                        inputs_unreg   <= (others =>
                            to_ufixed(0, inputs_unreg'element));
                        weights_unreg  <= (others =>
                            to_sfixed(0, weights_unreg'element));
                        */
                        
                        if i_fire = '1' then
                            -- Save the external inputs (which
                            -- can change after i_fire).
                            inputs_local <= i_inputs;
                            
                            for i in 0 to g_BATCH_SIZE-1 loop
                                inputs_unreg(i)  <= i_inputs(i);
                                weights_unreg(i) <= g_NEURON_WEIGHTS(i);
                            end loop;
                        
                            -- NOTE: when pipeline stages == 1,
                            -- skip initializing and do the processing.
                            -- Switching cases counts as 1 delay itself
                            if g_PIPELINE_STAGES = 1 then
                                neuron_state <= processing;
                            else
                                neuron_state <= initializing;
                            end if;
                            
                        end if;
                    -- -------------------------------------------------
                    
                    -- Here, we "wait" (for a number of clock cycles
                    -- equal to pipeline stages) so that the first data
                    -- arrives through the pipeline; otherwise, the
                    -- weighted sum would have uninitialized values.
                    when initializing =>
                        neuron_state <= initializing;
                        
                        -- Even though we are "waiting," we should still
                        -- continue to fill the upcoming pipeline stages
                        --
                        -- TODO: Account for the scenario where the
                        -- pipeline stages exceed the number of inputs
                        -- (stop filling the pipeline at that point.)
                        for i in 0 to g_BATCH_SIZE-1 loop
                            inputs_unreg(i)  <=
                                inputs_local(pipe_iter_idx+i);
                            weights_unreg(i) <=
                                g_NEURON_WEIGHTS(pipe_iter_idx+i);
                        end loop;
                        pipe_iter_idx <= pipe_iter_idx + g_BATCH_SIZE;
                        
                        if (pipe_delay < g_PIPELINE_STAGES-1) then
                            pipe_delay <= pipe_delay + 1;
                        else
                            pipe_delay   <= 0; -- Reuse for 'finalizing'
                            neuron_state <= processing;
                        end if;
                    -- -------------------------------------------------
                    
                    when processing =>
                        neuron_state <= processing;
                    
                        -- TODO: Have a generic switch to toggle
                        -- between computing the activation function
                        -- DURING the last batch iteration (1 clock 
                        -- cycle less latency), or AFTER a clock cycle
                        -- passes, like now (better logic timing).
                        
                        -- NOTE: The pipeline still needs to be filled
                        -- at g_NUM_STAGES ahead-of-time, but it will
                        -- also need to stop sooner; this is why we
                        -- keep track and stop it separately.
                        -- TODO: Account for when batch processing's off
                        pipeline_unsaturated : if
                            pipe_iter_idx < NUM_INPUTS
                        then
                            for i in 0 to g_BATCH_SIZE-1 loop
                                -- Continue filling the pipeline, which
                                -- will eventually reach the multiplier
                                -- after a number of clock cycles (i.e.,
                                -- pipeline stages).
                                inputs_unreg(i)  <=
                                    inputs_local(pipe_iter_idx+i);
                                weights_unreg(i) <=
                                    g_NEURON_WEIGHTS(pipe_iter_idx+i);
                            end loop;
                            pipe_iter_idx <=
                                pipe_iter_idx + g_BATCH_SIZE;
                        end if pipeline_unsaturated;
                        
                        
                        -- NOTE: This loop is unrolled into actual
                        -- hardware; this is why we don't multiply
                        -- an entire matrix all in one pass (it
                        -- would be far too much in one clock cycle)
                        for i in 0 to g_BATCH_SIZE-1 loop
                            -- This is a running accumulator; the
                            -- result of the multiplication of each
                            -- weight by its associated input is
                            -- resized (IF NEEDED) to the size of
                            -- the Accumulator and then added to it
                            multiply_accumulate(
                                -- VHDL limitation workaround
                                idx        => i,
                                -- Numbers to multiply
                                mul_a      => weights_reg,
                                mul_b      => inputs_reg,
                                -- Accumulator
                                acc_in     => outputs_reg,
                                acc_out    => outputs_unreg,
                                -- Internal multiplier pipeline
                                prod_unreg => products_unreg,
                                prod_reg   => products_reg
                            );
                        end loop;
                        proc_iter_idx <= proc_iter_idx + g_BATCH_SIZE;
                        
                        -- NOTE: Short-circuited to one at compile-time
                        sum_calculated : if
                            -- Not processing in batches (iterate once)
                            (ITER_HIGH  = 0 and
                                proc_iter_idx /= 0) or
                            -- OR: Processing in batches
                            (ITER_HIGH /= 0 and
                                proc_iter_idx >= ITER_HIGH)
                        then
                            neuron_state <= finalizing;
                        end if sum_calculated;
                    -- -------------------------------------------------
                    
                    -- Here, similar to initializing, we will wait for
                    -- the pipelined OUTPUT to "catch up" and finish.
                    when finalizing =>
                        neuron_state <= finalizing;
                        
                        -- TODO: Do we also pipeline this?
                        for i in 0 to g_BATCH_SIZE-1 loop
                            weighted_sum := resize(
                                weighted_sum
                                + outputs_reg(i)
                                + products_reg(i),
                            weighted_sum);
                        end loop;
                        
                        if (pipe_delay < g_PIPELINE_STAGES-1) then
                            pipe_delay <= pipe_delay + 1;
                        else
                            pipe_delay   <= 0;
                            if g_PIPELINE_STAGES = 1 then
                                neuron_state <= done;
                            else
                                neuron_state <= activating;
                            end if;
                        end if;
                    -- -------------------------------------------------
                    
                    -- Wait for activation on the weighted sum.
                    -- (It is done here to avoid logic/gate delay
                    -- that'd occur in the previous case's branch,
                    -- because it also has to be pipelined.)
                    when activating =>
                        -- Activate only once
                        if pipe_delay = 0 then
                            activation_unreg <= 
                                activation_function(weighted_sum);
                        end if;
                                
                        if (pipe_delay < g_PIPELINE_STAGES-1) then
                            pipe_delay <= pipe_delay + 1;
                        else
                            neuron_state <= done;
                        end if;
                    -- -------------------------------------------------
                    
                    when done =>
                        o_output     <= activation_reg;
                            
                        -- Signal that we're no longer busy,
                        -- for a single clock cycle
                        o_done       <= '1';
                        
                        -- Back to idle state; await new data
                        neuron_state <= idle;
                    -- -------------------------------------------------
                    
                    -- Hardening in case of "unknown" states
                    when others => -- 1-clock-long cleanup phase
                        perform_reset;
                    -- -------------------------------------------------
                end case;
                
            end if;
        end if;
    end process neuron_loop;
    
         
         
end architecture pipelined;


-- ---------------------------------------------------------------------
-- END OF FILE: neuron.vhd
-- ---------------------------------------------------------------------