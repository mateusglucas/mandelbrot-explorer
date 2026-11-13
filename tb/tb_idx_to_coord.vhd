-- VUnit testbench for idx_to_coord:
--   coord = center + (2*idx - (RES-1)) * RATIO / 2^(zoom+1)
--   valid_out tracks valid_in when en=1 (pipeline propagate)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_idx_to_coord IS
	GENERIC(
		runner_cfg	: STRING;
		K			: NATURAL := 16;
		RES			: NATURAL := 5;
		W_ZOOM		: NATURAL := 3;
		RATIO_FP	: INTEGER := 4096  -- 2^12 with K=16
	);
END tb_idx_to_coord;

ARCHITECTURE sim OF tb_idx_to_coord IS
	CONSTANT ONE		: SIGNED(K - 1 DOWNTO 0) := to_signed(2 ** (K - 4), K);
	CONSTANT W_IDX		: NATURAL := bits_of(RES - 1);
	CONSTANT CLK_PERIOD	: TIME := 10 ns;
	CONSTANT RATIO_C	: SIGNED(K - 1 DOWNTO 0) := to_signed(RATIO_FP, K);

	SIGNAL clk			: STD_LOGIC := '0';
	SIGNAL rst			: STD_LOGIC := '0';
	SIGNAL en			: STD_LOGIC := '0';
	SIGNAL valid_in		: STD_LOGIC := '0';
	SIGNAL center		: SIGNED(K - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL idx			: UNSIGNED(W_IDX - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL zoom			: UNSIGNED(W_ZOOM - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL coord		: SIGNED(K - 1 DOWNTO 0);
	SIGNAL valid_out	: STD_LOGIC;

	FUNCTION expected_coord(
		CONSTANT c		: SIGNED;
		CONSTANT idx_n	: NATURAL;
		CONSTANT z		: NATURAL
	) RETURN SIGNED IS
		CONSTANT DIFF_W	: NATURAL := bits_of(RES - 1) + 1;
		VARIABLE diff_v	: SIGNED(DIFF_W - 1 DOWNTO 0);
		VARIABLE prod_v	: SIGNED(RATIO_C'LENGTH + DIFF_W - 1 DOWNTO 0);
		VARIABLE shift_v	: SIGNED(K - 1 DOWNTO 0);
	BEGIN
		diff_v := to_signed(2 * idx_n - (RES - 1), DIFF_W);
		prod_v := diff_v * RATIO_C;
		shift_v := resize(shift_right(prod_v, z + 1), K);
		RETURN resize(c + shift_v, K);
	END FUNCTION;

	PROCEDURE do_rst(
		SIGNAL rst_s		: OUT STD_LOGIC;
		SIGNAL en_s			: OUT STD_LOGIC;
		SIGNAL valid_in_s	: OUT STD_LOGIC;
		SIGNAL clk_s		: IN STD_LOGIC
	) IS
	BEGIN
		en_s		<= '0';
		valid_in_s	<= '0';
		rst_s		<= '1';
		WAIT UNTIL rising_edge(clk_s);
		rst_s		<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	PROCEDURE apply(
		CONSTANT c			: SIGNED;
		CONSTANT idx_n		: NATURAL;
		CONSTANT z			: NATURAL;
		CONSTANT vin		: STD_LOGIC;
		SIGNAL center_s		: OUT SIGNED(K - 1 DOWNTO 0);
		SIGNAL idx_s		: OUT UNSIGNED(W_IDX - 1 DOWNTO 0);
		SIGNAL zoom_s		: OUT UNSIGNED(W_ZOOM - 1 DOWNTO 0);
		SIGNAL valid_in_s	: OUT STD_LOGIC;
		SIGNAL en_s			: OUT STD_LOGIC;
		SIGNAL clk_s		: IN STD_LOGIC
	) IS
	BEGIN
		center_s	<= c;
		idx_s		<= to_unsigned(idx_n, W_IDX);
		zoom_s		<= to_unsigned(z, W_ZOOM);
		valid_in_s	<= vin;
		en_s		<= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s		<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	PROCEDURE check_point(
		CONSTANT c			: SIGNED;
		CONSTANT idx_n		: NATURAL;
		CONSTANT z			: NATURAL;
		CONSTANT msg		: STRING;
		SIGNAL center_s		: OUT SIGNED(K - 1 DOWNTO 0);
		SIGNAL idx_s		: OUT UNSIGNED(W_IDX - 1 DOWNTO 0);
		SIGNAL zoom_s		: OUT UNSIGNED(W_ZOOM - 1 DOWNTO 0);
		SIGNAL valid_in_s	: OUT STD_LOGIC;
		SIGNAL en_s			: OUT STD_LOGIC;
		SIGNAL clk_s		: IN STD_LOGIC;
		SIGNAL coord_s		: IN SIGNED(K - 1 DOWNTO 0);
		SIGNAL valid_out_s	: IN STD_LOGIC
	) IS
		VARIABLE exp : SIGNED(K - 1 DOWNTO 0);
	BEGIN
		apply(c, idx_n, z, '1', center_s, idx_s, zoom_s, valid_in_s, en_s, clk_s);
		exp := expected_coord(c, idx_n, z);
		check_equal(coord_s, exp, msg);
		check_equal(valid_out_s, '1', msg & " valid_out");
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.idx_to_coord
		GENERIC MAP(
			K		=> K,
			RES		=> RES,
			W_ZOOM	=> W_ZOOM,
			RATIO	=> RATIO_C
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			en			=> en,
			valid_in	=> valid_in,
			center		=> center,
			idx			=> idx,
			zoom		=> zoom,
			coord		=> coord,
			valid_out	=> valid_out
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE held : SIGNED(K - 1 DOWNTO 0);
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			do_rst(rst, en, valid_in, clk);

			IF run("corners_zoom0") THEN
				check_point(to_signed(0, K), 0, 0, "idx=0 zoom=0 center=0",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, K), RES - 1, 0, "idx=RES-1 zoom=0 center=0",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(ONE, 0, 0, "idx=0 zoom=0 center=1.0",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(-ONE, RES - 1, 0, "idx=RES-1 zoom=0 center=-1.0",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);

			ELSIF run("mid_pixel") THEN
				check_point(resize(3 * ONE, K), RES / 2, 0, "mid idx => coord=center",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);

			ELSIF run("zoom") THEN
				check_point(to_signed(0, K), 0, 1, "idx=0 zoom=1",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, K), RES - 1, 1, "idx=RES-1 zoom=1",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, K), 0, 2, "idx=0 zoom=2",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);
				check_point(to_signed(0, K), RES - 1, 2, "idx=RES-1 zoom=2",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);

			ELSIF run("en_hold") THEN
				check_equal(valid_out, '0', "valid_out after rst");

				check_point(to_signed(0, K), 0, 0, "load before hold",
					center, idx, zoom, valid_in, en, clk, coord, valid_out);
				held := coord;
				center		<= ONE;
				idx			<= to_unsigned(RES - 1, W_IDX);
				zoom		<= to_unsigned(1, W_ZOOM);
				valid_in	<= '0';
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(coord, held, "coord must hold when en=0");
				check_equal(valid_out, '1', "valid_out sticky when en=0");

				do_rst(rst, en, valid_in, clk);
				check_equal(valid_out, '0', "valid_out clears on rst");

			ELSIF run("valid_prop") THEN
				apply(to_signed(0, K), 0, 0, '0',
					center, idx, zoom, valid_in, en, clk);
				check_equal(valid_out, '0', "bubble: valid_out follows 0");

				apply(to_signed(0, K), RES - 1, 0, '1',
					center, idx, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "valid_out follows 1");
				check_equal(coord, expected_coord(to_signed(0, K), RES - 1, 0),
					"coord after valid sample");

			ELSIF run("sweep_idx") THEN
				IF RES <= 16 THEN
					FOR n IN 0 TO RES - 1 LOOP
						check_point(to_signed(0, K), n, 0, "sweep zoom=0",
							center, idx, zoom, valid_in, en, clk, coord, valid_out);
						check_point(to_signed(0, K), n, 1, "sweep zoom=1",
							center, idx, zoom, valid_in, en, clk, coord, valid_out);
					END LOOP;
				ELSE
					check_point(to_signed(0, K), 1, 0, "sweep idx=1",
						center, idx, zoom, valid_in, en, clk, coord, valid_out);
					check_point(to_signed(0, K), RES / 4, 0, "sweep idx=RES/4",
						center, idx, zoom, valid_in, en, clk, coord, valid_out);
					check_point(to_signed(0, K), (3 * RES) / 4, 1, "sweep idx=3RES/4 zoom=1",
						center, idx, zoom, valid_in, en, clk, coord, valid_out);
				END IF;
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
