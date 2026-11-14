-- navigator: pan X/Y + zoom counter
-- zoom feeds both pan blocks; DELTA shared (same step on X and Y).

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY navigator IS
	GENERIC (
		k           : natural := 36;
		zoom_max	: natural := 31;
		delta       : signed
	);
	PORT (
		clk      : IN    std_logic;
		rst      : IN    std_logic;
		inc_x    : IN    std_logic;
		dec_x    : IN    std_logic;
		inc_y    : IN    std_logic;
		dec_y    : IN    std_logic;
		inc_zoom : IN    std_logic;
		dec_zoom : IN    std_logic;
		center_x : OUT   signed(k - 1 DOWNTO 0);
		center_y : OUT   signed(k - 1 DOWNTO 0);
		zoom     : OUT   unsigned(bits_of(zoom_max) - 1 DOWNTO 0)
	);
END ENTITY navigator;

ARCHITECTURE structural OF navigator IS

	CONSTANT w_zoom    : natural := bits_of(zoom_max);
	SIGNAL   zoom_i	: unsigned(w_zoom - 1 DOWNTO 0);

BEGIN

	zoom <= zoom_i;

	U_ZOOM : ENTITY work.counter
		GENERIC MAP (
			max => zoom_max
		)
		PORT MAP (
			clk	=> clk,
			rst	=> rst,
			inc	=> inc_zoom,
			dec	=> dec_zoom,
			cnt	=> zoom_i
		);

	U_PAN_X : ENTITY work.pan
		GENERIC MAP (
			k         => k,
			w_zoom	=> W_ZOOM,
			delta     => delta
		)
		PORT MAP (
			clk       => clk,
			rst       => rst,
			zoom      => zoom_i,
			inc       => inc_x,
			dec       => dec_x,
			center	=> center_x
		);

	U_PAN_Y : ENTITY work.pan
		GENERIC MAP (
			k         => k,
			w_zoom	=> W_ZOOM,
			delta     => delta
		)
		PORT MAP (
			clk       => clk,
			rst       => rst,
			zoom      => zoom_i,
			inc       => inc_y,
			dec       => dec_y,
			center	=> center_y
		);

END ARCHITECTURE structural;
