--AJEITAR PARA QUE PULSOS DE VSYNC E HSYNC TENHAM INICIO AO MESMO TEMPO
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY vga_sync IS
	PORT
	(
		clock			: IN STD_LOGIC; --25.175 MHz
		v_sync		: OUT STD_LOGIC;
		h_sync		: OUT STD_LOGIC;
		active_area	: OUT STD_LOGIC
	);
END vga_sync;

ARCHITECTURE behavioral OF vga_sync IS
SIGNAL pixel_cnt	: UNSIGNED (9 DOWNTO 0); --até 800
SIGNAL line_cnt	: UNSIGNED (9 DOWNTO 0); --até 525
BEGIN

PROCESS(clock)
BEGIN
	IF(RISING_EDGE(clock)) THEN
		IF(pixel_cnt<799) THEN 
			pixel_cnt<=pixel_cnt+1;
			line_cnt<=line_cnt;
		ELSE
			pixel_cnt<=(OTHERS=>'0');
			IF (line_cnt<524) THEN line_cnt<=line_cnt+1;
			ELSE line_cnt<=(OTHERS=>'0');
			END IF;
		END IF;
		
		IF(pixel_cnt<96) THEN h_sync<='0';
		ELSE h_sync<='1';
		END IF;
		
		IF(line_cnt<2) THEN v_sync<='0';
		ELSE v_sync<='1';
		END IF;
		
		IF((pixel_cnt<752 AND pixel_cnt>112) AND (line_cnt<492 AND line_cnt>12)) THEN active_area<='1';
		ELSE active_area<='0';
		END IF;
		
	END IF;
END PROCESS;

END behavioral;