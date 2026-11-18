-- VUnit testbench for pixel_map (2x idx_to_coord + calc_addr, aligned)
-- Contract: valid_x = valid_y = valid_addr every settled cycle

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_pixel_map IS
	GENERIC (
		runner_cfg          : string;
		k                   : natural := 16;
		res_h               : natural := 5;
		res_v               : natural := 4;
		w_zoom              : natural := 3;
		zoom_bits_per_stage : natural := 2;
		ratio_fp            : integer := 4096
	);
END ENTITY tb_pixel_map;

ARCHITECTURE sim OF tb_pixel_map IS

	CONSTANT w_row         : natural                := bits_of(res_v - 1);
	CONSTANT w_col         : natural                := bits_of(res_h - 1);
	CONSTANT w_addr		: natural                := bits_of(res_h * res_v - 1);
	CONSTANT lat_coord     : natural                := (w_zoom + zoom_bits_per_stage - 1) / zoom_bits_per_stage + 2;
	CONSTANT lat_addr      : natural                := 1;
	CONSTANT lat_max       : natural                := maximum(lat_coord, lat_addr);
	CONSTANT clk_period	: time                   := 10 ns;
	CONSTANT ratio_c       : signed(k - 1 DOWNTO 0) := to_signed(ratio_fp, k);
	CONSTANT one           : signed(k - 1 DOWNTO 0) := to_signed(2 ** (k - 4), k);

	SIGNAL clk        : std_logic := '0';
	SIGNAL rst        : std_logic;
	SIGNAL en         : std_logic;
	SIGNAL valid_in   : std_logic;
	SIGNAL row        : unsigned(w_row - 1 DOWNTO 0);
	SIGNAL col        : unsigned(w_col - 1 DOWNTO 0);
	SIGNAL center_x   : signed(k - 1 DOWNTO 0);
	SIGNAL center_y   : signed(k - 1 DOWNTO 0);
	SIGNAL zoom       : unsigned(w_zoom - 1 DOWNTO 0);
	SIGNAL x          : signed(k - 1 DOWNTO 0);
	SIGNAL y          : signed(k - 1 DOWNTO 0);
	SIGNAL addr       : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL valid_x    : std_logic;
	SIGNAL valid_y    : std_logic;
	SIGNAL valid_addr : std_logic;
	SIGNAL valid_out  : std_logic;

	SIGNAL watch_valids	: boolean;

	FUNCTION expected_coord (
		CONSTANT c		: signed;
		CONSTANT idx_n	: natural;
		CONSTANT res	: natural;
		CONSTANT z		: natural
	) RETURN signed IS

		CONSTANT diff_w     : natural := bits_of(res - 1) + 1;
		VARIABLE diff_v     : signed(diff_w - 1 DOWNTO 0);
		VARIABLE prod_v     : signed(RATIO_C'LENGTH + diff_w - 1 DOWNTO 0);
		VARIABLE shift_v	: signed(K - 1 DOWNTO 0);

	BEGIN

		diff_v  := to_signed(2 * idx_n - (res - 1), diff_w);
		prod_v  := diff_v * RATIO_C;
		shift_v := resize(shift_right(prod_v, z + 1), K);
		RETURN resize(c + shift_v, K);

	END FUNCTION expected_coord;

	PROCEDURE check_valids_eq IS
	BEGIN

		check_equal(valid_x, valid_y, "valid_x == valid_y");
		check_equal(valid_y, valid_addr, "valid_y == valid_addr");
		check_equal(valid_out, valid_x AND valid_y AND valid_addr, "valid_out is AND");

	END PROCEDURE check_valids_eq;

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

	-- one sample; then extra en pulses to finish LAT_MAX pipeline

	PROCEDURE push (
		CONSTANT r           : natural;
		CONSTANT c           : natural;
		CONSTANT cx          : signed;
		CONSTANT cy          : signed;
		CONSTANT z           : natural;
		CONSTANT vin         : std_logic;
		SIGNAL row_s         : OUT unsigned(w_row - 1 DOWNTO 0);
		SIGNAL col_s         : OUT unsigned(w_col - 1 DOWNTO 0);
		SIGNAL center_x_s	: OUT signed(K - 1 DOWNTO 0);
		SIGNAL center_y_s	: OUT signed(K - 1 DOWNTO 0);
		SIGNAL zoom_s		: OUT unsigned(W_ZOOM - 1 DOWNTO 0);
		SIGNAL valid_in_s	: OUT std_logic;
		SIGNAL en_s          : OUT std_logic;
		SIGNAL clk_s         : IN std_logic
	) IS
	BEGIN

		row_s         <= to_unsigned(r, W_ROW);
		col_s         <= to_unsigned(c, W_COL);
		center_x_s	<= cx;
		center_y_s	<= cy;
		zoom_s		<= to_unsigned(z, W_ZOOM);
		valid_in_s	<= vin;
		en_s          <= '1';
		WAIT UNTIL rising_edge(clk_s);

		FOR i IN 2 TO LAT_MAX LOOP

			WAIT UNTIL rising_edge(clk_s);

		END LOOP;

		en_s <= '0';
		WAIT FOR 1 ns;
		check_valids_eq;

	END PROCEDURE push;

BEGIN

	DUT : ENTITY work.pixel_map
		GENERIC MAP (
			k                   => k,
			res_h               => res_h,
			res_v               => res_v,
			w_zoom              => w_zoom,
			zoom_bits_per_stage => zoom_bits_per_stage,
			ratio               => RATIO_C
		)
		PORT MAP (
			clk           => clk,
			rst           => rst,
			en			=> en,
			valid_in      => valid_in,
			row           => row,
			col           => col,
			center_x      => center_x,
			center_y      => center_y,
			zoom          => zoom,
			x             => x,
			y             => y,
			addr          => addr,
			valid_x       => valid_x,
			valid_y       => valid_y,
			valid_addr	=> valid_addr,
			valid_out     => valid_out
		);

	clk <= NOT clk AFTER clk_period / 2;

	-- watch equality on every clock while a test runs
	PROCESS IS
	BEGIN

		WAIT UNTIL rising_edge(clk);
		WAIT FOR 1 ns;

		IF (watch_valids AND rst = '0') THEN
			check_valids_eq;
		END IF;

	END PROCESS;

	PROCESS IS
	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			watch_valids <= FALSE;
			do_rst(rst, en, valid_in, clk);
			watch_valids <= TRUE;

			IF run("after_rst") THEN
				check_equal(valid_out, '0', "valid_out after rst");
				check_valids_eq;
			ELSIF run("corners") THEN
				push(0, 0, to_signed(0, k), to_signed(0, k), 0, '1',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "valid at 0,0");
				check_equal(to_integer(addr), 0, "addr 0,0");
				check_equal(x, expected_coord(to_signed(0, k), 0, res_h, 0), "x 0,0");
				check_equal(y, expected_coord(to_signed(0, k), 0, res_v, 0), "y 0,0");

				push(0, res_h - 1, to_signed(0, k), ONE, 0, '1',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(to_integer(addr), res_h - 1, "addr top-right");
				check_equal(x, expected_coord(to_signed(0, k), res_h - 1, res_h, 0), "x top-right");
				check_equal(y, expected_coord(ONE, 0, res_v, 0), "y top-right");

				push(res_v - 1, 0, ONE, to_signed(0, k), 0, '1',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(to_integer(addr), res_h * (res_v - 1), "addr bottom-left");

				push(res_v - 1, res_h - 1, -ONE, ONE, 1, '1',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(to_integer(addr), res_h * res_v - 1, "addr last");
				check_equal(x, expected_coord(-ONE, res_h - 1, res_h, 1), "x last");
				check_equal(y, expected_coord(ONE, res_v - 1, res_v, 1), "y last");
			ELSIF run("valid_prop") THEN
				push(1, 2, to_signed(0, k), to_signed(0, k), 0, '0',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '0', "bubble stays invalid");

				push(1, 2, to_signed(0, k), to_signed(0, k), 0, '1',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "valid sample");
				check_equal(to_integer(addr), res_h * 1 + 2, "addr after valid");
			ELSIF run("en_hold") THEN
				push(2, 3, to_signed(0, k), to_signed(0, k), 0, '1',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "loaded");

				row      <= to_unsigned(0, w_row);
				col      <= to_unsigned(0, w_col);
				valid_in <= '0';
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(valid_out, '1', "valid sticky when en=0");
				check_equal(to_integer(addr), res_h * 2 + 3, "addr holds");
				check_valids_eq;
			ELSIF run("sweep") THEN

				FOR r IN 0 TO res_v - 1 LOOP

					FOR c IN 0 TO res_h - 1 LOOP

						push(r, c, to_signed(0, k), to_signed(0, k), 0, '1',
	     row, col, center_x, center_y, zoom, valid_in, en, clk);
						check_equal(valid_out, '1', "sweep valid");
						check_equal(to_integer(addr), res_h * r + c, "sweep addr");
						check_equal(x, expected_coord(to_signed(0, k), c, res_h, 0), "sweep x");
						check_equal(y, expected_coord(to_signed(0, k), r, res_v, 0), "sweep y");

					END LOOP;

				END LOOP;

			END IF;

			watch_valids <= FALSE;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
