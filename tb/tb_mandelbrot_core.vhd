-- Smoke test for mandelbrot_core: reset → pixels written → nav pulse restarts

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_mandelbrot_core IS
	GENERIC(
		runner_cfg	: STRING;
		K			: NATURAL := 16;
		I			: NATURAL := 4;
		RES_H		: NATURAL := 4;
		RES_V		: NATURAL := 3;
		MAX_ITER	: NATURAL := 16;
		ZOOM_MAX	: NATURAL := 7;
		W_DATA		: NATURAL := 3;
		DELTA_FP	: INTEGER := 256;
		RATIO_FP	: INTEGER := 4096
	);
END tb_mandelbrot_core;

ARCHITECTURE sim OF tb_mandelbrot_core IS
	CONSTANT CLK_PERIOD	: TIME := 10 ns;
	CONSTANT N_PIX		: NATURAL := RES_H * RES_V;
	CONSTANT W_ADDR		: NATURAL := bits_of(N_PIX - 1);
	CONSTANT DELTA_C	: SIGNED(K - 1 DOWNTO 0) := to_signed(DELTA_FP, K);
	CONSTANT RATIO_C	: SIGNED(K - 1 DOWNTO 0) := to_signed(RATIO_FP, K);

	SIGNAL clk			: STD_LOGIC := '0';
	SIGNAL rst			: STD_LOGIC := '1';
	SIGNAL inc_x		: STD_LOGIC := '0';
	SIGNAL dec_x		: STD_LOGIC := '0';
	SIGNAL inc_y		: STD_LOGIC := '0';
	SIGNAL dec_y		: STD_LOGIC := '0';
	SIGNAL inc_zoom		: STD_LOGIC := '0';
	SIGNAL dec_zoom		: STD_LOGIC := '0';
	SIGNAL clk_rd		: STD_LOGIC := '0';
	SIGNAL rd_en		: STD_LOGIC := '1';
	SIGNAL rd_addr		: UNSIGNED(W_ADDR - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL rd_data		: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);

BEGIN
	clk <= NOT clk AFTER CLK_PERIOD / 2;
	clk_rd <= clk;

	DUT: ENTITY work.mandelbrot_core
		GENERIC MAP(
			K			=> K,
			I			=> I,
			RES_H		=> RES_H,
			RES_V		=> RES_V,
			MAX_ITER	=> MAX_ITER,
			ZOOM_MAX	=> ZOOM_MAX,
			W_DATA		=> W_DATA,
			DELTA		=> DELTA_C,
			RATIO		=> RATIO_C
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
			zoom_out	=> OPEN,
			clk_rd		=> clk_rd,
			rd_en		=> rd_en,
			rd_addr		=> rd_addr,
			rd_data		=> rd_data
		);

	main: PROCESS
		VARIABLE v : STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("fill_frame") THEN
				rst <= '1';
				WAIT UNTIL rising_edge(clk);
				WAIT UNTIL rising_edge(clk);
				rst <= '0';

				FOR n IN 1 TO N_PIX * (MAX_ITER + 8) + 64 LOOP
					WAIT UNTIL rising_edge(clk);
				END LOOP;

				FOR a IN 0 TO N_PIX - 1 LOOP
					rd_addr <= to_unsigned(a, W_ADDR);
					WAIT UNTIL rising_edge(clk);
					WAIT UNTIL rising_edge(clk);
					v := rd_data;
					check(v /= "XXX", "mem[" & integer'image(a) & "] uninitialized");
				END LOOP;

			ELSIF run("nav_restarts") THEN
				rst <= '1';
				WAIT UNTIL rising_edge(clk);
				WAIT UNTIL rising_edge(clk);
				rst <= '0';

				FOR n IN 1 TO (MAX_ITER + 8) * 3 + 32 LOOP
					WAIT UNTIL rising_edge(clk);
				END LOOP;

				inc_x <= '1';
				WAIT UNTIL rising_edge(clk);
				inc_x <= '0';

				FOR n IN 1 TO N_PIX * (MAX_ITER + 8) + 64 LOOP
					WAIT UNTIL rising_edge(clk);
				END LOOP;

				rd_addr <= to_unsigned(0, W_ADDR);
				WAIT UNTIL rising_edge(clk);
				WAIT UNTIL rising_edge(clk);
				check(rd_data /= "XXX", "mem after nav still readable");
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
