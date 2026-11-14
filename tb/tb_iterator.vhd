-- VUnit testbench for iterator (Mandelbrot z <- z^2 + c)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE ieee.math_real.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_iterator IS
	GENERIC (
		runner_cfg	: string;
		k             : natural := 36;
		i             : natural := 4;
		max_iter      : natural := 32;
		w_addr		: natural := 8
	);
END ENTITY tb_iterator;

ARCHITECTURE sim OF tb_iterator IS

	CONSTANT w_iter		: natural := bits_of(max_iter);
	CONSTANT clk_period	: time    := 10 ns;
	CONSTANT f             : natural := k - i;  -- fractional bits

	SIGNAL clk         : std_logic;
	SIGNAL rst         : std_logic;
	SIGNAL load		: std_logic;
	SIGNAL x_c         : signed(k - 1 DOWNTO 0);
	SIGNAL y_c         : signed(k - 1 DOWNTO 0);
	SIGNAL addr		: unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL done		: std_logic;
	SIGNAL iter		: unsigned(w_iter - 1 DOWNTO 0);
	SIGNAL addr_out	: unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL empty       : std_logic;

	-- real -> Q(I.F): parte inteira << F, depois *2 extraindo bits fracionários.

	FUNCTION to_fp (
		v : real
	) RETURN signed IS

		VARIABLE x      : real;
		VARIABLE r      : signed(K - 1 DOWNTO 0);
		VARIABLE neg	: boolean;
		VARIABLE ip     : integer;

	BEGIN

		neg := v < 0.0;
		x   := ABS(v);
		-- INTEGER(real) arredonda (0.75->1); FLOOR trunca para baixo
		ip := INTEGER(FLOOR(x));
		x  := x - REAL(ip);
		r  := shift_left(to_signed(ip, K), F);

		FOR i IN F - 1 DOWNTO 0 LOOP

			x := x * 2.0;

			IF (x >= 1.0) THEN
				r(i) := '1';
				x    := x - 1.0;
			END IF;

		END LOOP;

		IF (neg) THEN
			r := -r;
		END IF;

		RETURN r;

	END FUNCTION to_fp;

	PROCEDURE tick (
		SIGNAL clk_s : IN std_logic
	) IS
	BEGIN

		WAIT UNTIL rising_edge(clk_s);

	END PROCEDURE tick;

	PROCEDURE start_point (
		CONSTANT xc   : signed;
		CONSTANT yc   : signed;
		CONSTANT a    : natural;
		SIGNAL x_c_s  : OUT signed(K - 1 DOWNTO 0);
		SIGNAL y_c_s  : OUT signed(K - 1 DOWNTO 0);
		SIGNAL addr_s : OUT unsigned(W_ADDR - 1 DOWNTO 0);
		SIGNAL load_s : OUT std_logic;
		SIGNAL clk_s  : IN std_logic
	) IS
	BEGIN

		x_c_s     <= xc;
		y_c_s     <= yc;
		addr_s	<= to_unsigned(a, W_ADDR);
		load_s	<= '1';
		tick(clk_s);
		load_s	<= '0';

	END PROCEDURE start_point;

	-- Sample done after combo settles (avoids delta-cycle glitches on valid↑).

	PROCEDURE wait_done (
		SIGNAL done_s	: IN std_logic;
		SIGNAL clk_s     : IN std_logic
	) IS
	BEGIN

		WAIT FOR 1 ns;

		IF (done_s = '1') THEN
			RETURN;
		END IF;

		FOR i IN 0 TO MAX_ITER + 4 LOOP

			tick(clk_s);
			WAIT FOR 1 ns;

			IF (done_s = '1') THEN
				RETURN;
			END IF;

		END LOOP;

		check_equal(done_s, '1', "timeout waiting for done");

	END PROCEDURE wait_done;

	PROCEDURE expect_iter (
		CONSTANT xc          : signed;
		CONSTANT yc          : signed;
		CONSTANT a           : natural;
		CONSTANT exp_iter	: natural;
		CONSTANT msg         : string;
		SIGNAL x_c_s         : OUT signed(K - 1 DOWNTO 0);
		SIGNAL y_c_s         : OUT signed(K - 1 DOWNTO 0);
		SIGNAL addr_s		: OUT unsigned(W_ADDR - 1 DOWNTO 0);
		SIGNAL load_s		: OUT std_logic;
		SIGNAL clk_s         : IN std_logic;
		SIGNAL done_s		: IN std_logic;
		SIGNAL iter_s		: IN unsigned(w_iter - 1 DOWNTO 0);
		SIGNAL addr_out_s	: IN unsigned(W_ADDR - 1 DOWNTO 0)
	) IS

		VARIABLE exp_clamped : natural;

	BEGIN

		IF (exp_iter < MAX_ITER) THEN
			exp_clamped := exp_iter;
		ELSE
			exp_clamped := MAX_ITER;
		END IF;

		start_point(xc, yc, a, x_c_s, y_c_s, addr_s, load_s, clk_s);
		wait_done(done_s, clk_s);
		check_equal(iter_s, exp_clamped, msg);
		check_equal(addr_out_s, a, msg & " addr_out");

	END PROCEDURE expect_iter;

BEGIN

	DUT : ENTITY work.iterator
		GENERIC MAP (
			k        => k,
			i        => i,
			max_iter => max_iter,
			w_addr   => w_addr
		)
		PORT MAP (
			clk      => clk,
			rst      => rst,
			load     => load,
			x_c      => x_c,
			y_c      => y_c,
			addr     => addr,
			done     => done,
			iter     => iter,
			addr_out => addr_out,
			empty    => empty
		);

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS IS
	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			-- known idle state
			rst  <= '1';
			load <= '0';
			tick(clk);
			rst  <= '0';
			WAIT FOR 1 ns;

			IF run("escape_counts") THEN
				-- different escape depths (real axis)
				expect_iter(to_fp(3.0), to_fp(0.0), 1, 0, "c=3 -> iter 0",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(1.0), to_fp(0.0), 2, 1, "c=1 -> iter 1",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.75), to_fp(0.0), 3, 2, "c=0.75 -> iter 2",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.5), to_fp(0.0), 4, 4, "c=0.5 -> iter 4",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.0), to_fp(0.0), 5, max_iter, "c=0 -> MAX_ITER",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-1.0), to_fp(0.0), 6, max_iter, "c=-1 (in set) -> MAX_ITER",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);

				-- +/- imag: conjugate pairs should match; exercises y / 2xy path
				expect_iter(to_fp(-1.75), to_fp(0.75), 10, 1, "c=-1.75+0.75j -> iter 1",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-1.75), to_fp(-0.75), 11, 1, "c=-1.75-0.75j -> iter 1",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-1.75), to_fp(0.5), 12, 2, "c=-1.75+0.5j -> iter 2",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-1.75), to_fp(-0.5), 13, 2, "c=-1.75-0.5j -> iter 2",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-0.75), to_fp(0.5), 14, 5, "c=-0.75+0.5j -> iter 5",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-0.75), to_fp(-0.5), 15, 5, "c=-0.75-0.5j -> iter 5",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-0.75), to_fp(0.25), 16, 12, "c=-0.75+0.25j -> iter 12",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-0.75), to_fp(-0.25), 17, 12, "c=-0.75-0.25j -> iter 12",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.5), to_fp(0.5), 18, 4, "c=0.5+0.5j -> iter 4",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.0), to_fp(1.0), 19, max_iter, "c=0+1j (in set) -> MAX_ITER",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.0), to_fp(-1.0), 20, max_iter, "c=0-1j (in set) -> MAX_ITER",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.25), to_fp(0.75), 21, 4, "c=0.25+0.75j -> iter 4",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(0.25), to_fp(-0.75), 22, 4, "c=0.25-0.75j -> iter 4",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-0.25), to_fp(0.75), 23, 21, "c=-0.25+0.75j -> iter 21",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
				expect_iter(to_fp(-0.25), to_fp(-0.75), 24, 21, "c=-0.25-0.75j -> iter 21",
	            x_c, y_c, addr, load, clk, done, iter, addr_out);
			ELSIF run("done_pulse") THEN
				-- after done, next clock clears valid → done falls
				start_point(to_fp(3.0), to_fp(0.0), 1, x_c, y_c, addr, load, clk);
				wait_done(done, clk);
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(done, '0', "done should be a one-cycle pulse");
			ELSIF run("empty_ready") THEN
				-- idle: ready to receive
				WAIT FOR 1 ns;
				check_equal(empty, '1', "empty when idle");

				-- busy while iterating a point that needs several cycles (c=0.5 -> iter 4)
				start_point(to_fp(0.5), to_fp(0.0), 1, x_c, y_c, addr, load, clk);
				WAIT FOR 1 ns;
				check_equal(empty, '0', "busy after load (not done yet)");
				check_equal(done, '0', "not done yet after load for c=0.5");

				wait_done(done, clk);
				check_equal(empty, '1', "empty when done (ready for next)");

				tick(clk);
				WAIT FOR 1 ns;
				check_equal(done, '0', "done cleared");
				check_equal(empty, '1', "empty stays high when idle again");
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
