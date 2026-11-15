-- VUnit testbench for counter: saturating up/down 0 .. MAX

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_counter IS
	GENERIC (
		runner_cfg	: string;
		max           : natural := 7
	);
END ENTITY tb_counter;

ARCHITECTURE sim OF tb_counter IS

	CONSTANT w_cnt         : natural := bits_of(max);
	CONSTANT clk_period	: time    := 10 ns;

	SIGNAL clk   : std_logic := '0';
	SIGNAL rst   : std_logic;
	SIGNAL inc   : std_logic;
	SIGNAL dec_s : std_logic;
	SIGNAL cnt   : unsigned(w_cnt - 1 DOWNTO 0);

	PROCEDURE tick (
		SIGNAL clk_s : IN std_logic
	) IS
	BEGIN

		WAIT UNTIL rising_edge(clk_s);

	END PROCEDURE tick;

	PROCEDURE do_rst (
		SIGNAL rst_s	: OUT std_logic;
		SIGNAL inc_s	: OUT std_logic;
		SIGNAL dec_o	: OUT std_logic;
		SIGNAL clk_s	: IN std_logic
	) IS
	BEGIN

		inc_s	<= '0';
		dec_o	<= '0';
		rst_s	<= '1';
		tick(clk_s);
		rst_s	<= '0';
		WAIT FOR 1 ns;

	END PROCEDURE do_rst;

	PROCEDURE pulse_inc (
		SIGNAL inc_s	: OUT std_logic;
		SIGNAL dec_o	: OUT std_logic;
		SIGNAL clk_s	: IN std_logic
	) IS
	BEGIN

		inc_s	<= '1';
		dec_o	<= '0';
		tick(clk_s);
		inc_s	<= '0';
		WAIT FOR 1 ns;

	END PROCEDURE pulse_inc;

	PROCEDURE pulse_dec (
		SIGNAL inc_s	: OUT std_logic;
		SIGNAL dec_o	: OUT std_logic;
		SIGNAL clk_s	: IN std_logic
	) IS
	BEGIN

		inc_s	<= '0';
		dec_o	<= '1';
		tick(clk_s);
		dec_o	<= '0';
		WAIT FOR 1 ns;

	END PROCEDURE pulse_dec;

BEGIN

	DUT : ENTITY work.counter
		GENERIC MAP (
			max => max
		)
		PORT MAP (
			clk	=> clk,
			rst	=> rst,
			inc	=> inc,
			dec	=> dec_s,
			cnt	=> cnt
		);

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS IS

		VARIABLE held : natural;

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			do_rst(rst, inc, dec_s, clk);

			IF run("after_rst") THEN
				check_equal(to_integer(cnt), 0, "cnt after rst");
			ELSIF run("inc") THEN

				FOR i IN 1 TO maximum(1, max / 2) LOOP

					pulse_inc(inc, dec_s, clk);
					check_equal(to_integer(cnt), i, "inc step");

				END LOOP;

			ELSIF run("dec") THEN

				FOR i IN 1 TO max LOOP

					pulse_inc(inc, dec_s, clk);

				END LOOP;

				check_equal(to_integer(cnt), max, "at max before dec");

				FOR i IN 1 TO maximum(1, max / 2) LOOP

					pulse_dec(inc, dec_s, clk);
					check_equal(to_integer(cnt), max - i, "dec step");

				END LOOP;

			ELSIF run("sat_high") THEN

				FOR i IN 1 TO max + 3 LOOP

					pulse_inc(inc, dec_s, clk);

				END LOOP;

				check_equal(to_integer(cnt), max, "saturates at MAX");
			ELSIF run("sat_low") THEN
				pulse_inc(inc, dec_s, clk);

				FOR i IN 1 TO 5 LOOP

					pulse_dec(inc, dec_s, clk);

				END LOOP;

				check_equal(to_integer(cnt), 0, "saturates at 0");
			ELSIF run("both_hold") THEN
				pulse_inc(inc, dec_s, clk);
				pulse_inc(inc, dec_s, clk);
				held := to_integer(cnt);

				inc   <= '1';
				dec_s <= '1';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(to_integer(cnt), held, "inc and dec both 1 => hold");
			ELSIF run("idle_hold") THEN
				pulse_inc(inc, dec_s, clk);
				held := to_integer(cnt);
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(to_integer(cnt), held, "idle holds");
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
