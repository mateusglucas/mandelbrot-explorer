-- UART RX 8N1
-- valid is high for one clk cycle when a full byte is in data

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY uart_rx IS
	GENERIC(
		CLK_HZ	: NATURAL := 81_000_000;
		BAUD	: NATURAL := 115_200
	);
	PORT(
		clk		: IN  STD_LOGIC;
		rx		: IN  STD_LOGIC;
		data	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		valid	: OUT STD_LOGIC
	);
END uart_rx;

ARCHITECTURE behavioral OF uart_rx IS
	CONSTANT CYCLES_BIT : NATURAL := CLK_HZ / BAUD;
	TYPE state_t IS (IDLE, START, RECV, STOP);
	SIGNAL state	: state_t := IDLE;
	SIGNAL rx_sync	: STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '1');
	SIGNAL cnt		: NATURAL RANGE 0 TO CYCLES_BIT - 1 := 0;
	SIGNAL bit_idx	: NATURAL RANGE 0 TO 7 := 0;
	SIGNAL shift	: STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
BEGIN
	data <= shift;

	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			rx_sync <= rx_sync(1 DOWNTO 0) & rx;
			valid <= '0';
			CASE state IS
				WHEN IDLE =>
					cnt <= 0;
					IF rx_sync(2) = '0' THEN
						state <= START;
					END IF;
				WHEN START =>
					-- wait half bit and confirm start still low
					IF cnt < CYCLES_BIT / 2 THEN
						cnt <= cnt + 1;
					ELSE
						cnt <= 0;
						bit_idx <= 0;
						IF rx_sync(2) = '0' THEN
							state <= RECV;
						ELSE
							state <= IDLE;
						END IF;
					END IF;
				WHEN RECV =>
					IF cnt < CYCLES_BIT - 1 THEN
						cnt <= cnt + 1;
					ELSE
						cnt <= 0;
						shift <= rx_sync(2) & shift(7 DOWNTO 1);
						IF bit_idx < 7 THEN
							bit_idx <= bit_idx + 1;
						ELSE
							state <= STOP;
						END IF;
					END IF;
				WHEN STOP =>
					IF cnt < CYCLES_BIT - 1 THEN
						cnt <= cnt + 1;
					ELSE
						cnt <= 0;
						IF rx_sync(2) = '1' THEN
							valid <= '1';
						END IF;
						state <= IDLE;
					END IF;
			END CASE;
		END IF;
	END PROCESS;
END behavioral;
