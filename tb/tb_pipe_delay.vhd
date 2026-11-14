-- VUnit testbench for pipe_delay (incl. N=0 wire and N=1 null-range shift)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_pipe_delay IS
	GENERIC (
		runner_cfg	: string;
		n             : natural := 1;
		w             : natural := 4
	);
END ENTITY tb_pipe_delay;

ARCHITECTURE sim OF tb_pipe_delay IS

	CONSTANT clk_period : time := 10 ns;

	SIGNAL clk	: std_logic;
	SIGNAL rst	: std_logic;
	SIGNAL en     : std_logic;
	SIGNAL d      : std_logic_vector(w - 1 DOWNTO 0);
	SIGNAL q      : std_logic_vector(w - 1 DOWNTO 0);

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

		en_s <= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s <= '0';
		WAIT FOR 1 ns;

	END PROCEDURE pulse_en;

BEGIN

	DUT : ENTITY work.pipe_delay
		GENERIC MAP (
			n => n, w => w
		)
		PORT MAP (
			clk => clk,
			rst => rst,
			en  => en,
			d   => d,
			q   => q
		);

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS IS

		VARIABLE pattern : std_logic_vector(w - 1 DOWNTO 0);

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			do_rst(rst, en, clk);

			IF run("after_rst") THEN
				IF (n = 0) THEN
					-- wire: q follows d even after rst
					d <= (OTHERS => '0');
					WAIT FOR 1 ns;
					check_equal(q, d, "N=0 q tracks d");
				ELSE
					check_equal(q, std_logic_vector'(q'range => '0'), "q cleared");
				END IF;
			ELSIF run("latency") THEN
				pattern    := (OTHERS => '0');
				pattern(0) := '1';
				IF (w > 1) THEN
					pattern(w - 1) := '1';
				END IF;
				d <= pattern;

				IF (n = 0) THEN
					WAIT FOR 1 ns;
					check_equal(q, pattern, "N=0 combinational");
				ELSE
					-- first N-1 enables: q still old (0 after rst)
					FOR i IN 1 TO n - 1 LOOP

						pulse_en(en, clk);
						check_equal(q, std_logic_vector'(q'range => '0'),
							"q still 0 before latency");

					END LOOP;

					pulse_en(en, clk);
					check_equal(q, pattern, "q after N enables");
				END IF;
			ELSIF run("en_hold") THEN
				IF (n = 0) THEN
					-- wire: q always tracks d (no hold)
					d <= (OTHERS => '1');
					WAIT FOR 1 ns;
					check_equal(q, d, "N=0 tracks 1s");
					d <= (OTHERS => '0');
					WAIT FOR 1 ns;
					check_equal(q, d, "N=0 tracks 0s");
				ELSE
					d <= (OTHERS => '1');

					FOR i IN 1 TO n LOOP

						en <= '1';
						WAIT UNTIL rising_edge(clk);

					END LOOP;

					en <= '0';
					WAIT FOR 1 ns;
					check_equal(q, std_logic_vector'(q'range => '1'), "loaded");

					d <= (OTHERS => '0');
					WAIT UNTIL rising_edge(clk);
					WAIT FOR 1 ns;
					check_equal(q, std_logic_vector'(q'range => '1'), "holds when en=0");
				END IF;
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
