-----------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later or CERN-OHL-W-2.0
-- file_parser.vhd is a part of Innervator.
-----------------------------------------------------------------------


library std;
    use std.textio.all;

library ieee;
    use ieee.std_logic_1164.all;
    --use ieee.std_logic_textio.all;

library config;
    context config.neural_context;


-- NOTE: These deferred constants will be "initialized" inside the
-- Package's body, after the above function declarations (which
-- will be used in these constants) have been "elaborated."
-- NOTE: The reason this package has been divided into two, including
-- an auxiliary one, is because I could not use the same functions
-- defined in a single package's body inside constant initializations
-- of its header (since the functions were not 'elaborated' on yet);
-- while you might think that 'deferred constants' were a solution to
-- this, they actually were not.
--     Because I also needed to use said deferred constants inside 
-- the subtypes/types defined in the actual package's header, I
-- would trigger simulator errors related to "illegal use of deferred
-- constants."  So, this was the only solution to access bo
package file_parser_aux is 

    -- NOTE: Because the fixed-point package only provides procedures
    -- to read its types from files in the textual format of binary,
    -- octal, and hexadecimal (i.e., NOT decimal), I initially chose
    -- to read the inputs as floating-point 'real' types which would 
    -- then be converted into fixed-point internally.  HOWEVER, this
    -- brought me to the second issue: Xilinx Vivado has a bug in its
    -- implementation of the 'read()' procedure for 'real' datatypes,
    -- which prevents you from reading more than 7 elements from a 
    -- single row.  THUS, I had to resort to the lesser-known 'sread()'
    -- procedure, which takes in a (forcibly constrained) string,
    -- strips the given line of any and all types of whitespace 
    -- characters and, lastly, tokenizes each whitespace-separated
    -- collection of characters into the input string; this way,
    -- I could get past Vivado's bug and convert the string 
    -- representation of floating-points into a 'real' and finally
    -- an actual fixed-point... or, could I?
    --     Vivado, unsurprisingly, did NOT care to implement 'sread()'
    -- AT ALL; while it appears to synthetize correctly, it hard-
    -- crashes the simulator with NO log and also does not even work
    -- in synthesis itself (tested using 'assert' statements).
    -- To make matters even worse, Vivado implemented the fixed-point
    -- package---an official IEEE package---in an incredibly poor and
    -- "hacky" way; not only does the simulator outright REFUSE to work
    -- with the ieee.fixed_generic_pkg, but it also suggets, even as of
    -- the 2023.2 version, that you use the now-OUTDATED workaround of
    -- replacing ieee with ieee_proposed as to use the VHDL-93 version
    -- of the Package.  The problem here is that, sometime around 2021,
    -- they removed ieee_proposed from the package list, making their
    -- OWN workaround OBSOLETE.  Not only that but, because they again
    -- failed to implement std.textio's 'line' type properly, you also
    -- cannot place the raw files of fixed-point package into your own
    -- project's directory and resolve the issue; Vivado does not even
    -- let you define or use a procedure that takes in a 'line' type
    -- parameter.  This also brings us to the next issue: I could NOT
    -- use fixed-point package's implementation of sfixed/ufixed parser
    -- [i.e., read()].  SEE:
    -- https://support.xilinx.com/s/question/0D52E00006lLghFSAS
    --     ULTIMATELY, I had to resort back to using Vivado's broken
    -- implementation of read() (which is the ONLY choice) and
    -- flatten my input files to not contain more than a single
    -- element per line.
    --     But then I encountered yet another problem: Vivado's 
    -- 'readline()' behaved very strangely, reporting the 'length
    -- attribute to be >0 even for otherwise-blank lines.  The issue
    -- as I later found out, was that Vivado, for some reason, treats
    -- files with a '.txt' extension in a special manner and readline()
    -- completely breaks on those; so, I had to rename it to something
    -- else (e.g., '.dat').  This should not happen since 'text' is
    -- defined as 'file of string' in std.textio, and, if I wanted to
    -- have my file read as binary or any other type, I would define
    -- my own 'type binary is file of bit', yet Vivado makes this 
    -- (undocumented) assumption on its own...  SEE:
    -- reddit.com/r/FPGA/comments/16th9ok
    --     /textio_not_reading_negative_integers_from_file_in
    --     That seemed to solve the Issue only in simulation, although
    -- read() would still not read more than 7 elements per line; in
    -- synthesis, read() was STILL broken beyond repair.  Eventually,
    -- I found that Vivado actually implemented the read() procedure
    -- correctly ONLY in case of 'bit_vector' and 'std_logic_vector';
    -- NOTHING else---not even simple positive integers---works.
    --     Also, I found out that another limitation is that you CANNOT
    -- detect "blank" lines; for some reason, Vivado will always report
    -- the current line's 'length attribute to be the same throughout
    -- an entire file.  Fortunately, this could be worked-around by 
    -- merely using rows full of 'X', 'Z', or 'U' as "delimiters."
    -- inside COMMENTS, and its read() was completely disfunctional).
    --     Never have I had to wrestle so much with a toolchain just to
    -- get something so incredibly trivial to work, but this seems to
    -- be commonplace within EDA tools: I also looked into Synopsys'
    -- Synplify to see if they implemented file I/O properly there,
    -- but Synplify seemed even buggier than Vivado (e.g., it would
    -- break when you used ASCII grave accents and specific keywords
    -- such as protected).
    --
    -- NOTE: Do NOT use 'ulogic' as Vivado's read() is broken for it.
    subtype read_t is std_logic_vector(neural_word'length-1 downto 0);
    --
    -- NOTE: Also, since you cannot leave out the 'out' parameters of 
    -- procedures as 'open' in VHDL (unlike entities and components),
    -- I NEED to use this "dummy" placeholder evem if we don't actually
    -- care about the read values and only want to count their numbers.
    alias dummy_t is read_t;
    -- Be aware that you cannot combine 'sread()' (which is broken
    -- anyway) with a non-static while-loop, or else Vivado will
    -- still complain about using an unsynthesizable procedure. 
    --constant FAKE_LIMIT : natural := 2**16 - 1;

    constant ROW_DELIMITER : read_t := (others => 'X');
    --constant NULL_SLV      : std_logic_vector (0 downto 1) :=
    --    (others => '0');


    -- Helper macros; TODO: Make this package a generic based on these
    function get_weights_file(
        layer_path : in string;
        layer_idx  : in natural
    ) return string;

    function get_biases_file(
        layer_path : in string;
        layer_idx  : in natural
    ) return string;

    impure function get_num_layers(
        network_path : in string
    ) return natural;
    
    impure function get_network_dimensions(
        network_dir : in string;
        num_layers  : in natural
    ) return dimensions_array;
    
    function max(x : dimensions_array) return dimension;
    
end package file_parser_aux;

package body file_parser_aux is

    function get_weights_file(
        layer_path : in string;
        layer_idx  : in natural
    ) return string is
    begin
        return layer_path & "/weights_" &
        natural'image(layer_idx) & ".dat";
    end function get_weights_file;

    function get_biases_file(
        layer_path : in string;
        layer_idx  : in natural
    ) return string is
    begin
        return layer_path & "/biases_" &
        natural'image(layer_idx) & ".dat";
    end function get_biases_file;

    -- Returns the number of layers in a network, depending on how
    -- many 'weights' files were present in a given directory.
    -- Unfortunately, as a side effect, it has to create an extra
    -- file named "weights_{N+1}.dat" to bypass Vivado's limitations.
    --
    -- NOTE: Due to Vivado's nonstandard implementation of file_open(),
    -- we cannot depend on "open_status = name_error," because Vivado
    -- just quits whenever it encounters a file that cannot be opened.
    -- SEE: support.xilinx.com/s/question/0D54U00008CO8pTSAT/
    --         bug-fileopen-is-not-consistent-with-ieee-standards
    impure function get_num_layers(
        network_path : in string
    ) return natural is
        file     test_handle  : text;
        variable open_status  : file_open_status;
        variable file_no      : natural := 0;
    begin
        -- Exit when there are no more layers/files to process.
        try_file : loop
            -- NOTE: In VHDL-2008, there is no 'read_write_mode' as
            -- in VHDL-2009; this is a rather lengthy workaround.
            --
            -- NOTE: Do NOT use 'write_mode'; it wipes the file out.
            -- use 'append_mode' instead.
            file_open(
                open_status,
                test_handle,
                get_weights_file(network_path, file_no),
                append_mode -- Create it if it doesn't exist
            );
            file_close(test_handle);
            
            -- 'open_status' doesn't work in Vivado.
            exit when (open_status /= open_ok);      
            
            file_open(
                open_status,
                test_handle,
                get_weights_file(network_path, file_no),
                read_mode -- Re-open it in readmode
            );
            
            was_empty : if endfile(test_handle)  then
                file_close(test_handle);
                exit; -- Exit entirely
            else
                -- The file opened was valid & there exists a layer.
                file_no := file_no + 1;
            end if was_empty;
            
            file_close(test_handle);
        end loop try_file;
        
        return file_no;
    end function get_num_layers;

    -- This function returns the number of rows and columns in a file.
    impure function get_layer_dimension(
        layer_dir : in string;
        layer_idx : in natural
    ) return dimension is
        constant sample_file     : string :=
            get_weights_file(layer_dir, layer_idx);
        file     file_to_test    : text open read_mode is sample_file;
        variable current_line    : line;        
        variable dummy_element   : dummy_t;
        variable read_succeded   : boolean;
        variable n_rows          : natural := 1; -- No ending delimiter
        variable n_cols          : natural := 0;
        variable layer_dimension : dimension;
    begin
        
        count_rows : while not endfile(file_to_test) loop
            --count_cols : while not endfile(file_to_test) loop
            
            readline(file_to_test, current_line);
            read(current_line, dummy_element, read_succeded);
            
            if dummy_element = ROW_DELIMITER then
                n_rows := n_rows + 1;
            end if;
            
            if n_rows = 1 then -- Avoid re-counting multiple times
                n_cols := n_cols + 1;
            end if;         
            
            --end loop count_cols;
        end loop count_rows;
        
        assert n_rows > 0
            report "No rows existed in layer no. "
            & natural'image(layer_idx) & "."
                severity failure;
        assert n_cols > 0
            report "No columns existed in layer no. " 
            & natural'image(layer_idx) & "."
                severity failure;
        
        layer_dimension.rows := n_rows;
        layer_dimension.cols := n_cols;
        
        return layer_dimension;
    end function get_layer_dimension;

    -- This returns an array of rows and cols in a network's layers
    impure function get_network_dimensions(
        network_dir : in string;
        num_layers  : in natural
    ) return dimensions_array is
        variable network_dimensions : 
            dimensions_array (0 to num_layers-1);
    begin
    
        per_layer : for idx in network_dimensions'range loop
            network_dimensions(idx) :=
                get_layer_dimension(network_dir, idx);
        end loop per_layer;
        
        return network_dimensions;
    end function get_network_dimensions;


    -- Returns the maximum of either columns# and rows# together
    -- as a single dimension; takes an array of dimensions.
    function max(x : dimensions_array) return dimension is
        variable x_max : dimension := x(x'low); -- Start with the first
    begin
        -- Starting from 'low+1 because 'low was assigned beforehand.
        comparator : for i in x'low+1 to x'high loop
            x_max.rows := x(i).rows when (x(i).rows > x_max.rows);
            x_max.cols := x(i).cols when (x(i).cols > x_max.cols);
        end loop comparator;
        
        return x_max;
    end function max;

end package body file_parser_aux;


library std;
    use std.textio.all;

library ieee;
    use ieee.std_logic_1164.all;
    
library work;
    use work.file_parser_aux.all;
    
library config;
    context config.neural_context;


package file_parser is
    generic (
        g_NETWORK_DIR : string
    );
    use work.file_parser_aux.all;

    constant c_NUM_LAYERS : natural :=
        get_num_layers(g_NETWORK_DIR);
    constant c_LAYER_DIMS : dimensions_array :=
        get_network_dimensions(g_NETWORK_DIR, c_NUM_LAYERS);
    constant c_MAX_DIM    : dimension :=
        max(c_LAYER_DIMS);


    subtype constr_params_t is layer_parameters (
        weights (0 to c_MAX_DIM.rows-1) (0 to c_MAX_DIM.cols-1),
        biases  (0 to c_MAX_DIM.rows-1)
    );
    type constr_params_arr_t is
        array (0 to c_NUM_LAYERS-1) of constr_params_t;


    impure function parse_network_from_dir(
        network_dir : string
    ) return constr_params_arr_t;
   
end package file_parser;

-- NOTE: In VHDL, you are not able to pass or return ranges (e.g.,
-- '7 downto 0') to or from functions/procedures; so, the start/end
-- both have to be given SEPARATELY.
--
-- NOTE: In VHDL, you also cannot pass 'file' handles/objects; so,
-- the solution is to reduntantly open/close the files EACH time.
package body file_parser is  
    -- NOTE Due to VHDL limitations, and to avoid allocators (i.e.,
    -- 'access', 'new', and dynamic concatenation), which are
    -- completely disallowed in synthesis (EVEN to just initialize
    -- other constants) we have to know the number of rows/cols in
    -- each file as a constant BEFORE calling these functions.  In
    -- other words, the '_dim' parameters are the actual dimensions
    -- and not the ones we'd subsequently use for the Resizing Trick.
    -- (Thanks to Mr. Brian Padalino for his dimension-measuring idea.)

    -- NOTE: Make sure to review the following link:
    -- support.xilinx.com/s/question/0D54U00008ADvMRSA1
    -- TL;DR: Vivado (as of 2023.2) has a bug within its 
    -- 'read()' procedure of 'real' datatypes that prevents 
    -- reading out more than 7 times from a single line.  
    -- 
    -- This means that "rows" hereinafter refer to a _flattened_ list
    -- of elements on multiple lines, NOT multiple elements per line.
       
       
    -- Variant for arrays (e.g., biases)
    impure function parse_elements(
        file_path : in string;
        file_dim  : in dimension
    ) return neural_array is
        file     file_handle : text open read_mode is file_path;
        variable file_row    : line;
        variable row_elem    : read_t; -- Intermediary for conversion
        variable result_arr  : neural_array (0 to file_dim.rows-1);
    begin
        -- No need for an outer loop; there is only ONE "row" of biases
        
        parse_row : for col in result_arr'range loop

            readline(file_handle, file_row);
            read(file_row, row_elem);
            
            -- Convert to the internally used fixed-point type.
            result_arr(col) := to_sfixed(
                row_elem, neural_word'high, neural_word'low
            );    

        end loop parse_row;        

        return result_arr;
    end function parse_elements;
        
    -- Variant for nested arrrays/matrices (e.g., weights)
    impure function parse_elements(
        file_path : in string;
        file_dim  : in dimension
    ) return neural_matrix is
        file     file_handle  : text open read_mode is file_path;
        variable file_row     : line;
        variable row_elem     : read_t; -- Intermediary for conversion
        variable dummy_length : natural;        
        variable result_mat   : neural_matrix
            (0 to file_dim.rows-1) (0 to file_dim.cols-1);
    begin
        
        parse_rows : for row in result_mat'range loop
            parse_cols : for col in result_mat(0)'range loop

                readline(file_handle, file_row);
                read(file_row, row_elem);
                
                -- If the row hasn't ended, convert and store the item.
                result_mat(row)(col) := to_sfixed(
                    row_elem, neural_word'high, neural_word'low
                );
            
            end loop parse_cols;
            
            -- Skip the delimiters (except at EOF)
            if not endfile(file_handle) then
                readline(file_handle, file_row);
            end if;
        end loop parse_rows;
                
        return result_mat;
    end function parse_elements;


    -- NOTE: A very frustrating limitation was that anything earlier
    -- than VHDL-2019 cannot use 'block' in subprograms (e.g., function
    -- bodies), and I really needed to use 'block's because they allow
    -- you to have a varying number of locally scoped constant types.
    -- Because I have an unknown (though not at compile-time) number of
    -- layers to parse, I cannot simply hard-code 10 or 100 constant
    -- types.  So, one way was to constrain the entire holder (record)
    -- inside the function's declaration region, but this proved a 
    -- challenge: I now could not return my value from the function in
    -- any way.
    --     Constraining a record inside a function's LOCAL declaration
    -- area meant that I could not use it to define the function's own
    -- return type, much less use it outside the function for the 
    -- caller's type.  Other than using VHDL-2019 (which, as of 2024,
    -- is not supported anywhere), a solution to this was using a
    -- for-generate loop (which DOES have a locally scoped declaration
    -- region) inside an entity.  However, this meant having to 
    -- instantiate an entity each time you want to use the parser;
    -- the syntax would look rather clunky that way.
    --     Ultimately, I chose to take advantage of VHDL-2008's generic
    -- packages and perform some of the processing (i.e., finding the 
    -- number of layers or their dimensions), which will be used by the
    -- custom constrained record types, earlier in the package's header
    impure function parse_network_from_dir(
        network_dir : string
    ) return constr_params_arr_t is
        variable layer_params : constr_params_t;
        variable result_arr : constr_params_arr_t;
    begin

        per_layer : for i in 0 to c_NUM_LAYERS-1 loop
        
            layer_params.biases  := resize(parse_elements(
                get_biases_file(g_NETWORK_DIR, i), c_LAYER_DIMS(i)
            ), c_MAX_DIM);
            layer_params.weights := resize(parse_elements(
                get_weights_file(g_NETWORK_DIR, i), c_LAYER_DIMS(i)
            ), c_MAX_DIM);
            
            result_arr(i) := layer_params;
        end loop per_layer;
        
        return result_arr;
    end function parse_network_from_dir;


end package body file_parser;


-----------------------------------------------------------------------
-- END OF FILE: file_parser.vhd
-----------------------------------------------------------------------