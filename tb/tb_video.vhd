-- video smoke: FB pixel at (0,0) appears as RGB via 2x-scaled readout

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_video IS
	GENERIC(
		runner_cfg	: STRING;
		RES_H		: NATURAL := 4;
		RES_V		: NATURAL := 3;
		W_DATA		: NATURAL := 8
	);
END tb_video;

ARCHITECTURE sim OF tb_video IS
	CONSTANT CLK_PERIOD	: TIME := 10 ns;
	CONSTANT MEM_SIZE	: NATURAL := RES_H * RES_V;
	CONSTANT W_ADDR		: NATURAL := bits_of(MEM_SIZE - 1);

	SIGNAL clk		: STD_LOGIC := '0';
	SIGNAL rd_en	: STD_LOGIC;
	SIGNAL rd_addr	: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL rd_data	: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL rgb		: STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL h_sync	: STD_LOGIC;
	SIGNAL v_sync	: STD_LOGIC;
	SIGNAL de		: STD_LOGIC;

	TYPE mem_t IS ARRAY (0 TO MEM_SIZE - 1) OF STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
	SIGNAL mem : mem_t := (OTHERS => (OTHERS => '0'));
BEGIN
	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			IF rd_en = '1' AND rd_addr < MEM_SIZE THEN
				rd_data <= mem(TO_INTEGER(rd_addr));
			END IF;
		END IF;
	END PROCESS;

	DUT: ENTITY work.video
		GENERIC MAP(RES_H => RES_H, RES_V => RES_V, W_DATA => W_DATA)
		PORT MAP(
			clk		=> clk,
			rd_en	=> rd_en,
			rd_addr	=> rd_addr,
			rd_data	=> rd_data,
			rgb		=> rgb,
			h_sync	=> h_sync,
			v_sync	=> v_sync,
			de		=> de
		);

	main: PROCESS
		VARIABLE seen_de : BOOLEAN;
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("palette_at_origin") THEN
				mem(0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(1, W_DATA));
				mem(1) <= STD_LOGIC_VECTOR(TO_UNSIGNED(255, W_DATA));

				seen_de := FALSE;
				FOR i IN 0 TO 800 * 10 LOOP
					WAIT UNTIL RISING_EDGE(clk);
					IF de = '1' THEN
						seen_de := TRUE;
						check(rgb /= x"000000", "iter=1 should not be black");
						EXIT;
					END IF;
				END LOOP;
				check_true(seen_de, "never saw active video");

			ELSIF run("sync_levels") THEN
				WAIT UNTIL h_sync = '0' FOR 900 * CLK_PERIOD;
				check_equal(h_sync, '0');
				WAIT UNTIL h_sync = '1' FOR 200 * CLK_PERIOD;
				check_equal(h_sync, '1');
				WAIT UNTIL v_sync = '0' FOR 900 * 525 * CLK_PERIOD;
				check_equal(v_sync, '0');
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
