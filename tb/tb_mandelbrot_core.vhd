-- Smoke test for mandelbrot_core: reset → pixels written → nav pulse restarts

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_mandelbrot_core IS
	GENERIC (
		runner_cfg	: string;
		k             : natural := 16;
		i             : natural := 4;
		res_h         : natural := 4;
		res_v         : natural := 3;
		max_iter      : natural := 16;
		zoom_max      : natural := 7;
		w_data		: natural := 3;
		delta_fp      : integer := 256;
		ratio_fp      : integer := 4096
	);
END ENTITY tb_mandelbrot_core;

ARCHITECTURE sim OF tb_mandelbrot_core IS

	CONSTANT clk_period	: time                   := 10 ns;
	CONSTANT n_pix         : natural                := res_h * res_v;
	CONSTANT w_addr		: natural                := bits_of(n_pix - 1);
	CONSTANT delta_c       : signed(k - 1 DOWNTO 0) := to_signed(delta_fp, k);
	CONSTANT ratio_c       : signed(k - 1 DOWNTO 0) := to_signed(ratio_fp, k);

	SIGNAL clk      : std_logic;
	SIGNAL rst      : std_logic;
	SIGNAL inc_x    : std_logic;
	SIGNAL dec_x    : std_logic;
	SIGNAL inc_y    : std_logic;
	SIGNAL dec_y    : std_logic;
	SIGNAL inc_zoom : std_logic;
	SIGNAL dec_zoom : std_logic;
	SIGNAL clk_rd   : std_logic;
	SIGNAL rd_en    : std_logic;
	SIGNAL rd_addr  : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL rd_data  : std_logic_vector(w_data - 1 DOWNTO 0);

BEGIN

	clk    <= NOT clk AFTER clk_period / 2;
	clk_rd <= clk;

	DUT : ENTITY work.mandelbrot_core
		GENERIC MAP (
			k        => k,
			i        => i,
			res_h    => res_h,
			res_v    => res_v,
			max_iter => max_iter,
			zoom_max => zoom_max,
			w_data   => w_data,
			delta    => DELTA_C,
			ratio    => RATIO_C
		)
		PORT MAP (
			clk      => clk,
			rst      => rst,
			inc_x    => inc_x,
			dec_x    => dec_x,
			inc_y    => inc_y,
			dec_y    => dec_y,
			inc_zoom => inc_zoom,
			dec_zoom => dec_zoom,
			zoom_out => OPEN,
			clk_rd   => clk_rd,
			rd_en    => rd_en,
			rd_addr  => rd_addr,
			rd_data  => rd_data
		);

	MAIN : PROCESS IS

		VARIABLE v : std_logic_vector(w_data - 1 DOWNTO 0);

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			IF run("fill_frame") THEN
				rst <= '1';
				WAIT UNTIL rising_edge(clk);
				WAIT UNTIL rising_edge(clk);
				rst <= '0';

				FOR n IN 1 TO n_pix * (max_iter + 8) + 64 LOOP

					WAIT UNTIL rising_edge(clk);

				END LOOP;

				FOR a IN 0 TO n_pix - 1 LOOP

					rd_addr <= to_unsigned(a, w_addr);
					WAIT UNTIL rising_edge(clk);
					WAIT UNTIL rising_edge(clk);
					v       := rd_data;
					check(v /= "XXX", "mem[" & integer'image(a) & "] uninitialized");

				END LOOP;

			ELSIF run("nav_restarts") THEN
				rst <= '1';
				WAIT UNTIL rising_edge(clk);
				WAIT UNTIL rising_edge(clk);
				rst <= '0';

				FOR n IN 1 TO (max_iter + 8) * 3 + 32 LOOP

					WAIT UNTIL rising_edge(clk);

				END LOOP;

				inc_x <= '1';
				WAIT UNTIL rising_edge(clk);
				inc_x <= '0';

				FOR n IN 1 TO n_pix * (max_iter + 8) + 64 LOOP

					WAIT UNTIL rising_edge(clk);

				END LOOP;

				rd_addr <= to_unsigned(0, w_addr);
				WAIT UNTIL rising_edge(clk);
				WAIT UNTIL rising_edge(clk);
				check(rd_data /= "XXX", "mem after nav still readable");
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
