-- video smoke: FB pixel at (0,0) appears as RGB via 2x-scaled readout
-- Uses a tiny VGA frame so the suite stays fast (production defaults stay 640x480).

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_video IS
	GENERIC (
		runner_cfg : string;
		res_h      : natural := 4;
		res_v      : natural := 3;
		w_data     : natural := 8;
		-- 8x6 active (covers 4x3 FB at 2x) + minimal blanking
		h_visible  : natural := 8;
		h_fporch   : natural := 1;
		h_sync_w   : natural := 2;
		h_bporch   : natural := 1;
		v_visible  : natural := 6;
		v_fporch   : natural := 1;
		v_sync_w   : natural := 1;
		v_bporch   : natural := 1
	);
END ENTITY tb_video;

ARCHITECTURE sim OF tb_video IS

	CONSTANT clk_period : time    := 10 ns;
	CONSTANT mem_size   : natural := res_h * res_v;
	CONSTANT w_addr     : natural := bits_of(mem_size - 1);
	CONSTANT h_total    : natural := h_visible + h_fporch + h_sync_w + h_bporch;
	CONSTANT v_total    : natural := v_visible + v_fporch + v_sync_w + v_bporch;

	SIGNAL clk     : std_logic := '0';
	SIGNAL rst     : std_logic := '1';
	SIGNAL rd_en   : std_logic;
	SIGNAL rd_addr : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL rd_data : std_logic_vector(w_data - 1 DOWNTO 0);
	SIGNAL rgb     : std_logic_vector(23 DOWNTO 0);
	SIGNAL h_sync  : std_logic;
	SIGNAL v_sync  : std_logic;
	SIGNAL de      : std_logic;

	TYPE mem_t IS ARRAY(0 TO mem_size - 1) OF std_logic_vector(w_data - 1 DOWNTO 0);

	SIGNAL mem : mem_t;

BEGIN

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rd_en = '1' AND rd_addr < mem_size) THEN
				rd_data <= mem(TO_INTEGER(rd_addr));
			END IF;
		END IF;

	END PROCESS;

	DUT : ENTITY work.video
		GENERIC MAP (
			res_h     => res_h,
			res_v     => res_v,
			w_data    => w_data,
			h_visible => h_visible,
			h_fporch  => h_fporch,
			h_sync_w  => h_sync_w,
			h_bporch  => h_bporch,
			v_visible => v_visible,
			v_fporch  => v_fporch,
			v_sync_w  => v_sync_w,
			v_bporch  => v_bporch
		)
		PORT MAP (
			clk     => clk,
			rst     => rst,
			rd_en   => rd_en,
			rd_addr => rd_addr,
			rd_data => rd_data,
			rgb     => rgb,
			h_sync  => h_sync,
			v_sync  => v_sync,
			de      => de
		);

	MAIN : PROCESS IS

		VARIABLE seen_de : boolean;

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			IF run("palette_at_origin") THEN
				mem(0) <= STD_LOGIC_VECTOR(TO_UNSIGNED(1, w_data));
				mem(1) <= STD_LOGIC_VECTOR(TO_UNSIGNED(255, w_data));

				rst <= '1';
				WAIT UNTIL RISING_EDGE(clk);
				WAIT UNTIL RISING_EDGE(clk);
				rst <= '0';

				seen_de := FALSE;

				FOR i IN 0 TO h_total * v_total + 16 LOOP

					WAIT UNTIL RISING_EDGE(clk);
					IF (de = '1') THEN
						seen_de := TRUE;
						check(rgb /= x"000000", "iter=1 should not be black");
						EXIT;
					END IF;

				END LOOP;

				check_true(seen_de, "never saw active video");
			ELSIF run("sync_levels") THEN
				rst <= '1';
				WAIT UNTIL RISING_EDGE(clk);
				WAIT UNTIL RISING_EDGE(clk);
				rst <= '0';

				WAIT UNTIL h_sync = '0' FOR (h_total + 4) * clk_period;
				check_equal(h_sync, '0');
				WAIT UNTIL h_sync = '1' FOR (h_sync_w + 4) * clk_period;
				check_equal(h_sync, '1');
				WAIT UNTIL v_sync = '0' FOR (h_total * v_total + 4) * clk_period;
				check_equal(v_sync, '0');
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
