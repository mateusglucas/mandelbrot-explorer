-- commands: letter keys and ESC [ arrows → one-cycle pulses

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_commands IS
	GENERIC (
		runner_cfg : string
	);
END ENTITY tb_commands;

ARCHITECTURE sim OF tb_commands IS

	CONSTANT clk_period : time := 10 ns;

	SIGNAL clk      : std_logic := '0';
	SIGNAL data     : std_logic_vector(7 DOWNTO 0);
	SIGNAL valid    : std_logic;
	SIGNAL inc_x    : std_logic;
	SIGNAL dec_x    : std_logic;
	SIGNAL inc_y    : std_logic;
	SIGNAL dec_y    : std_logic;
	SIGNAL inc_zoom : std_logic;
	SIGNAL dec_zoom : std_logic;
	SIGNAL reset    : std_logic;

BEGIN

	clk <= NOT clk AFTER clk_period / 2;

	DUT : ENTITY work.commands
		PORT MAP (
			clk      => clk,
			data     => data,
			valid    => valid,
			inc_x    => inc_x,
			dec_x    => dec_x,
			inc_y    => inc_y,
			dec_y    => dec_y,
			inc_zoom => inc_zoom,
			dec_zoom => dec_zoom,
			reset    => reset
		);

	MAIN : PROCESS IS

		PROCEDURE tick_byte (
			CONSTANT b : integer
		) IS
		BEGIN

			WAIT UNTIL FALLING_EDGE(clk);
			data  <= STD_LOGIC_VECTOR(TO_UNSIGNED(b, 8));
			valid <= '1';
			WAIT UNTIL RISING_EDGE(clk);
			WAIT FOR 1 ps;
			WAIT UNTIL FALLING_EDGE(clk);
			valid <= '0';

		END PROCEDURE tick_byte;

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			IF run("letters") THEN
				tick_byte(CHARACTER'POS('d'));
				check_equal(inc_x, '1');

				tick_byte(CHARACTER'POS('a'));
				check_equal(dec_x, '1');

				tick_byte(CHARACTER'POS('w'));
				check_equal(dec_y, '1');

				tick_byte(CHARACTER'POS('s'));
				check_equal(inc_y, '1');

				tick_byte(CHARACTER'POS('+'));
				check_equal(inc_zoom, '1');

				tick_byte(CHARACTER'POS('q'));
				check_equal(dec_zoom, '1');

				tick_byte(CHARACTER'POS('r'));
				check_equal(reset, '1');

				WAIT UNTIL RISING_EDGE(clk);
				WAIT FOR 1 ps;
				check_equal(reset, '0');
			ELSIF run("arrows") THEN
				tick_byte(CHARACTER'POS(ESC));
				tick_byte(CHARACTER'POS('['));
				tick_byte(CHARACTER'POS('C'));
				check_equal(inc_x, '1');

				tick_byte(CHARACTER'POS(ESC));
				tick_byte(CHARACTER'POS('['));
				tick_byte(CHARACTER'POS('A'));
				check_equal(dec_y, '1');

				tick_byte(CHARACTER'POS(ESC));
				tick_byte(CHARACTER'POS('['));
				tick_byte(CHARACTER'POS('D'));
				check_equal(dec_x, '1');
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
