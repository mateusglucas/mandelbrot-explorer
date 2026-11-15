-- VUnit testbench for idx_to_coord:
--   coord = center + (2*idx - (RES-1)) * RATIO / 2^(zoom+1)
--   latency 3: valid_out / coord settle after 3 en cycles

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_idx_to_coord IS
	GENERIC (
		runner_cfg	: string;
		k             : natural := 16;
		res           : natural := 5;
		w_zoom		: natural := 3;
		ratio_fp      : integer := 4096  -- 2^12 with K=16
	);
END ENTITY tb_idx_to_coord;

ARCHITECTURE sim OF tb_idx_to_coord IS

	CONSTANT one           : signed(k - 1 DOWNTO 0) := to_signed(2 ** (k - 4), k);
	CONSTANT w_idx         : natural                := bits_of(res - 1);
	CONSTANT lat           : natural                := 3; -- must match idx_to_coord pipeline
	CONSTANT clk_period	: time                   := 10 ns;
	CONSTANT ratio_c       : signed(k - 1 DOWNTO 0) := to_signed(ratio_fp, k);

	SIGNAL clk       : std_logic := '0';
	SIGNAL rst       : std_logic;
	SIGNAL en        : std_logic;
	SIGNAL valid_in  : std_logic;
	SIGNAL center    : signed(k - 1 DOWNTO 0);
	SIGNAL idx       : unsigned(w_idx - 1 DOWNTO 0);
	SIGNAL zoom      : unsigned(w_zoom - 1 DOWNTO 0);
	SIGNAL coord     : signed(k - 1 DOWNTO 0);
	SIGNAL valid_out : std_logic;

	FUNCTION expected_coord (
		CONSTANT c		: signed;
		CONSTANT idx_n	: natural;
		CONSTANT z		: natural
	) RETURN signed IS

		CONSTANT diff_w     : natural := bits_of(RES - 1) + 1;
		VARIABLE diff_v     : signed(diff_w - 1 DOWNTO 0);
		VARIABLE prod_v     : signed(RATIO_C'LENGTH + diff_w - 1 DOWNTO 0);
		VARIABLE shift_v	: signed(K - 1 DOWNTO 0);

	BEGIN

		diff_v  := to_signed(2 * idx_n - (RES - 1), diff_w);
		prod_v  := diff_v * RATIO_C;
		shift_v := resize(shift_right(prod_v, z + 1), K);
		RETURN resize(c + shift_v, K);

	END FUNCTION expected_coord;

	PROCEDURE do_rst (
		SIGNAL rst_s         : OUT std_logic;
		SIGNAL en_s          : OUT std_logic;
		SIGNAL valid_in_s	: OUT std_logic;
		SIGNAL clk_s         : IN std_logic
	) IS
	BEGIN

		en_s          <= '0';
		valid_in_s	<= '0';
		rst_s         <= '1';
		WAIT UNTIL rising_edge(clk_s);
		rst_s         <= '0';
		WAIT FOR 1 ns;

	END PROCEDURE do_rst;

	PROCEDURE apply (
		CONSTANT c        : signed;
		CONSTANT idx_n    : natural;
		CONSTANT z        : natural;
		CONSTANT vin      : std_logic;
		SIGNAL center_s   : OUT signed(K - 1 DOWNTO 0);
		SIGNAL idx_s      : OUT unsigned(w_idx - 1 DOWNTO 0);
		SIGNAL zoom_s     : OUT unsigned(W_ZOOM - 1 DOWNTO 0);
		SIGNAL valid_in_s : OUT std_logic;
		SIGNAL en_s       : OUT std_logic;
		SIGNAL clk_s      : IN std_logic
	) IS
	BEGIN

		center_s      <= c;
		idx_s         <= to_unsigned(idx_n, W_IDX);
		zoom_s		<= to_unsigned(z, W_ZOOM);
		valid_in_s	<= vin;
		en_s          <= '1';

		FOR i IN 1 TO LAT LOOP

			WAIT UNTIL rising_edge(clk_s);

		END LOOP;

		en_s <= '0';
		WAIT FOR 1 ns;

	END PROCEDURE apply;

	PROCEDURE check_point (
		CONSTANT c			: signed;
		CONSTANT idx_n		: natural;
		CONSTANT z			: natural;
		CONSTANT msg          : string;
		SIGNAL center_s       : OUT signed(K - 1 DOWNTO 0);
		SIGNAL idx_s          : OUT unsigned(w_idx - 1 DOWNTO 0);
		SIGNAL zoom_s         : OUT unsigned(W_ZOOM - 1 DOWNTO 0);
		SIGNAL valid_in_s     : OUT std_logic;
		SIGNAL en_s           : OUT std_logic;
		SIGNAL clk_s          : IN std_logic;
		SIGNAL coord_s		: IN signed(K - 1 DOWNTO 0);
		SIGNAL valid_out_s	: IN std_logic
	) IS

		VARIABLE exp : signed(K - 1 DOWNTO 0);

	BEGIN

		apply(c, idx_n, z, '1', center_s, idx_s, zoom_s, valid_in_s, en_s, clk_s);
		exp := expected_coord(c, idx_n, z);
		check_equal(coord_s, exp, msg);
		check_equal(valid_out_s, '1', msg & " valid_out");

	END PROCEDURE check_point;

BEGIN

	DUT : ENTITY work.idx_to_coord
		GENERIC MAP (
			k         => k,
			res       => res,
			w_zoom	=> w_zoom,
			ratio     => RATIO_C
		)
		PORT MAP (
			clk          => clk,
			rst          => rst,
			en           => en,
			valid_in     => valid_in,
			center       => center,
			idx          => idx,
			zoom         => zoom,
			coord		=> coord,
			valid_out	=> valid_out
		);

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS IS

		VARIABLE held : signed(k - 1 DOWNTO 0);

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			do_rst(rst, en, valid_in, clk);

			IF run("corners_zoom0") THEN
				check_point(to_signed(0, k), 0, 0, "idx=0 zoom=0 center=0",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, k), res - 1, 0, "idx=RES-1 zoom=0 center=0",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(ONE, 0, 0, "idx=0 zoom=0 center=1.0",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(-ONE, res - 1, 0, "idx=RES-1 zoom=0 center=-1.0",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
			ELSIF run("mid_pixel") THEN
				check_point(resize(3 * ONE, k), res / 2, 0, "mid idx => coord=center",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
			ELSIF run("zoom") THEN
				check_point(to_signed(0, k), 0, 1, "idx=0 zoom=1",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, k), res - 1, 1, "idx=RES-1 zoom=1",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, k), 0, 2, "idx=0 zoom=2",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, k), res - 1, 2, "idx=RES-1 zoom=2",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
			ELSIF run("en_hold") THEN
				check_equal(valid_out, '0', "valid_out after rst");

				check_point(to_signed(0, k), 0, 0, "load before hold",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				held     := coord;
				center   <= one;
				idx      <= to_unsigned(res - 1, w_idx);
				zoom     <= to_unsigned(1, w_zoom);
				valid_in <= '0';
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(coord, held, "coord must hold when en=0");
				check_equal(valid_out, '1', "valid_out sticky when en=0");

				do_rst(rst, en, valid_in, clk);
				check_equal(valid_out, '0', "valid_out clears on rst");
			ELSIF run("valid_prop") THEN
				apply(to_signed(0, k), 0, 0, '0',
	      center, idx, zoom, valid_in, en, clk);
				check_equal(valid_out, '0', "bubble: valid_out follows 0");

				apply(to_signed(0, k), res - 1, 0, '1',
	      center, idx, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "valid_out follows 1");
				check_equal(coord, expected_coord(to_signed(0, k), res - 1, 0),
	            "coord after valid sample");
			ELSIF run("sweep_idx") THEN
				IF (res <= 16) THEN

					FOR n IN 0 TO res - 1 LOOP

						check_point(to_signed(0, k), n, 0, "sweep zoom=0",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
						check_point(to_signed(0, k), n, 1, "sweep zoom=1",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);

					END LOOP;

				ELSE
					check_point(to_signed(0, k), 1, 0, "sweep idx=1",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
					check_point(to_signed(0, k), res / 4, 0, "sweep idx=RES/4",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
					check_point(to_signed(0, k), (3 * res) / 4, 1, "sweep idx=3RES/4 zoom=1",
	            center, idx, zoom, valid_in, en, clk, coord, valid_out);
				END IF;
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
