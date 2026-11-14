-- Decode UART bytes into one-cycle nav pulses
--   w / up arrow     : dec_y          s / down arrow  : inc_y
--   (Y flipped vs math coords so screen up matches key up)
--   d / right arrow  : inc_x          a / left arrow  : dec_x
--   e / + / =        : inc_zoom       q / - / _       : dec_zoom
--   r                : reset
-- Arrow keys arrive as ESC [ A/B/C/D

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY commands IS
	PORT(
		clk			: IN  STD_LOGIC;
		data		: IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		valid		: IN  STD_LOGIC;
		inc_x		: OUT STD_LOGIC;
		dec_x		: OUT STD_LOGIC;
		inc_y		: OUT STD_LOGIC;
		dec_y		: OUT STD_LOGIC;
		inc_zoom	: OUT STD_LOGIC;
		dec_zoom	: OUT STD_LOGIC;
		reset		: OUT STD_LOGIC
	);
END commands;

ARCHITECTURE behavioral OF commands IS
	TYPE state_t IS (S_NORMAL, S_ESC, S_CSI);
	SIGNAL state : state_t := S_NORMAL;
BEGIN
	PROCESS(clk)
		VARIABLE c : INTEGER RANGE 0 TO 255;
	BEGIN
		IF RISING_EDGE(clk) THEN
			inc_x <= '0';
			dec_x <= '0';
			inc_y <= '0';
			dec_y <= '0';
			inc_zoom <= '0';
			dec_zoom <= '0';
			reset <= '0';
			IF valid = '1' THEN
				c := TO_INTEGER(UNSIGNED(data));
				CASE state IS
					WHEN S_NORMAL =>
						CASE c IS
							WHEN CHARACTER'POS(ESC) =>
								state <= S_ESC;
							WHEN CHARACTER'POS('d') | CHARACTER'POS('D') =>
								inc_x <= '1';
							WHEN CHARACTER'POS('a') | CHARACTER'POS('A') =>
								dec_x <= '1';
							WHEN CHARACTER'POS('w') | CHARACTER'POS('W') =>
								dec_y <= '1';
							WHEN CHARACTER'POS('s') | CHARACTER'POS('S') =>
								inc_y <= '1';
							WHEN CHARACTER'POS('e') | CHARACTER'POS('E')
								| CHARACTER'POS('+') | CHARACTER'POS('=') =>
								inc_zoom <= '1';
							WHEN CHARACTER'POS('q') | CHARACTER'POS('Q')
								| CHARACTER'POS('-') | CHARACTER'POS('_') =>
								dec_zoom <= '1';
							WHEN CHARACTER'POS('r') | CHARACTER'POS('R') =>
								reset <= '1';
							WHEN OTHERS =>
								NULL;
						END CASE;
					WHEN S_ESC =>
						IF c = CHARACTER'POS('[') THEN
							state <= S_CSI;
						ELSE
							state <= S_NORMAL;
						END IF;
					WHEN S_CSI =>
						CASE c IS
							WHEN CHARACTER'POS('A') => dec_y <= '1';
							WHEN CHARACTER'POS('B') => inc_y <= '1';
							WHEN CHARACTER'POS('C') => inc_x <= '1';
							WHEN CHARACTER'POS('D') => dec_x <= '1';
							WHEN OTHERS => NULL;
						END CASE;
						state <= S_NORMAL;
				END CASE;
			END IF;
		END IF;
	END PROCESS;
END behavioral;
