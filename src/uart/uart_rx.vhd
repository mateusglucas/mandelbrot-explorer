-- UART RX 8N1
-- valid is high for one clk cycle when a full byte is in data

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY uart_rx IS
	GENERIC (
		clk_hz	: natural := 81_000_000;
		baud      : natural := 115_200
	);
	PORT (
		clk   : IN    std_logic;
		rx    : IN    std_logic;
		data  : OUT   std_logic_vector(7 DOWNTO 0);
		valid : OUT   std_logic
	);
END ENTITY uart_rx;

ARCHITECTURE behavioral OF uart_rx IS

	CONSTANT cycles_bit : natural := clk_hz / baud;

	TYPE state_t IS (idle, start, recv, stop);

	SIGNAL state      : state_t;
	SIGNAL rx_sync	: std_logic_vector(2 DOWNTO 0);
	SIGNAL cnt		: natural RANGE 0 TO cycles_bit - 1;
	SIGNAL bit_idx	: natural RANGE 0 TO 7;
	SIGNAL shift      : std_logic_vector(7 DOWNTO 0);

BEGIN

	data <= shift;

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			rx_sync <= rx_sync(1 DOWNTO 0) & rx;
			valid   <= '0';

			CASE state IS

				WHEN idle =>

					cnt <= 0;
					IF (rx_sync(2) = '0') THEN
						state <= start;
					END IF;

				WHEN start =>

					-- wait half bit and confirm start still low
					IF (cnt < cycles_bit / 2) THEN
						cnt <= cnt + 1;
					ELSE
						cnt     <= 0;
						bit_idx <= 0;
						IF (rx_sync(2) = '0') THEN
							state <= recv;
						ELSE
							state <= idle;
						END IF;
					END IF;

				WHEN recv =>

					IF (cnt < cycles_bit - 1) THEN
						cnt <= cnt + 1;
					ELSE
						cnt   <= 0;
						shift <= rx_sync(2) & shift(7 DOWNTO 1);
						IF (bit_idx < 7) THEN
							bit_idx <= bit_idx + 1;
						ELSE
							state <= stop;
						END IF;
					END IF;

				WHEN stop =>

					IF (cnt < cycles_bit - 1) THEN
						cnt <= cnt + 1;
					ELSE
						cnt <= 0;
						IF (rx_sync(2) = '1') THEN
							valid <= '1';
						END IF;
						state <= idle;
					END IF;

			END CASE;

		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
