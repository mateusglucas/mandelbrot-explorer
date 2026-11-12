-- pan: block for panning the center coordinate

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY pan IS
	GENERIC(
		K	    : NATURAL := 36; -- number of bits for the center coordinate
		W_ZOOM	: NATURAL := 5;  -- number of bits for the zoom level
		DELTA	: SIGNED         -- delta value
	);
	PORT
	(
		clk			: IN STD_LOGIC;
		reset		: IN STD_LOGIC;
		zoom		: IN UNSIGNED (W_ZOOM-1 DOWNTO 0);
		inc			: IN STD_LOGIC;
		dec			: IN STD_LOGIC;
		center	    : OUT SIGNED(K-1 DOWNTO 0)
	);
END pan;

ARCHITECTURE behavioral OF pan IS
SIGNAL center_i : SIGNED(K-1 DOWNTO 0);
BEGIN

	center <= center_i;

	PROCESS(clk)
	VARIABLE delta_shifted : SIGNED(K-1 DOWNTO 0);
	BEGIN
		IF RISING_EDGE(clk) THEN
			IF reset='1' THEN
				center_i <= (OTHERS=>'0');
			ELSIF inc='1' XOR dec='1' THEN
				delta_shifted := SHIFT_RIGHT(RESIZE(DELTA, K), TO_INTEGER(zoom));
				IF delta_shifted = 0 THEN
					delta_shifted := TO_SIGNED(1, K);
				END IF;

				IF inc='1' THEN
					center_i <= center_i + delta_shifted;
				ELSE -- dec='1'
					center_i <= center_i - delta_shifted;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END behavioral;