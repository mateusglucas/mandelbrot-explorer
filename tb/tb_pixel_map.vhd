-- VUnit testbench for pixel_map (2x idx_to_coord + calc_addr, aligned)
-- Contract: valid_x = valid_y = valid_addr every settled cycle

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_pixel_map IS
	GENERIC(
		runner_cfg	: STRING;
		K			: NATURAL := 16;
		RES_H		: NATURAL := 5;
		RES_V		: NATURAL := 4;
		W_ZOOM		: NATURAL := 3;
		RATIO_FP	: INTEGER := 4096;
		LAT_COORD	: NATURAL := 1;
		LAT_ADDR	: NATURAL := 1
	);
END tb_pixel_map;

ARCHITECTURE sim OF tb_pixel_map IS
	CONSTANT W_ROW		: NATURAL := bits_of(RES_V - 1);
	CONSTANT W_COL		: NATURAL := bits_of(RES_H - 1);
	CONSTANT W_ADDR		: NATURAL := bits_of(RES_H * RES_V - 1);
	CONSTANT LAT_MAX	: NATURAL := maximum(LAT_COORD, LAT_ADDR);
	CONSTANT CLK_PERIOD	: TIME := 10 ns;
	CONSTANT RATIO_C	: SIGNED(K - 1 DOWNTO 0) := to_signed(RATIO_FP, K);
	CONSTANT ONE		: SIGNED(K - 1 DOWNTO 0) := to_signed(2 ** (K - 4), K);

	SIGNAL clk			: STD_LOGIC := '0';
	SIGNAL rst			: STD_LOGIC := '0';
	SIGNAL en			: STD_LOGIC := '0';
	SIGNAL valid_in		: STD_LOGIC := '0';
	SIGNAL row			: UNSIGNED(W_ROW - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL col			: UNSIGNED(W_COL - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL center_x		: SIGNED(K - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL center_y		: SIGNED(K - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL zoom			: UNSIGNED(W_ZOOM - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL x			: SIGNED(K - 1 DOWNTO 0);
	SIGNAL y			: SIGNED(K - 1 DOWNTO 0);
	SIGNAL addr			: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL valid_x		: STD_LOGIC;
	SIGNAL valid_y		: STD_LOGIC;
	SIGNAL valid_addr	: STD_LOGIC;
	SIGNAL valid_out	: STD_LOGIC;

	SIGNAL watch_valids	: BOOLEAN := FALSE;

	FUNCTION expected_coord(
		CONSTANT c		: SIGNED;
		CONSTANT idx_n	: NATURAL;
		CONSTANT res	: NATURAL;
		CONSTANT z		: NATURAL
	) RETURN SIGNED IS
		CONSTANT DIFF_W	: NATURAL := bits_of(res - 1) + 1;
		VARIABLE diff_v	: SIGNED(DIFF_W - 1 DOWNTO 0);
		VARIABLE prod_v	: SIGNED(RATIO_C'LENGTH + DIFF_W - 1 DOWNTO 0);
		VARIABLE shift_v	: SIGNED(K - 1 DOWNTO 0);
	BEGIN
		diff_v := to_signed(2 * idx_n - (res - 1), DIFF_W);
		prod_v := diff_v * RATIO_C;
		shift_v := resize(shift_right(prod_v, z + 1), K);
		RETURN resize(c + shift_v, K);
	END FUNCTION;

	PROCEDURE check_valids_eq IS
	BEGIN
		check_equal(valid_x, valid_y, "valid_x == valid_y");
		check_equal(valid_y, valid_addr, "valid_y == valid_addr");
		check_equal(valid_out, valid_x AND valid_y AND valid_addr, "valid_out is AND");
	END PROCEDURE;

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

	-- one sample; then extra en pulses to finish LAT_MAX pipeline
	PROCEDURE push(
		CONSTANT r			: NATURAL;
		CONSTANT c			: NATURAL;
		CONSTANT cx			: SIGNED;
		CONSTANT cy			: SIGNED;
		CONSTANT z			: NATURAL;
		CONSTANT vin		: STD_LOGIC;
		SIGNAL row_s		: OUT UNSIGNED(W_ROW - 1 DOWNTO 0);
		SIGNAL col_s		: OUT UNSIGNED(W_COL - 1 DOWNTO 0);
		SIGNAL center_x_s	: OUT SIGNED(K - 1 DOWNTO 0);
		SIGNAL center_y_s	: OUT SIGNED(K - 1 DOWNTO 0);
		SIGNAL zoom_s		: OUT UNSIGNED(W_ZOOM - 1 DOWNTO 0);
		SIGNAL valid_in_s	: OUT STD_LOGIC;
		SIGNAL en_s			: OUT STD_LOGIC;
		SIGNAL clk_s		: IN STD_LOGIC
	) IS
	BEGIN
		row_s		<= to_unsigned(r, W_ROW);
		col_s		<= to_unsigned(c, W_COL);
		center_x_s	<= cx;
		center_y_s	<= cy;
		zoom_s		<= to_unsigned(z, W_ZOOM);
		valid_in_s	<= vin;
		en_s		<= '1';
		WAIT UNTIL rising_edge(clk_s);
		FOR i IN 2 TO LAT_MAX LOOP
			WAIT UNTIL rising_edge(clk_s);
		END LOOP;
		en_s <= '0';
		WAIT FOR 1 ns;
		check_valids_eq;
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.pixel_map
		GENERIC MAP(
			K			=> K,
			RES_H		=> RES_H,
			RES_V		=> RES_V,
			W_ZOOM		=> W_ZOOM,
			RATIO		=> RATIO_C,
			LAT_COORD	=> LAT_COORD,
			LAT_ADDR	=> LAT_ADDR
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			en			=> en,
			valid_in	=> valid_in,
			row			=> row,
			col			=> col,
			center_x	=> center_x,
			center_y	=> center_y,
			zoom		=> zoom,
			x			=> x,
			y			=> y,
			addr		=> addr,
			valid_x		=> valid_x,
			valid_y		=> valid_y,
			valid_addr	=> valid_addr,
			valid_out	=> valid_out
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	-- watch equality on every clock while a test runs
	PROCESS
	BEGIN
		WAIT UNTIL rising_edge(clk);
		WAIT FOR 1 ns;
		IF watch_valids AND rst = '0' THEN
			check_valids_eq;
		END IF;
	END PROCESS;

	PROCESS
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
				push(0, 0, to_signed(0, K), to_signed(0, K), 0, '1',
					row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "valid at 0,0");
				check_equal(to_integer(addr), 0, "addr 0,0");
				check_equal(x, expected_coord(to_signed(0, K), 0, RES_H, 0), "x 0,0");
				check_equal(y, expected_coord(to_signed(0, K), 0, RES_V, 0), "y 0,0");

				push(0, RES_H - 1, to_signed(0, K), ONE, 0, '1',
					row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(to_integer(addr), RES_H - 1, "addr top-right");
				check_equal(x, expected_coord(to_signed(0, K), RES_H - 1, RES_H, 0), "x top-right");
				check_equal(y, expected_coord(ONE, 0, RES_V, 0), "y top-right");

				push(RES_V - 1, 0, ONE, to_signed(0, K), 0, '1',
					row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(to_integer(addr), RES_H * (RES_V - 1), "addr bottom-left");

				push(RES_V - 1, RES_H - 1, -ONE, ONE, 1, '1',
					row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(to_integer(addr), RES_H * RES_V - 1, "addr last");
				check_equal(x, expected_coord(-ONE, RES_H - 1, RES_H, 1), "x last");
				check_equal(y, expected_coord(ONE, RES_V - 1, RES_V, 1), "y last");

			ELSIF run("valid_prop") THEN
				push(1, 2, to_signed(0, K), to_signed(0, K), 0, '0',
					row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '0', "bubble stays invalid");

				push(1, 2, to_signed(0, K), to_signed(0, K), 0, '1',
					row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "valid sample");
				check_equal(to_integer(addr), RES_H * 1 + 2, "addr after valid");

			ELSIF run("en_hold") THEN
				push(2, 3, to_signed(0, K), to_signed(0, K), 0, '1',
					row, col, center_x, center_y, zoom, valid_in, en, clk);
				check_equal(valid_out, '1', "loaded");

				row			<= to_unsigned(0, W_ROW);
				col			<= to_unsigned(0, W_COL);
				valid_in	<= '0';
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(valid_out, '1', "valid sticky when en=0");
				check_equal(to_integer(addr), RES_H * 2 + 3, "addr holds");
				check_valids_eq;

			ELSIF run("sweep") THEN
				FOR r IN 0 TO RES_V - 1 LOOP
					FOR c IN 0 TO RES_H - 1 LOOP
						push(r, c, to_signed(0, K), to_signed(0, K), 0, '1',
							row, col, center_x, center_y, zoom, valid_in, en, clk);
						check_equal(valid_out, '1', "sweep valid");
						check_equal(to_integer(addr), RES_H * r + c, "sweep addr");
						check_equal(x, expected_coord(to_signed(0, K), c, RES_H, 0), "sweep x");
						check_equal(y, expected_coord(to_signed(0, K), r, RES_V, 0), "sweep y");
					END LOOP;
				END LOOP;
			END IF;

			watch_valids <= FALSE;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
