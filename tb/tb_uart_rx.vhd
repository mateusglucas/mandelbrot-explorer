-- uart_rx smoke: drive a known byte on rx and check data/valid

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_uart_rx IS
	GENERIC(
		runner_cfg	: STRING;
		CLK_HZ		: NATURAL := 1_000_000;
		BAUD		: NATURAL := 100_000
	);
END tb_uart_rx;

ARCHITECTURE sim OF tb_uart_rx IS
	CONSTANT CLK_PERIOD		: TIME := 1 us;
	CONSTANT BIT_CYCLES		: NATURAL := CLK_HZ / BAUD;

	SIGNAL clk		: STD_LOGIC := '0';
	SIGNAL rx		: STD_LOGIC := '1';
	SIGNAL data		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL valid	: STD_LOGIC;

	SIGNAL capture_en	: STD_LOGIC := '0';
	SIGNAL captured		: STD_LOGIC := '0';
	SIGNAL cap_data		: STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

	PROCEDURE send_byte(
		SIGNAL c		: IN  STD_LOGIC;
		SIGNAL line		: OUT STD_LOGIC;
		CONSTANT b		: IN  STD_LOGIC_VECTOR(7 DOWNTO 0)
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
	END PROCEDURE;
BEGIN
	clk <= NOT clk AFTER CLK_PERIOD / 2;

	DUT: ENTITY work.uart_rx
		GENERIC MAP(CLK_HZ => CLK_HZ, BAUD => BAUD)
		PORT MAP(clk => clk, rx => rx, data => data, valid => valid);

	-- Capture valid pulse while enabled (pulse happens during stop bit)
	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			IF capture_en = '0' THEN
				captured <= '0';
			ELSIF valid = '1' THEN
				captured <= '1';
				cap_data <= data;
			END IF;
		END IF;
	END PROCESS;

	main: PROCESS
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("byte_0x55") THEN
				WAIT FOR 5 * CLK_PERIOD;
				capture_en <= '1';
				send_byte(clk, rx, x"55");
				WAIT FOR 2 * CLK_PERIOD;
				check_equal(captured, '1');
				check_equal(cap_data, std_logic_vector'(x"55"));
				capture_en <= '0';
				WAIT FOR CLK_PERIOD;

			ELSIF run("byte_0xA3") THEN
				WAIT FOR 5 * CLK_PERIOD;
				capture_en <= '1';
				send_byte(clk, rx, x"A3");
				WAIT FOR 2 * CLK_PERIOD;
				check_equal(captured, '1');
				check_equal(cap_data, std_logic_vector'(x"A3"));
				capture_en <= '0';
				WAIT FOR CLK_PERIOD;
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
