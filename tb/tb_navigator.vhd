-- VUnit testbench for navigator (2x pan + zoom counter)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_navigator IS
	GENERIC(
		runner_cfg	: STRING;
		K			: NATURAL := 16;
		ZOOM_MAX	: NATURAL := 5;
		DELTA_FP	: INTEGER := 256
	);
END tb_navigator;

ARCHITECTURE sim OF tb_navigator IS
	CONSTANT W_ZOOM		: NATURAL := bits_of(ZOOM_MAX);
	CONSTANT CLK_PERIOD	: TIME := 10 ns;
	CONSTANT DELTA_C	: SIGNED(K - 1 DOWNTO 0) := to_signed(DELTA_FP, K);

	SIGNAL clk			: STD_LOGIC := '0';
	SIGNAL rst			: STD_LOGIC := '0';
	SIGNAL inc_x		: STD_LOGIC := '0';
	SIGNAL dec_x		: STD_LOGIC := '0';
	SIGNAL inc_y		: STD_LOGIC := '0';
	SIGNAL dec_y		: STD_LOGIC := '0';
	SIGNAL inc_zoom		: STD_LOGIC := '0';
	SIGNAL dec_zoom		: STD_LOGIC := '0';
	SIGNAL center_x		: SIGNED(K - 1 DOWNTO 0);
	SIGNAL center_y		: SIGNED(K - 1 DOWNTO 0);
	SIGNAL zoom			: UNSIGNED(W_ZOOM - 1 DOWNTO 0);

	FUNCTION step_of(CONSTANT z : NATURAL) RETURN SIGNED IS
		VARIABLE d : SIGNED(K - 1 DOWNTO 0);
	BEGIN
		d := shift_right(resize(DELTA_C, K), z);
		IF d = 0 THEN
			d := to_signed(1, K);
		END IF;
		RETURN d;
	END FUNCTION;

	PROCEDURE tick(SIGNAL clk_s : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk_s);
	END PROCEDURE;

	PROCEDURE do_rst(
		SIGNAL rst_s		: OUT STD_LOGIC;
		SIGNAL inc_x_s		: OUT STD_LOGIC;
		SIGNAL dec_x_s		: OUT STD_LOGIC;
		SIGNAL inc_y_s		: OUT STD_LOGIC;
		SIGNAL dec_y_s		: OUT STD_LOGIC;
		SIGNAL inc_z_s		: OUT STD_LOGIC;
		SIGNAL dec_z_s		: OUT STD_LOGIC;
		SIGNAL clk_s		: IN STD_LOGIC
	) IS
	BEGIN
		inc_x_s	<= '0';
		dec_x_s	<= '0';
		inc_y_s	<= '0';
		dec_y_s	<= '0';
		inc_z_s	<= '0';
		dec_z_s	<= '0';
		rst_s	<= '1';
		tick(clk_s);
		rst_s	<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	PROCEDURE clear_cmds(
		SIGNAL inc_x_s		: OUT STD_LOGIC;
		SIGNAL dec_x_s		: OUT STD_LOGIC;
		SIGNAL inc_y_s		: OUT STD_LOGIC;
		SIGNAL dec_y_s		: OUT STD_LOGIC;
		SIGNAL inc_z_s		: OUT STD_LOGIC;
		SIGNAL dec_z_s		: OUT STD_LOGIC
	) IS
	BEGIN
		inc_x_s	<= '0';
		dec_x_s	<= '0';
		inc_y_s	<= '0';
		dec_y_s	<= '0';
		inc_z_s	<= '0';
		dec_z_s	<= '0';
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.navigator
		GENERIC MAP(
			K			=> K,
			ZOOM_MAX	=> ZOOM_MAX,
			DELTA		=> DELTA_C
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			inc_x		=> inc_x,
			dec_x		=> dec_x,
			inc_y		=> inc_y,
			dec_y		=> dec_y,
			inc_zoom	=> inc_zoom,
			dec_zoom	=> dec_zoom,
			center_x	=> center_x,
			center_y	=> center_y,
			zoom		=> zoom
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE z : NATURAL;
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			do_rst(rst, inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom, clk);

			IF run("after_rst") THEN
				check_equal(center_x, 0, "center_x after rst");
				check_equal(center_y, 0, "center_y after rst");
				check_equal(to_integer(zoom), 0, "zoom after rst");

			ELSIF run("pan_axes") THEN
				-- X and Y independent at zoom=0
				inc_x <= '1';
				tick(clk);
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				check_equal(center_x, step_of(0), "inc_x");
				check_equal(center_y, 0, "y untouched");

				inc_y <= '1';
				tick(clk);
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				check_equal(center_x, step_of(0), "x holds");
				check_equal(center_y, step_of(0), "inc_y");

				dec_x <= '1';
				tick(clk);
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				check_equal(center_x, 0, "dec_x");
				check_equal(center_y, step_of(0), "y holds");

			ELSIF run("zoom_sat") THEN
				FOR i IN 1 TO ZOOM_MAX + 3 LOOP
					inc_zoom <= '1';
					tick(clk);
				END LOOP;
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				check_equal(to_integer(zoom), ZOOM_MAX, "zoom sat high");

				FOR i IN 1 TO ZOOM_MAX + 3 LOOP
					dec_zoom <= '1';
					tick(clk);
				END LOOP;
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				check_equal(to_integer(zoom), 0, "zoom sat low");

			ELSIF run("zoom_scales_pan") THEN
				-- zoom in once, then pan X: step must use new zoom
				inc_zoom <= '1';
				tick(clk);
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				z := to_integer(zoom);
				check_equal(z, 1, "zoom=1");

				inc_x <= '1';
				tick(clk);
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				check_equal(center_x, step_of(z), "pan uses zoom");
				check_equal(center_y, 0, "y still 0");

			ELSIF run("simultaneous") THEN
				-- pan both axes and zoom same cycle
				inc_x		<= '1';
				inc_y		<= '1';
				inc_zoom	<= '1';
				tick(clk);
				clear_cmds(inc_x, dec_x, inc_y, dec_y, inc_zoom, dec_zoom);
				WAIT FOR 1 ns;
				-- zoom updates same cycle; pan reads zoom_i registered value
				-- pan uses zoom BEFORE this cycle's counter update (old zoom=0)
				check_equal(to_integer(zoom), 1, "zoom advanced");
				check_equal(center_x, step_of(0), "pan X used zoom=0");
				check_equal(center_y, step_of(0), "pan Y used zoom=0");
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
