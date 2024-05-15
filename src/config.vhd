-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- config.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


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
    -- NOTE: Apparently, some FPGAs (e.g., Xilinx 7 series) work better
    -- (internally) with active-high resets, because their flip-flops
    -- were designed to take reset signals as so, and using active-low
    -- would require an inverter before each flip-flop's SR port; yet,
    -- board vendors might use negative/active-low signals for their
    -- reset buttons, because electronics are designed easier that way.
    -- If we have no control over the (external) polarity of our reset
    -- signal, a solution is to place a single inverter in the top-
    -- level hierarchy of the I/O pin logic ("IOB") & use that instead.
    -- SEE:
    --     ednasia.com/coding-consideration-for-pipeline-flip-flops
    --     01signal.com/electronics/iob-registers
    --
    --     Also, you might want to "synchronize" (i.e., de-glitch, NOT
    -- related to sync./async. types of reset) and possibly debounce,
    -- if it is a button, your external reset signal prior to using it.
    -- signal.
    constant c_RST_INVT : boolean    := true; -- Invert ext. reset pin?
    constant c_RST_POLE : std_ulogic := '0';  -- '0' = int. neg. reset
    constant c_RST_SYNC : boolean    := true; -- false = async. reset
    -- TODO: Have a constant that chooses rising_ or falling_edge
    --constant c_EDG_RISE 
    /* Internal Fixed-Point Sizing */
    constant c_WORD_INTG   : natural  := 4;
    constant c_WORD_FRAC   : natural  := 4;
    constant c_WORD_SIZE   : positive := c_WORD_INTG + c_WORD_FRAC;
    constant c_GUARD_BITS  : natural  := 0;
    constant c_FIXED_ROUND : fixed_round_style_type    :=
        fixed_truncate;
    constant c_FIXED_OFLOW : fixed_overflow_style_type :=
        fixed_saturate;
    /* Neuron Settings */
    -- Number of data to be concurrently processed in a single neuron
    -- (More = Faster network, at the expense of more FPGA logic usage)
    -- TODO: Make this an array to configure each layer/neuron.
    constant c_BATCH_SIZE : positive := 1; -- < or = to data's length.
    -- TODO: Add options to select between executing the activation
    -- function and/or setting the done signal inside or outside
    -- the neurons' busy state. (Speed/Size trade-off)
    /* UART Parameters */
    -- NOTE: Bitrate = Baud, in the digital world
    constant c_BIT_RATE : positive := 9_600;
    constant c_BIT_PERD : time     := 1 sec / c_BIT_RATE;
end package constants;


-- ---------------------------------------------------------------------
-- END OF FILE: config.vhd
-- ---------------------------------------------------------------------