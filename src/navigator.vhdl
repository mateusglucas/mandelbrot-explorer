-- navigator: pan X/Y + zoom counter
-- zoom feeds both pan blocks; DELTA shared (same step on X and Y).

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY navigator IS
	GENERIC(
		K			: NATURAL := 36;
		ZOOM_MAX	: NATURAL := 31;
		DELTA		: SIGNED
	);
	PORT(
		clk			: IN  STD_LOGIC;
		rst			: IN  STD_LOGIC;
		inc_x		: IN  STD_LOGIC;
		dec_x		: IN  STD_LOGIC;
		inc_y		: IN  STD_LOGIC;
		dec_y		: IN  STD_LOGIC;
		inc_zoom	: IN  STD_LOGIC;
		dec_zoom	: IN  STD_LOGIC;
		center_x	: OUT SIGNED(K - 1 DOWNTO 0);
		center_y	: OUT SIGNED(K - 1 DOWNTO 0);
		zoom		: OUT UNSIGNED(bits_of(ZOOM_MAX) - 1 DOWNTO 0)
	);
END navigator;

ARCHITECTURE structural OF navigator IS
	CONSTANT W_ZOOM : NATURAL := bits_of(ZOOM_MAX);
	SIGNAL zoom_i	: UNSIGNED(W_ZOOM - 1 DOWNTO 0);
BEGIN
	zoom <= zoom_i;

	u_zoom: ENTITY work.counter
		GENERIC MAP(MAX => ZOOM_MAX)
		PORT MAP(
			clk	=> clk,
			rst	=> rst,
			inc	=> inc_zoom,
			dec	=> dec_zoom,
			cnt	=> zoom_i
		);

	u_pan_x: ENTITY work.pan
		GENERIC MAP(
			K		=> K,
			W_ZOOM	=> W_ZOOM,
			DELTA	=> DELTA
		)
		PORT MAP(
			clk		=> clk,
			rst		=> rst,
			zoom	=> zoom_i,
			inc		=> inc_x,
			dec		=> dec_x,
			center	=> center_x
		);

	u_pan_y: ENTITY work.pan
		GENERIC MAP(
			K		=> K,
			W_ZOOM	=> W_ZOOM,
			DELTA	=> DELTA
		)
		PORT MAP(
			clk		=> clk,
			rst		=> rst,
			zoom	=> zoom_i,
			inc		=> inc_y,
			dec		=> dec_y,
			center	=> center_y
		);
END structural;
