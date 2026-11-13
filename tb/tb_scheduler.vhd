-- VUnit testbench for scheduler:
--   column-major scan: row varies fastest, then col
--   one-shot frame: after last pixel, next en clears valid (done sticky until rst)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_scheduler IS
	GENERIC(
		runner_cfg	: STRING;
		RES_H		: NATURAL := 3;
		RES_V		: NATURAL := 2
	);
END tb_scheduler;

ARCHITECTURE sim OF tb_scheduler IS
	CONSTANT W_ROW		: NATURAL := bits_of(RES_V - 1);
	CONSTANT W_COL		: NATURAL := bits_of(RES_H - 1);
	CONSTANT N_PIX		: NATURAL := RES_H * RES_V;
	CONSTANT CLK_PERIOD	: TIME := 10 ns;

	SIGNAL clk		: STD_LOGIC := '0';
	SIGNAL rst		: STD_LOGIC := '0';
	SIGNAL en		: STD_LOGIC := '0';
	SIGNAL row		: UNSIGNED(W_ROW - 1 DOWNTO 0);
	SIGNAL col		: UNSIGNED(W_COL - 1 DOWNTO 0);
	SIGNAL valid	: STD_LOGIC;

	PROCEDURE do_rst(
		SIGNAL rst_s	: OUT STD_LOGIC;
		SIGNAL en_s		: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		en_s	<= '0';
		rst_s	<= '1';
		WAIT UNTIL rising_edge(clk_s);
		rst_s	<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	PROCEDURE pulse_en(
		SIGNAL en_s		: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		en_s	<= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s	<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	-- column-major index -> (row, col)
	PROCEDURE expected_rc(
		CONSTANT idx	: NATURAL;
		VARIABLE r		: OUT NATURAL;
		VARIABLE c		: OUT NATURAL
	) IS
	BEGIN
		c := idx / RES_V;
		r := idx MOD RES_V;
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.scheduler
		GENERIC MAP(
			RES_H	=> RES_H,
			RES_V	=> RES_V
		)
		PORT MAP(
			clk		=> clk,
			rst		=> rst,
			en		=> en,
			row		=> row,
			col		=> col,
			valid	=> valid
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE exp_r	: NATURAL;
		VARIABLE exp_c	: NATURAL;
		VARIABLE held_r	: NATURAL;
		VARIABLE held_c	: NATURAL;
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			do_rst(rst, en, clk);

			IF run("after_rst") THEN
				check_equal(valid, '0', "valid after rst");

			ELSIF run("start") THEN
				pulse_en(en, clk);
				check_equal(valid, '1', "valid after first en");
				check_equal(to_integer(row), 0, "row starts at 0");
				check_equal(to_integer(col), 0, "col starts at 0");

			ELSIF run("en_hold") THEN
				pulse_en(en, clk);
				pulse_en(en, clk);  -- advance to next pixel
				held_r := to_integer(row);
				held_c := to_integer(col);

				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(to_integer(row), held_r, "row holds when en=0");
				check_equal(to_integer(col), held_c, "col holds when en=0");
				check_equal(valid, '1', "valid sticky when en=0");

			ELSIF run("full_sweep") THEN
				FOR i IN 0 TO N_PIX - 1 LOOP
					pulse_en(en, clk);
					expected_rc(i, exp_r, exp_c);
					check_equal(valid, '1', "valid during sweep @" & integer'image(i));
					check_equal(to_integer(row), exp_r, "row @" & integer'image(i));
					check_equal(to_integer(col), exp_c, "col @" & integer'image(i));
				END LOOP;

			ELSIF run("done_freezes") THEN
				-- present every pixel
				FOR i IN 0 TO N_PIX - 1 LOOP
					pulse_en(en, clk);
				END LOOP;
				held_r := to_integer(row);
				held_c := to_integer(col);
				check_equal(held_r, RES_V - 1, "last row");
				check_equal(held_c, RES_H - 1, "last col");
				check_equal(valid, '1', "valid high on last pixel");

				-- next en: done + valid falls; coords hold
				pulse_en(en, clk);
				check_equal(valid, '0', "valid falls after frame");
				check_equal(to_integer(row), held_r, "row frozen after done");
				check_equal(to_integer(col), held_c, "col frozen after done");

				pulse_en(en, clk);
				check_equal(valid, '0', "stays invalid without rst");
				check_equal(to_integer(row), held_r, "still frozen");
				check_equal(to_integer(col), held_c, "still frozen");

			ELSIF run("restart_after_rst") THEN
				FOR i IN 0 TO N_PIX LOOP
					pulse_en(en, clk);  -- through last pixel + done
				END LOOP;

				do_rst(rst, en, clk);
				check_equal(valid, '0', "valid cleared for restart");

				pulse_en(en, clk);
				check_equal(valid, '1', "valid after restart");
				check_equal(to_integer(row), 0, "row restarts at 0");
				check_equal(to_integer(col), 0, "col restarts at 0");
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
