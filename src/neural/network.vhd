-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- network.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;

library work;  
    context work.neural_context;

library config;
    use config.constants.all;

entity network is
    generic (
        g_NETWORK_PARAMS  : network_layers;
        g_BATCH_SIZE      : positive;
        g_PIPELINE_STAGES : natural
    );
    port (
        i_inputs  : in  neural_bvector
            (0 to g_NETWORK_PARAMS(g_NETWORK_PARAMS'low).dims.cols-1);
        o_outputs : out neural_bvector
            (0 to g_NETWORK_PARAMS(g_NETWORK_PARAMS'high).dims.rows-1);
        /* Sequential (pipeline) controllers */
        i_clk     : in  std_ulogic; -- Clock
        i_rst     : in  std_ulogic; -- Reset
        i_fire    : in  std_ulogic; -- Start/fire up all the layesr
        o_done    : out std_ulogic  -- Is the network done processing?
    );
    
    constant NUM_LAYERS  : positive := g_NETWORK_PARAMS'length;
    -- Number of neurons in the first (i.e., input) layer.
    constant NUM_INPUTS  : positive := i_inputs'length;
    -- Number of neurons in the last (i.e., output) layer.
    constant NUM_OUTPUTS : positive := o_outputs'length;
end entity network;


architecture neural of network is
    
    -- Helper functions to "deflate" (or sanitize) max-sized arrays
    -- introduced due to the workaround around VHDL's lack of
    -- variable-sized elements in arrays.  You can find more details
    -- on the specifics of this workaround (and how to reverse it)
    -- in the file_parser.vhd file.
    function deflate( -- Arrays
        inflated_data : neural_vector;
        size_key      : natural
    ) return neural_vector is
        constant deflated_array : neural_vector (0 to size_key-1) :=
            inflated_data (0 to size_key-1);
    begin
        return deflated_array;
    end function deflate;

    function deflate( -- Matrices (i.e., Nested Arrays of Arrays)
        inflated_data : neural_matrix;
        size_key      : dimension
    ) return neural_matrix is
        variable deflated_matrix : neural_matrix
            (0 to size_key.rows-1) (0 to size_key.cols-1);
    begin
        deflate_rows : for i in deflated_matrix'range loop
            deflated_matrix(i) := -- Deflate individual sub-arrays.
                deflate(inflated_data(i), size_key.cols);
        end loop deflate_rows;
        
        return deflated_matrix;
    end function deflate;
    
    -- Unfortunately, VHDL has a language-level limitation where it
    -- does not allow you to refer back to a previous instance of a
    -- for-generate's local signals, even though you could manually
    -- "unroll" it into a single 'block' clause, containing mangled
    -- names of signals that cannot collision.  A solution is to
    -- employ the same max-dimension workaround from file_parser.vhd.
    -- Fortunately, the max-dimension has already been calculated by
    -- the file parser, earlier; we get to re-use it here.
    --     Unused/dummy elements would get discarded and optimized
    -- by the synthesizer, but this can still be very redundant
    -- and clunky, especially for nested arrays and very large ones.
    signal layers_done    : std_ulogic_vector (0 to NUM_LAYERS-1);
    -- This is a NESTED array of 'neural_bvector' (an array type).
    --
    -- NOTE: We cannot use the 'element attribute here; because
    -- each element of the parameter array is a record on its own,
    -- toolchains will break apart on such complicated expressions.
    signal layers_outputs : neural_bmatrix (0 to NUM_LAYERS-1)
        (0 to g_NETWORK_PARAMS(0).weights'length-1);
        
    -- The entire network is done whenever the last layer of it is.
    signal network_done    : std_ulogic;
    -- The output of the entire network is its layer layer's output.
    -- This could be arg-max'ed or used as-is, as needed.
    signal network_outputs : neural_bvector (0 to NUM_OUTPUTS-1);
begin

    -- NOTE: This is a "feed-forward" neural network, meaning that
    -- each layer's output is connected to the proceeding layer's
    -- input, in a chain-like formation.
    neural_network : for i in 0 to NUM_LAYERS-1 generate
        -- NOTE: These are intermediary signals to get around a VHDL
        -- limitation where you cannot have "conditionally mapped"
        -- port or generic maps (even in static for-generate clauses);
        -- we first assign the condition to a signal and then the port
        --     Because these are considered "concurrent" signal
        -- connections, there's no assignment or clock cycle delay.
        --     Also, in < VHDL-2019, you cannot define these as
        -- constants, because you cannot use when...else in them.
        -- TODO: See if we can somehow get the UNCONSTRAINED subtype
        -- of 'inputs' here, rather than hard-coding it.
        signal inputs_im : neural_bvector
            (0 to g_NETWORK_PARAMS(i).dims.cols-1);
        signal i_fire_im : i_fire'subtype;
        
        -- NOTE: in VHDL, you cannot constrain port assignments
        -- directly, because these would count as "locally non-static
        -- ranges," even though they are constants at compile-time;
        -- we have to constrain each generated instance's input here.
        constant sanitized_weights : neural_matrix := 
            deflate(
                g_NETWORK_PARAMS(i).weights,
                g_NETWORK_PARAMS(i).dims
            );
        constant sanitized_biases  : neural_vector := 
            deflate(
                g_NETWORK_PARAMS(i).biases,
                g_NETWORK_PARAMS(i).dims.rows         
            );
    begin
        -- NOTE: Somehow, using when...else instead of if..generate
        -- seems to result in indices such as -1; it seems that the
        -- condition after the 'else' part is "evaluated" even if 
        -- it is not suppoesd to be [i.e., when i=0, it tries to do
        -- i-1 and index the array as (-1)].
        input_layer_condition : if i = 0 generate
            inputs_im <= i_inputs;
            i_fire_im <= i_fire;
        else generate
            inputs_im <= layers_outputs(i-1)
                (0 to g_NETWORK_PARAMS(i).dims.cols-1);
            i_fire_im <= layers_done(i-1);
        end generate input_layer_condition; 
        
        neural_layer : entity work.layer (dense)
            generic map (
                -- NOTE: These arrays are "sliced" due to a workaround,
                -- which was used to bypass the lack of variable-sized
                -- arrays in VHDL; said workaround (explained in the
                -- file_parser.vhd file) would declare an array to be
                -- the "maximum" possible size (the biggest out of all
                -- its elements) and keep track of their "true" sizes
                -- in a separate field called .dims.  Here, we have
                -- simply sliced the "inflated" array, discarding the
                -- unused/dummy elements based on the true sizes.
                g_LAYER_WEIGHTS   => sanitized_weights,
                g_LAYER_BIASES    => sanitized_biases,
                g_BATCH_SIZE      => g_BATCH_SIZE,
                g_PIPELINE_STAGES => g_PIPELINE_STAGES
            )
            port map (
                i_inputs  => inputs_im,
                o_outputs => layers_outputs(i)
                    (0 to g_NETWORK_PARAMS(i).dims.rows-1),
                i_clk     => i_clk, -- Clock
                i_rst     => i_rst, -- Reset
                -- The first layer (i.e., the "input layer") will
                -- activate whenever the network is told to.
                -- Each subsequent layer will "fire" (i.e., activate)
                -- whenever its previous layer is "done" processing.
                i_fire    => i_fire_im,
                o_done    => layers_done(i) -- Is it done processing?
            );

    end generate neural_network;

    network_done    <= layers_done(layers_done'high);
    network_outputs <= layers_outputs(layers_outputs'high)
        (0 to NUM_OUTPUTS-1);

    -- The Network's 'done' signal is different than the that of the
    -- neurons in the sense that it "stays" done; that is to let us
    -- know that that it has finished its processing and remains IDLE,
    -- ready to accept another set of data.  Neurons' done signals
    -- lasted for a single clock cycle and then switched back to 0;
    -- because each layer's done signal was connected to the following
    -- layers' 'fire' signal, continuing to keep said layer's done 
    -- at 1 would result in proceeding layers never ending firing.
    
    toggle_out : process (i_clk, i_rst) is
        procedure perform_reset is
        begin
            o_done <= '1';
            o_outputs <= (others => (others => '0'));
        end procedure perform_reset;
    begin

        if not c_RST_SYNC and i_rst = c_RST_POLE then perform_reset;
        elsif rising_edge(i_clk) then
            if c_RST_SYNC and i_rst = c_RST_POLE then perform_reset;
            else

                if network_done = '1' then
                    o_done  <= '1';
                    o_outputs <= network_outputs;
                -- "elsif" so 'network_done' lasts at least one cycle.
                elsif i_fire = '1' then
                    o_done  <= '0';
                    o_outputs <= (others => (others => '0'));
                end if;
                
            end if;
        end if;
    end process toggle_out;
    
    /*
    toggle_out : process (all) is
    begin

        if network_done = '1' then
            o_done  <= '1';
            outputs <= network_outputs;
        -- "elsif" so 'network_done' lasts at least one cycle.
        elsif i_fire = '1' then
            o_done  <= '0';
            outputs <= (others => (others => '0'));
        end if;
                
    end process toggle_out;
    */
end architecture neural;


-- ---------------------------------------------------------------------
-- END OF FILE: network.vhd
-- ---------------------------------------------------------------------