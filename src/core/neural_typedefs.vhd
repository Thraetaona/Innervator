-----------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- neural_typedefs.vhd is a part of Innervator.
-----------------------------------------------------------------------


library ieee;

-- TODO: Provide an option to use unsigned types, too.
package fixed_neural_pkg is
    generic (
        INTEGRAL_BITS, FRACTIONAL_BITS : natural; -- For Fixed-Points
    -- From The Designer's Guide to VHDL 3rd ed. by Peter J. Ashenden:
    --
    -- "In this case, the formal package represents an instance of the
    -- named uninstantiated package, for use within the enclosing unit
    -- containing the generic list.  In most use cases, the enclosing
    -- unit is itself an uninstantiated package.  However, we can also
    -- specify formal generic packages in the generic lists of entities
    -- and subprograms.  When we instantiate the enclosing unit, we
    -- provide an actual package corresponding to the formal generic
    -- package. The actual package must be an instance of the named
    -- uninstantiated packge. The box notation '<>' written in the
    -- generic map of the formal generic package specifies that the
    -- actual package is allowed to be any instance of the named
    -- uninstantiated package. We use this form when the enclosing
    -- unit does not depend on the particular actual generics defined
    -- for the actual generic package."
        package FIXED_PKG_INSTANCE is new ieee.fixed_generic_pkg
            generic map ( <> ) -- VHDL-2008 Formal Generic Package
    );
    use FIXED_PKG_INSTANCE.all; -- Import our custom fixed_pkg

    -- A word is the "primary" size of values that we are going to use.
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
    subtype neural_word is
        u_sfixed (INTEGRAL_BITS-1 downto -FRACTIONAL_BITS);
    -- A single row (1-D array) of neural_word values.
    type neural_array is array (natural range <>) of neural_word;
    -- A multi-row (i.e., a nested array of arrays; NOT a 2-D array)
    -- array of neural_array arrays.
    type neural_matrix is array (natural range <>) of neural_array;
    -- Alternative definition ~ a multidimensional 2-D array of words:
    --type neural_matrix is
    --    array (natural range <>, natural range <>) of neural_word;

    -- An enumeration/structure of a layer's neuron(s)' weights (array
    -- of array) AND each neuron's associated bias (array).
    type layer_parameters is record
        weights : neural_matrix;
        biases  : neural_array;
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

    -- Misc. types derived from the primary word size
    subtype neural_bit is -- A single "analogue" bit with range [0, 1).
        u_ufixed (-1 downto -(FRACTIONAL_BITS*2)); -- Unsigned and < 1
    subtype neural_nibble is -- Half-word
        u_sfixed ((INTEGRAL_BITS/2)-1 downto -(FRACTIONAL_BITS/2));
    alias neural_byte is neural_word; -- Same as word
    subtype neural_dword is -- Double-word
        u_sfixed ((INTEGRAL_BITS*2)-1 downto -(FRACTIONAL_BITS*2));
    subtype neural_qword is -- Quadruple-word
        u_sfixed ((INTEGRAL_BITS*4)-1 downto -(FRACTIONAL_BITS*4));
    subtype neural_oword is -- Octuple-word
        u_sfixed ((INTEGRAL_BITS*8)-1 downto -(FRACTIONAL_BITS*8));
       
       
-----------------------------------------------------------------------
-- pragma translate_off
-----------------------------------------------------------------------
    -- Simulation-Time Pointer types:  You may access these types'
    -- dereferenced variables' values using ".all" suffixes after them.
    -- Also, you may have "dynamically sized" arrays by concatenating
    -- new "new" definitions with previous ones.  Lastly, you may re-
    -- use declared pointer types by using "deallocate()" on them.
    type neural_word_ptr is access neural_word;
    type neural_array_ptr is access neural_array;
    type neural_matrix_ptr is access neural_matrix;
    type network_layers_ptr is access network_layers;
    
    -- NOTE: VHDL doesn't permit files of multidimensionals (e.g.,
    -- matrices) directly, so some improvization with pointer types
    -- is required in order to retrieve them as arrays of arrays.
    --
    -- This could also be a file of fixed-points as fixed_pkg provides
    -- textio.read, although ONLY in binary, octal, or hex formats.
    type neural_file is file of neural_word;
-----------------------------------------------------------------------
-- pragma translate_on
-----------------------------------------------------------------------

    -- Custom helper types for use in finding files' dimensions
    -- (i.e., number of neurons and weights within each neuron)
    type dimension is record
        rows : natural;
        cols : natural;
    end record;
    type dimensions_array is
        array (natural range <>) of dimension;   
    
    
    -- NOTE: These "partially" resize their inputs; they are used as
    -- tricks to force synthetis tools to let us use arrays of
    -- differing element sizes.  In practice, these 'resize's only
    -- "expand" their inputs and don't fully scale the data; they
    -- _partially_ fill-in the expanded result.
    function resize(
        input_arr  : in neural_array;
        target_dim : in dimension
    ) return neural_array;
    
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
    
    attribute num_inputs  of neural_array : type is
        neural_array'length;
    attribute num_outputs of neural_array : type is
        neural_array'length;  
    
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
        input_arr  : in neural_array
    ) return natural;
    function len_outputs(
        input_arr  : in neural_array
    ) return natural;
    
    function len_inputs(
        input_mat  : in neural_matrix
    ) return natural;
    function len_outputs(
        input_mat  : in neural_matrix
    ) return natural;
    
    function len_neurons(
        input_arr  : in neural_array
    ) return natural;
    function len_neurons(
        input_arr  : in neural_array
    ) return natural;  -- array of naturals?      
    */
end package fixed_neural_pkg;

-- TODO: Whenever Synthesis tools support protected types inside 
-- synthesis (for constant initializations), as opposed to just 
-- simulation, convert the methods inside this package body to 
-- be inside a 'protected' type of 'neural_array' and '_matrix'.
package body fixed_neural_pkg is

    function resize(
        input_arr  : in neural_array;
        target_dim : in dimension
    ) return neural_array is
        variable resized_arr : neural_array (0 to target_dim.rows-1);
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


-----------------------------------------------------------------------
-- END OF FILE: neural_typedefs.vhd
-----------------------------------------------------------------------