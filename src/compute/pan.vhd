-- pan: block for panning the center coordinate

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY pan IS
	GENERIC (
		k         : natural := 36; -- number of bits for the center coordinate
		w_zoom	: natural := 5;  -- number of bits for the zoom level
		delta     : signed         -- delta value
	);
	PORT (
		clk    : IN    std_logic;
		rst    : IN    std_logic;
		zoom   : IN    unsigned(w_zoom - 1 DOWNTO 0);
		inc    : IN    std_logic;
		dec    : IN    std_logic;
		center : OUT   signed(k - 1 DOWNTO 0)
	);
END ENTITY pan;

ARCHITECTURE behavioral OF pan IS

	SIGNAL center_i : signed(k - 1 DOWNTO 0);

BEGIN

	center <= center_i;

	PROCESS (clk) IS

		VARIABLE delta_shifted : signed(k - 1 DOWNTO 0);

	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				center_i <= (OTHERS => '0');
			ELSIF (inc = '1' XOR dec = '1') THEN
				delta_shifted := SHIFT_RIGHT(RESIZE(delta, k), TO_INTEGER(zoom));
				IF (delta_shifted = 0) THEN
					delta_shifted := TO_SIGNED(1, k);
				END IF;

				IF (inc = '1') THEN
					center_i <= center_i + delta_shifted;
				ELSE -- dec='1'
					center_i <= center_i - delta_shifted;
				END IF;
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
