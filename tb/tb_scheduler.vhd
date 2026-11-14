-- VUnit testbench for scheduler:
--   column-major scan: row varies fastest, then col
--   one-shot frame: after last pixel, next en clears valid (done sticky until rst)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_scheduler IS
	GENERIC (
		runner_cfg	: string;
		res_h         : natural := 3;
		res_v         : natural := 2
	);
END ENTITY tb_scheduler;

ARCHITECTURE sim OF tb_scheduler IS

	CONSTANT w_row         : natural := bits_of(res_v - 1);
	CONSTANT w_col         : natural := bits_of(res_h - 1);
	CONSTANT n_pix         : natural := res_h * res_v;
	CONSTANT clk_period	: time    := 10 ns;

	SIGNAL clk   : std_logic;
	SIGNAL rst   : std_logic;
	SIGNAL en    : std_logic;
	SIGNAL row   : unsigned(w_row - 1 DOWNTO 0);
	SIGNAL col   : unsigned(w_col - 1 DOWNTO 0);
	SIGNAL valid : std_logic;

	PROCEDURE do_rst (
		SIGNAL rst_s : OUT std_logic;
		SIGNAL en_s  : OUT std_logic;
		SIGNAL clk_s : IN std_logic
	) IS
	BEGIN

		en_s     <= '0';
		rst_s	<= '1';
		WAIT UNTIL rising_edge(clk_s);
		rst_s	<= '0';
		WAIT FOR 1 ns;

	END PROCEDURE do_rst;

	PROCEDURE pulse_en (
		SIGNAL en_s  : OUT std_logic;
		SIGNAL clk_s : IN std_logic
	) IS
	BEGIN

		en_s	<= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s	<= '0';
		WAIT FOR 1 ns;

	END PROCEDURE pulse_en;

	-- column-major index -> (row, col)

	PROCEDURE expected_rc (
		CONSTANT idx : natural;
		VARIABLE r   : OUT natural;
		VARIABLE c   : OUT natural
	) IS
	BEGIN

		c := idx / RES_V;
		r := idx MOD RES_V;

	END PROCEDURE expected_rc;

BEGIN

	DUT : ENTITY work.scheduler
		GENERIC MAP (
			res_h	=> res_h,
			res_v	=> res_v
		)
		PORT MAP (
			clk   => clk,
			rst   => rst,
			en    => en,
			row   => row,
			col   => col,
			valid => valid
		);

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS IS

		VARIABLE exp_r     : natural;
		VARIABLE exp_c     : natural;
		VARIABLE held_r	: natural;
		VARIABLE held_c	: natural;

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
				pulse_en(en, clk);                                       -- advance to next pixel
				held_r := to_integer(row);
				held_c := to_integer(col);

				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(to_integer(row), held_r, "row holds when en=0");
				check_equal(to_integer(col), held_c, "col holds when en=0");
				check_equal(valid, '1', "valid sticky when en=0");
			ELSIF run("full_sweep") THEN

				FOR i IN 0 TO n_pix - 1 LOOP

					pulse_en(en, clk);
					expected_rc(i, exp_r, exp_c);
					check_equal(valid, '1', "valid during sweep @" & integer'image(i));
					check_equal(to_integer(row), exp_r, "row @" & integer'image(i));
					check_equal(to_integer(col), exp_c, "col @" & integer'image(i));

				END LOOP;

			ELSIF run("done_freezes") THEN
				-- present every pixel
				FOR i IN 0 TO n_pix - 1 LOOP

					pulse_en(en, clk);

				END LOOP;

				held_r := to_integer(row);
				held_c := to_integer(col);
				check_equal(held_r, res_v - 1, "last row");
				check_equal(held_c, res_h - 1, "last col");
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

				FOR i IN 0 TO n_pix LOOP

					pulse_en(en, clk);                                   -- through last pixel + done

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

END ARCHITECTURE sim;
