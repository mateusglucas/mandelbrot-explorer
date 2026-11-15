-- uart_rx smoke: drive a known byte on rx and check data/valid

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_uart_rx IS
	GENERIC (
		runner_cfg	: string;
		clk_hz		: natural := 1_000_000;
		baud          : natural := 100_000
	);
END ENTITY tb_uart_rx;

ARCHITECTURE sim OF tb_uart_rx IS

	CONSTANT clk_period : time    := 1 us;
	CONSTANT bit_cycles : natural := clk_hz / baud;

	SIGNAL clk   : std_logic := '0';
	SIGNAL rx    : std_logic;
	SIGNAL data  : std_logic_vector(7 DOWNTO 0);
	SIGNAL valid : std_logic;

	SIGNAL capture_en : std_logic;
	SIGNAL captured   : std_logic;
	SIGNAL cap_data   : std_logic_vector(7 DOWNTO 0);

	PROCEDURE send_byte (
		SIGNAL c    : IN  std_logic;
		SIGNAL line : OUT std_logic;
		CONSTANT b  : IN  std_logic_vector(7 DOWNTO 0)
	) IS
	BEGIN

		WAIT UNTIL RISING_EDGE(c);
		line <= '0';

		FOR k IN 1 TO BIT_CYCLES LOOP

			WAIT UNTIL RISING_EDGE(c);

		END LOOP;

		FOR i IN 0 TO 7 LOOP

			line <= b(i);

			FOR k IN 1 TO BIT_CYCLES LOOP

				WAIT UNTIL RISING_EDGE(c);

			END LOOP;

		END LOOP;

		line <= '1';

		FOR k IN 1 TO BIT_CYCLES LOOP

			WAIT UNTIL RISING_EDGE(c);

		END LOOP;

	END PROCEDURE send_byte;

BEGIN

	clk <= NOT clk AFTER clk_period / 2;

	DUT : ENTITY work.uart_rx
		GENERIC MAP (
			clk_hz => clk_hz, baud => baud
		)
		PORT MAP (
			clk   => clk,
			rx    => rx,
			data  => data,
			valid => valid
		);

	-- Capture valid pulse while enabled (pulse happens during stop bit)
	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (capture_en = '0') THEN
				captured <= '0';
			ELSIF (valid = '1') THEN
				captured <= '1';
				cap_data <= data;
			END IF;
		END IF;

	END PROCESS;

	MAIN : PROCESS IS
	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			IF run("byte_0x55") THEN
				WAIT FOR 5 * clk_period;
				capture_en <= '1';
				send_byte(clk, rx, x"55");
				WAIT FOR 2 * clk_period;
				check_equal(captured, '1');
				check_equal(cap_data, std_logic_vector'(x"55"));
				capture_en <= '0';
				WAIT FOR clk_period;
			ELSIF run("byte_0xA3") THEN
				WAIT FOR 5 * clk_period;
				capture_en <= '1';
				send_byte(clk, rx, x"A3");
				WAIT FOR 2 * clk_period;
				check_equal(captured, '1');
				check_equal(cap_data, std_logic_vector'(x"A3"));
				capture_en <= '0';
				WAIT FOR clk_period;
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
