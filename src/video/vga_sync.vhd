-- VGA timing generator (defaults: 640x480@60, pclk ~25.2 MHz on Tang)
-- H default: 640 active, 16 front, 96 sync, 48 back (800 total)
-- V default: 480 active, 10 front, 2 sync, 33 back (525 total)
-- h_sync / v_sync active low; all outputs registered and aligned

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY vga_sync IS
	GENERIC (
		h_visible : natural := 640;
		h_fporch  : natural := 16;
		h_sync_w  : natural := 96;
		h_bporch  : natural := 48;
		v_visible : natural := 480;
		v_fporch  : natural := 10;
		v_sync_w  : natural := 2;
		v_bporch  : natural := 33
	);
	PORT (
		clk         : IN    std_logic;
		rst         : IN    std_logic;
		v_sync      : OUT   std_logic;
		h_sync      : OUT   std_logic;
		active_area : OUT   std_logic;
		x           : OUT   unsigned(9 DOWNTO 0);
		y           : OUT   unsigned(9 DOWNTO 0)
	);
END ENTITY vga_sync;

ARCHITECTURE behavioral OF vga_sync IS

	CONSTANT h_total      : natural := h_visible + h_fporch + h_sync_w + h_bporch;
	CONSTANT v_total      : natural := v_visible + v_fporch + v_sync_w + v_bporch;
	CONSTANT h_sync_start : natural := h_visible + h_fporch;
	CONSTANT h_sync_end   : natural := h_sync_start + h_sync_w;
	CONSTANT v_sync_start : natural := v_visible + v_fporch;
	CONSTANT v_sync_end   : natural := v_sync_start + v_sync_w;

	SIGNAL pixel_cnt : unsigned(9 DOWNTO 0);
	SIGNAL line_cnt  : unsigned(9 DOWNTO 0);

BEGIN

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				pixel_cnt   <= (OTHERS => '0');
				line_cnt    <= (OTHERS => '0');
				h_sync      <= '1';
				v_sync      <= '1';
				active_area <= '0';
				x           <= (OTHERS => '0');
				y           <= (OTHERS => '0');
			ELSE
				IF (pixel_cnt < h_total - 1) THEN
					pixel_cnt <= pixel_cnt + 1;
				ELSE
					pixel_cnt <= (OTHERS => '0');
					IF (line_cnt < v_total - 1) THEN
						line_cnt <= line_cnt + 1;
					ELSE
						line_cnt <= (OTHERS => '0');
					END IF;
				END IF;

				IF (pixel_cnt >= h_sync_start AND pixel_cnt < h_sync_end) THEN
					h_sync <= '0';
				ELSE
					h_sync <= '1';
				END IF;

				IF (line_cnt >= v_sync_start AND line_cnt < v_sync_end) THEN
					v_sync <= '0';
				ELSE
					v_sync <= '1';
				END IF;

				IF (pixel_cnt < h_visible AND line_cnt < v_visible) THEN
					active_area <= '1';
				ELSE
					active_area <= '0';
				END IF;

				x <= pixel_cnt;
				y <= line_cnt;
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
