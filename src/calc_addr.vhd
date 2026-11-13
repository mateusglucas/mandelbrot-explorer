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
		RES_V	: NATURAL := 240
	);
	PORT
	(
		clk		  : IN STD_LOGIC;
		rst		  : IN STD_LOGIC;
		en		  : IN STD_LOGIC;
		valid_in  : IN STD_LOGIC;
		row		  : IN UNSIGNED (bits_of(RES_V-1)-1 DOWNTO 0);
		col 	  : IN UNSIGNED (bits_of(RES_H-1)-1 DOWNTO 0);
		addr	  : OUT UNSIGNED (bits_of(RES_H*RES_V-1)-1 DOWNTO 0);
		valid_out : OUT STD_LOGIC
	);
END calc_addr;

ARCHITECTURE structural OF calc_addr IS
SIGNAL valid_out_r: STD_LOGIC;

CONSTANT W_ADDR: NATURAL := bits_of(RES_H*RES_V-1);

BEGIN			
	valid_out<=valid_out_r;

	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			IF rst='1' THEN
				valid_out_r <= '0';
			ELSIF en='1' THEN
				addr <= resize(to_unsigned(RES_H, bits_of(RES_H)) * row, W_ADDR) + resize(col, W_ADDR);
				valid_out_r <= valid_in;
			END IF;
		END IF;
	END PROCESS;

END structural;