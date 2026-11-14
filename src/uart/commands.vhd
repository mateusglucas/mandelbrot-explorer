-- Decode UART bytes into one-cycle nav pulses
--   w / up arrow     : dec_y          s / down arrow  : inc_y
--   (Y flipped vs math coords so screen up matches key up)
--   d / right arrow  : inc_x          a / left arrow  : dec_x
--   e / + / =        : inc_zoom       q / - / _       : dec_zoom
--   r                : reset
-- Arrow keys arrive as ESC [ A/B/C/D

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY commands IS
	PORT (
		clk      : IN    std_logic;
		data     : IN    std_logic_vector(7 DOWNTO 0);
		valid    : IN    std_logic;
		inc_x    : OUT   std_logic;
		dec_x    : OUT   std_logic;
		inc_y    : OUT   std_logic;
		dec_y    : OUT   std_logic;
		inc_zoom : OUT   std_logic;
		dec_zoom : OUT   std_logic;
		reset    : OUT   std_logic
	);
END ENTITY commands;

ARCHITECTURE behavioral OF commands IS

	TYPE state_t IS (s_normal, s_esc, s_csi);

	SIGNAL state : state_t;

BEGIN

	PROCESS (clk) IS

		VARIABLE c : integer RANGE 0 TO 255;

	BEGIN

		IF RISING_EDGE(clk) THEN
			inc_x    <= '0';
			dec_x    <= '0';
			inc_y    <= '0';
			dec_y    <= '0';
			inc_zoom <= '0';
			dec_zoom <= '0';
			reset    <= '0';
			IF (valid = '1') THEN
				c := TO_INTEGER(UNSIGNED(data));

				CASE state IS

					WHEN s_normal =>

						CASE c IS

							WHEN CHARACTER'POS(ESC) =>

								state <= s_esc;

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

					WHEN s_esc =>

						IF (c = CHARACTER'POS('[')) THEN
							state <= s_csi;
						ELSE
							state <= s_normal;
						END IF;

					WHEN s_csi =>

						CASE c IS

							WHEN CHARACTER'POS('A') =>

								dec_y <= '1';

							WHEN CHARACTER'POS('B') =>

								inc_y <= '1';

							WHEN CHARACTER'POS('C') =>

								inc_x <= '1';

							WHEN CHARACTER'POS('D') =>

								dec_x <= '1';

							WHEN OTHERS =>

								NULL;

						END CASE;

						state <= s_normal;

				END CASE;

			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
