-- --------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- layer.vhd is a part of Innervator.
-- --------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;

library work;  
    context work.neural_context;

library config;
    use config.constants.all;


-- TODO: Generically 'type' these, at least in VHDL-2019.
entity layer is
    generic (
        g_LAYER_WEIGHTS : neural_matrix;
        g_LAYER_BIASES  : neural_vector;
        /* Sequential (pipeline) controllers */
        -- Number of inputs to be processed at a time (default = all)
        g_BATCH_SIZE    : positive := g_LAYER_WEIGHTS'element'length
    );
    port (
        inputs  : in  neural_bvector
            (0 to g_LAYER_WEIGHTS'element'length-1);
        outputs : out neural_bvector
            (0 to g_LAYER_WEIGHTS'length-1);
        /* Sequential (pipeline) controllers */
        i_clk   : in  std_ulogic; -- Clock
        i_rst   : in  std_ulogic; -- Reset
        i_fire  : in  std_ulogic; -- Start/fire up all the neurons
        o_done  : out std_ulogic  -- Are we done processing the layer?
    );
    
    -- NOTE: This assumes that the upper hierarchy (i.e., network)
    -- supplies the sanitized/actual slices of the layer's parameters.
    constant NUM_INPUTS  : positive := inputs'length;
    -- NOTE: This one is also the number of "neurons" in this layer.
    constant NUM_OUTPUTS : positive := outputs'length;
end entity layer;


architecture dense of layer is -- [Structural arch.]
    signal neurons_done : 
        std_ulogic_vector (0 to NUM_OUTPUTS-1);
begin
        
    neural_layer : for i in 0 to NUM_OUTPUTS-1 generate
        neuron_instance : entity work.neuron
            generic map (
                g_NEURON_WEIGHTS => g_LAYER_WEIGHTS(i),
                g_NEURON_BIAS    => g_LAYER_BIASES(i),
                g_BATCH_SIZE     => g_BATCH_SIZE
            )
            port map (
                inputs => inputs,
                output => outputs(i),
                i_clk  => i_clk,
                i_rst  => i_rst,
                i_fire => i_fire,
                o_done => neurons_done(i)
            );
    end generate neural_layer;
    
    -- TODO: Decide if the Layer's busy signal should be based
    -- on ALL neurons' busy signals (or just one of them?)
    --o_busy <= '0' when (neurons_done = (others => '0')) else
    --          '1' when (neurons_done = (others => '1'));
    o_done <= neurons_done(0);
    
end architecture dense;


-- --------------------------------------------------------------------
-- END OF FILE: layer.vhd
-- --------------------------------------------------------------------