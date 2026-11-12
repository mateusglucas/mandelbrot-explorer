-- This entity calculates the address of a pixel in the framebuffer based on the row and column of the pixel.
-- The address is calculated as follows:
-- addr = RES_H * row + col
-- where RES_H is the horizontal resolution of the screen, row is the row of the pixel and col is the column of the pixel.

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY calc_addr IS
	GENERIC (
		RES_H	: NATURAL := 320;
		--RES_V	: NATURAL := 240;
		W_COL	: NATURAL := 9; -- bits_of(RES_H-1)
		W_ROW	: NATURAL := 8; -- bits_of(RES_V-1)
		W_ADDR	: NATURAL := 17 -- bits_of(RES_H*RES_V-1)
	);
	PORT
	(
		clk		: IN STD_LOGIC;
		en		: IN STD_LOGIC;
		row		: IN UNSIGNED (W_ROW-1 DOWNTO 0);
		col 	: IN UNSIGNED (W_COL-1 DOWNTO 0);
		addr	: OUT UNSIGNED (W_ADDR-1 DOWNTO 0);
		valid	: OUT STD_LOGIC
	);
END calc_addr;

ARCHITECTURE structural OF calc_addr IS
SIGNAL valid_r: STD_LOGIC:='0';
BEGIN
	valid<=valid_r;

	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			IF en='1' THEN
				addr <= resize(to_unsigned(RES_H, bits_of(RES_H)) * row, W_ADDR) + resize(col, W_ADDR);
				valid_r <= '1';
			END IF;
		END IF;
	END PROCESS;

END structural;