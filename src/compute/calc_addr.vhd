-- This entity calculates the address of a pixel in the framebuffer based on the row and column of the pixel.
-- The address is calculated as follows:
-- addr = RES_H * row + col
-- where RES_H is the horizontal resolution of the screen, row is the row of the pixel and col is the column of the pixel.

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY calc_addr IS
	GENERIC (
		res_h	: natural := 320;
		res_v	: natural := 240
	);
	PORT (
		clk       : IN    std_logic;
		rst       : IN    std_logic;
		en        : IN    std_logic;
		valid_in  : IN    std_logic;
		row       : IN    unsigned(bits_of(res_v - 1) - 1 DOWNTO 0);
		col 	  : IN    unsigned(bits_of(res_h - 1) - 1 DOWNTO 0);
		addr	  : OUT   unsigned(bits_of(res_h * res_v - 1) - 1 DOWNTO 0);
		valid_out : OUT   std_logic
	);
END ENTITY calc_addr;

ARCHITECTURE structural OF calc_addr IS

	SIGNAL valid_out_r : std_logic;

	CONSTANT w_addr : natural := bits_of(res_h * res_v - 1);

BEGIN

	valid_out <= valid_out_r;

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				valid_out_r <= '0';
			ELSIF (en = '1') THEN
				addr        <= resize(to_unsigned(res_h, bits_of(res_h)) * row, w_addr) + resize(col, w_addr);
				valid_out_r <= valid_in;
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE structural;
