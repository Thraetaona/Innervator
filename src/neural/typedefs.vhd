-- ---------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- neural_typedefs.vhd is a part of Innervator.
-- ---------------------------------------------------------------------


-- NOTE: You NEED to re-declare used libraries AFTER you instantiate
-- the packages here; otherwise, basic types like "std_logic" will not
-- get recognized!  This is because VHDL's and Ada's ancient compilers
-- were "one-pass" and did not keep track of contexes.  See:
-- https://insights.sigasi.com/tech/use-and-library-vhdl/
--library work, std, ieee;

library ieee;

library config;
    use config.constants.all;

-- TODO: Provide an option to use unsigned types, too.
package fixed_neural_pkg is
    generic (
        -- NOTE: these two generic numbers should NOT be taken as
        -- generics, because Vivado 2023.2 has a bug where it throws
        -- random error messages if types, which are defined in a 
        -- generic package based on generic parameters, are used
        -- outside; this is not a problem with VHDL or the code but
        -- with Vivado itself, as always.  The solution is to
        -- "hard-code" them as constants from a global config file.
        --g_INTEGRAL_BITS, g_FRACTIONAL_BITS : natural;
        package g_FIXED_PKG_INSTANCE is new ieee.fixed_generic_pkg
            generic map ( <> ) -- VHDL-2008 Formal Generic Package
    );
    use g_FIXED_PKG_INSTANCE.all; -- Import our custom fixed_pkg
    
    -- Vivado bug workaround (see the note above)
    constant g_INTEGRAL_BITS   : natural := c_WORD_INTG;
    constant g_FRACTIONAL_BITS : natural := c_WORD_FRAC;
    
    -- NOTE: A word is the "primary" size of values that we are
    -- going to use.  Also, historically, a byte was the number
    -- of bits used to encode a character of text in a computer.
    -- SEE: https://en.wikipedia.org/wiki/Units_of_information
    --
    -- NOTE: In fixed-point arithmetic, the "Q" notation is used to
    -- indicate the minimum number of bits required to represent a
    -- range of values. For example, signed Q0.7 uses 1 bit for the
    -- signdedness, 0 bit for  the integer part, and 7 bits for the
    -- fractional part.  Similarly, unsigned Q2.5 represents 2
    -- integer and 5 fractional bits.
    -- See: inst.eecs.berkeley.edu/~cs61c/sp06/handout/fixedpt.html
    --
    -- NOTE: Bit Width = |INTEGRAL_BITS| + |FRACTIONAL_BITS|; the
    -- integral (i.e., whole) part comprises of [INTEGRAL_BITS-1,
    -- 0] and the fractional (i.e., after the .decimal point)
    -- comprises of [-1, -FRACTIONAL_BITS]


    /*
        Types derived from the generically given specifications
    */
    
    /* Scalars */
    subtype neural_bit    is -- An "analogue" bit with the range [0, 1)
        u_ufixed (-1 downto -(g_FRACTIONAL_BITS*2)); -- UNSIGNED and <1
    subtype neural_nibble is -- Half-word
        u_sfixed ((g_INTEGRAL_BITS/2)-1 downto -(g_FRACTIONAL_BITS/2));
    subtype neural_word   is -- Full-word
        u_sfixed (g_INTEGRAL_BITS-1 downto -g_FRACTIONAL_BITS);
    subtype neural_dword  is -- Double-word
        u_sfixed ((g_INTEGRAL_BITS*2)-1 downto -(g_FRACTIONAL_BITS*2));
    subtype neural_qword  is -- Quadruple-word
        u_sfixed ((g_INTEGRAL_BITS*4)-1 downto -(g_FRACTIONAL_BITS*4));
    subtype neural_oword  is -- Octuple-word
        u_sfixed ((g_INTEGRAL_BITS*8)-1 downto -(g_FRACTIONAL_BITS*8));
    /* Vectors */
    -- A single-row (1-D) array of neural_*word values.
    type  neural_vector  is array (natural range <>) of neural_word;
    type  neural_bvector is array (natural range <>) of neural_bit;
    type  neural_nvector is array (natural range <>) of neural_nibble;
    alias neural_wvector is neural_vector;
    type  neural_dvector is array (natural range <>) of neural_dword;
    type  neural_qvector is array (natural range <>) of neural_qword;
    type  neural_ovector is array (natural range <>) of neural_oword;
    /* Matrices */
    -- A multi-row/nested (NOT 2-D) array of neural_*vector arrays.
    type  neural_matrix  is array (natural range <>) of neural_vector;
    type  neural_bmatrix is array (natural range <>) of neural_bvector;
    type  neural_nmatrix is array (natural range <>) of neural_nvector;
    alias neural_wmatrix is neural_matrix;
    type  neural_dmatrix is array (natural range <>) of neural_dvector;
    type  neural_qmatrix is array (natural range <>) of neural_qvector;
    type  neural_omatrix is array (natural range <>) of neural_ovector;
     
    /*
        Shorthand notations of the above-mentioned types
    */
    
    /* Scalars */
    alias nrl_bit  is neural_bit;
    alias nrl_nib  is neural_nibble;
    alias nrl_wrd  is neural_word;
    alias nrl_dwd  is neural_dword;
    alias nrl_qwd  is neural_qword;
    alias nrl_owd  is neural_oword;
    /* Vectors */
    alias nrl_vec  is neural_vector;
    alias nrl_bvec is neural_bvector;
    alias nrl_nvec is neural_nvector;
    alias nrl_wvec is neural_wvector;
    alias nrl_dvec is neural_dvector;
    alias nrl_qvec is neural_qvector;
    alias nrl_ovec is neural_ovector;
    /* Matrices */
    alias nrl_mat  is neural_vector;
    alias nrl_bmat is neural_bmatrix;
    alias nrl_nmat is neural_nmatrix;
    alias nrl_wmat is neural_wmatrix;
    alias nrl_dmat is neural_dmatrix;
    alias nrl_qmat is neural_qmatrix;
    alias nrl_omat is neural_omatrix;

    -- Custom helper types for use in finding files' dimensions
    -- (i.e., number of neurons and weights within each neuron)
    type dimension is record
        rows : natural;
        cols : natural;
    end record;
    type dimensions_array is
        array (natural range <>) of dimension;   
    
    -- An enumeration/structure of a layer's neuron(s)' weights (array
    -- of array) AND each neuron's associated bias (array).
    type layer_parameters is record
        dims    : dimension; -- Array limitations' workaround
        weights : neural_matrix;
        biases  : neural_vector;
    end record;
    
    -- NOTE: This is more limited than it seems, as each record would
    -- have to be of exactly the same length in a VHDL array of records
    -- On the other hand, dynamically allocated arrays, which are
    -- able to hold variable-length elements, are NOT allowed in
    -- synthetizable VHDL at all.
    -- See: https://stackoverflow.com/a/61031840
    --
    -- Array of records to hold the parameters (i.e., weights and 
    -- biases) of each and every layer, amounting to the entire network
    type network_layers is
        array (natural range <>) of layer_parameters;


-- ---------------------------------------------------------------------
-- rtl_synthesis off
-- pragma translate_off
-- ---------------------------------------------------------------------
    -- Simulation-Time Pointer types:  You may access these types'
    -- dereferenced variables' values using ".all" suffixes after them.
    -- Also, you may have "dynamically sized" arrays by concatenating
    -- new "new" definitions with previous ones.  Lastly, you may re-
    -- use declared pointer types by using "deallocate()" on them.
    type neural_word_ptr    is access neural_word;
    type neural_vector_ptr  is access neural_vector;
    type neural_matrix_ptr  is access neural_matrix;
    type network_layers_ptr is access network_layers;
    
    -- NOTE: VHDL doesn't permit files of multidimensionals (e.g.,
    -- matrices) directly, so some improvization with pointer types
    -- is required in order to retrieve them as arrays of arrays.
    --
    -- This could also be a file of fixed-points as fixed_pkg provides
    -- textio.read, although ONLY in binary, octal, or hex formats.
    type neural_file is file of neural_word;
-- ---------------------------------------------------------------------
-- pragma translate_on
-- rtl_synthesis on
-- ---------------------------------------------------------------------


    -- NOTE: These "partially" resize their inputs; they are used as
    -- tricks to force synthetis tools to let us use arrays of
    -- differing element sizes.  In practice, these 'resize's only
    -- "expand" their inputs and don't fully scale the data; they
    -- _partially_ fill-in the expanded result.
    function resize(
        input_arr  : in neural_vector;
        target_dim : in dimension
    ) return neural_vector;
    
    function resize(
        input_mat  : in neural_matrix;
        target_dim : in dimension
    ) return neural_matrix;


    -- NOTE: These refuse to work with unconstrained generic types;
    -- so, you will have to define the manually for each constant
    -- decleration, if you want to use them.
    /*
    attribute num_inputs  : natural;
    attribute num_outputs : natural;
    
    attribute num_inputs  of neural_vector : type is
        neural_vector'length;
    attribute num_outputs of neural_vector : type is
        neural_vector'length;  
    
    attribute num_inputs  of neural_matrix : type is
        neural_matrix(0)'length; -- or 'length(dimension) for 2-D array
    attribute num_outputs of neural_matrix : type is
        neural_matrix'length;  

    -- NOTE: Records can't have methods; there's no protected record.
    -- So, we can use the rather obscure 'group' keyword to accomplish
    -- a similar objective.
    group layer_group_type is ( constant <> );
    attribute num_neurons : natural;
        
    group layer_group : layer_group_type (layer_parameters);
    attribute num_neurons of layer_group : group is
        layer_parameters.biases'length; -- or weights'length
    */
    
    -- Another way of realizing the above idea is by using functions.
    /*
    function len_inputs(
        input_arr  : in neural_vector
    ) return natural;
    function len_outputs(
        input_arr  : in neural_vector
    ) return natural;
    
    function len_inputs(
        input_mat  : in neural_matrix
    ) return natural;
    function len_outputs(
        input_mat  : in neural_matrix
    ) return natural;
    
    function len_neurons(
        input_arr  : in neural_vector
    ) return natural;
    function len_neurons(
        input_arr  : in neural_vector
    ) return natural;  -- array of naturals?      
    */
end package fixed_neural_pkg;

-- TODO: Whenever Synthesis tools support protected types inside 
-- synthesis (for constant initializations), as opposed to just 
-- simulation, convert the methods inside this package body to 
-- be inside a 'protected' type of 'neural_vector' and '_matrix'.
package body fixed_neural_pkg is

    function resize(
        input_arr  : in neural_vector;
        target_dim : in dimension
    ) return neural_vector is
        variable resized_arr : neural_vector (0 to target_dim.rows-1);
    begin
        resized_arr(input_arr'range) := input_arr; -- Partially fill it
        
        return resized_arr;
    end function;

    function resize(
        input_mat  : in neural_matrix;
        target_dim : in dimension
    ) return neural_matrix is
        variable resized_mat : neural_matrix
            (0 to target_dim.rows-1) (0 to target_dim.cols-1);
    begin
        for row in input_mat'range loop
            --resized_mat(row) := resize(input_mat(row), target_dim);
            resized_mat(row)(input_mat(row)'range) := input_mat(row);
        end loop;
        
        return resized_mat;
    end function;
    
end package body fixed_neural_pkg;



-- "'guard_bits' defaults to 'fixed_guard_bits,' which defaults
-- to 3. Guard bits are used in the rounding routines. If guard
-- is set to 0, the rounding is automatically turned off.
-- These extra bits are added to the end of the numbers in the
-- division and "to_real" functions to make the numbers more
-- accurate." (Fixed point package user's guide by Mr. David Bishop)
library ieee;
library config;
    use config.constants.all;
package fixed_pkg_for_neural is new ieee.fixed_generic_pkg
    generic map ( -- NOTE: ieee_proposed pre VHDL-08
        fixed_round_style    => c_FIXED_ROUND,
        fixed_overflow_style => c_FIXED_OFLOW,
        fixed_guard_bits     => c_GUARD_BITS,
        no_warning           => false
    );
    
library neural;
library config;
    use config.constants.all;
package neural_typedefs is new neural.fixed_neural_pkg
    generic map (
        --INTEGRAL_BITS        => c_WORD_INTG, -- NOTE: Signed
        --FRACTIONAL_BITS      => c_WORD_FRAC,
        g_FIXED_PKG_INSTANCE   => work.fixed_pkg_for_neural
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

-- TODO: Include arrays of std_(u)logic_vector types?
--type t_slv_arr is array (natural range <>) of std_logic_vector;
--type t_suv_arr is array (natural range <>) of std_ulogic_vector;
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
    library neural;
        use neural.fixed_pkg_for_neural.all,
            neural.neural_typedefs.all;
        use neural.fixed_generic_pkg_bugfix.all; -- REQUIRED!
end context neural_context;

-- NOTE: Unfortunately, even if I play by Vivado Simulator's rules by
-- placing the VHDL-93 compatibility version of IEEE's fixed_pkg into
-- a local directory AND commenting-out all homographes of std_logic_
-- vectors AND removing all references to 'line' datatypes, it still
-- finds a way to crash abruptly in other areas (e.g., File I/O),
-- without any log whatsoever, in simulation; working with Vivado's
-- Simulator is pointless, as even a ModelSim version from 8 years ago
-- (as of 2024) far outperforms it.

-- ---------------------------------------------------------------------
-- rtl_synthesis off
-- pragma translate_off
-- ---------------------------------------------------------------------

-- NOTE: Here, in simulation, we OVERWRITE the previous declaration;
-- this is done because there is no other way to detect whether the
-- code is being simulated and skip synth's code, in the latter case we
-- also need to use a custom version of IEEE's fixed_pkg due to Vivado.
/*
context neural_context is
    library ieee_proposed;
        use ieee_proposed.fixed_pkg.all;
    -- NOTE: Xilinx Vivado does not support fixed- or floating-point
    -- packages for use within its simulator, even though it can
    -- synthetize them just fine; as a workaround, use 
    -- a LOCAL 'ieee_proposed' instead of 'ieee'.
    --
    -- SEE: 
    --     docs.xilinx.com/r/en-US/ug900-vivado-logic-simulation/
    --         Fixed-and-Floating-Point-Packages
    --
    --     insights.sigasi.com/tech/list-known-vhdl-metacomment-pragmas
    library config;
        use config.neural_typedefs.all;
        use config.fixed_generic_pkg_bugfix.all; -- REQUIRED!
end context neural_context;
*/

-- ---------------------------------------------------------------------
-- pragma translate_on
-- rtl_synthesis on
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- END OF FILE: neural_typedefs.vhd
-- ---------------------------------------------------------------------