-- VUnit testbench for counter: saturating up/down 0 .. MAX

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_counter IS
	GENERIC(
		runner_cfg	: STRING;
		MAX			: NATURAL := 7
	);
END tb_counter;

ARCHITECTURE sim OF tb_counter IS
	CONSTANT W_CNT		: NATURAL := bits_of(MAX);
	CONSTANT CLK_PERIOD	: TIME := 10 ns;

	SIGNAL clk		: STD_LOGIC := '0';
	SIGNAL rst		: STD_LOGIC := '0';
	SIGNAL inc		: STD_LOGIC := '0';
	SIGNAL dec_s	: STD_LOGIC := '0';
	SIGNAL cnt		: UNSIGNED(W_CNT - 1 DOWNTO 0);

	PROCEDURE tick(SIGNAL clk_s : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk_s);
	END PROCEDURE;

	PROCEDURE do_rst(
		SIGNAL rst_s	: OUT STD_LOGIC;
		SIGNAL inc_s	: OUT STD_LOGIC;
		SIGNAL dec_o	: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		inc_s	<= '0';
		dec_o	<= '0';
		rst_s	<= '1';
		tick(clk_s);
		rst_s	<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	PROCEDURE pulse_inc(
		SIGNAL inc_s	: OUT STD_LOGIC;
		SIGNAL dec_o	: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		inc_s	<= '1';
		dec_o	<= '0';
		tick(clk_s);
		inc_s	<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	PROCEDURE pulse_dec(
		SIGNAL inc_s	: OUT STD_LOGIC;
		SIGNAL dec_o	: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		inc_s	<= '0';
		dec_o	<= '1';
		tick(clk_s);
		dec_o	<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.counter
		GENERIC MAP(MAX => MAX)
		PORT MAP(
			clk	=> clk,
			rst	=> rst,
			inc	=> inc,
			dec	=> dec_s,
			cnt	=> cnt
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE held : NATURAL;
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			do_rst(rst, inc, dec_s, clk);

			IF run("after_rst") THEN
				check_equal(to_integer(cnt), 0, "cnt after rst");

			ELSIF run("inc") THEN
				FOR i IN 1 TO maximum(1, MAX / 2) LOOP
					pulse_inc(inc, dec_s, clk);
					check_equal(to_integer(cnt), i, "inc step");
				END LOOP;

			ELSIF run("dec") THEN
				FOR i IN 1 TO MAX LOOP
					pulse_inc(inc, dec_s, clk);
				END LOOP;
				check_equal(to_integer(cnt), MAX, "at max before dec");

				FOR i IN 1 TO maximum(1, MAX / 2) LOOP
					pulse_dec(inc, dec_s, clk);
					check_equal(to_integer(cnt), MAX - i, "dec step");
				END LOOP;

			ELSIF run("sat_high") THEN
				FOR i IN 1 TO MAX + 3 LOOP
					pulse_inc(inc, dec_s, clk);
				END LOOP;
				check_equal(to_integer(cnt), MAX, "saturates at MAX");

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

				inc		<= '1';
				dec_s	<= '1';
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
END sim;
