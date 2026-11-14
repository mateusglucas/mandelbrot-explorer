-- Standard 640x480@60 timing (pixel clock ~25.175 MHz; use 25.2 MHz on Tang)
-- H: 640 active, 16 front, 96 sync, 48 back (800 total)
-- V: 480 active, 10 front, 2 sync, 33 back (525 total)
-- h_sync / v_sync active low; all outputs registered and aligned

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY vga_sync IS
	PORT (
		clk			: IN    std_logic;
		v_sync         : OUT   std_logic;
		h_sync         : OUT   std_logic;
		active_area	: OUT   std_logic;
		x              : OUT   unsigned(9 DOWNTO 0);
		y              : OUT   unsigned(9 DOWNTO 0)
	);
END ENTITY vga_sync;

ARCHITECTURE behavioral OF vga_sync IS

	SIGNAL pixel_cnt : unsigned(9 DOWNTO 0);
	SIGNAL line_cnt  : unsigned(9 DOWNTO 0);

BEGIN

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (pixel_cnt < 799) THEN
				pixel_cnt <= pixel_cnt + 1;
			ELSE
				pixel_cnt <= (OTHERS => '0');
				IF (line_cnt < 524) THEN
					line_cnt <= line_cnt + 1;
				ELSE
					line_cnt <= (OTHERS => '0');
				END IF;
			END IF;

			IF (pixel_cnt >= 656 AND pixel_cnt < 752) THEN
				h_sync <= '0';
			ELSE
				h_sync <= '1';
			END IF;

			IF (line_cnt >= 490 AND line_cnt < 492) THEN
				v_sync <= '0';
			ELSE
				v_sync <= '1';
			END IF;

			IF (pixel_cnt < 640 AND line_cnt < 480) THEN
				active_area <= '1';
			ELSE
				active_area <= '0';
			END IF;

			x <= pixel_cnt;
			y <= line_cnt;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
