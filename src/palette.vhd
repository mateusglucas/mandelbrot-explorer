-- Map iteration count to 24-bit RGB (ROM built at elaboration)
-- Max-iter points (255) are black; others follow a cyclic gradient

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY palette IS
	GENERIC(
		STEP : NATURAL := 8
	);
	PORT(
		clk		: IN  STD_LOGIC;
		iter	: IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		rgb		: OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
	);
END palette;

ARCHITECTURE behavioral OF palette IS
	TYPE rom_t IS ARRAY (0 TO 255) OF STD_LOGIC_VECTOR(23 DOWNTO 0);
	TYPE int_arr IS ARRAY (0 TO 5) OF INTEGER;

	CONSTANT POS : int_arr := (0, 41, 108, 164, 220, 256);
	CONSTANT R   : int_arr := (0, 32, 237, 255, 0, 0);
	CONSTANT G   : int_arr := (7, 107, 255, 170, 2, 7);
	CONSTANT B   : int_arr := (100, 203, 255, 0, 0, 100);

	FUNCTION build_rom RETURN rom_t IS
		VARIABLE rom : rom_t;
		VARIABLE phase, k, rr, gg, bb : INTEGER;
	BEGIN
		FOR i IN 0 TO 255 LOOP
			phase := (i * STEP) MOD 256;
			k := 0;
			FOR j IN 0 TO 4 LOOP
				IF phase >= POS(j) THEN
					k := j;
				END IF;
			END LOOP;
			rr := R(k) + ((R(k + 1) - R(k)) * (phase - POS(k))) / (POS(k + 1) - POS(k));
			gg := G(k) + ((G(k + 1) - G(k)) * (phase - POS(k))) / (POS(k + 1) - POS(k));
			bb := B(k) + ((B(k + 1) - B(k)) * (phase - POS(k))) / (POS(k + 1) - POS(k));
			rom(i) := STD_LOGIC_VECTOR(TO_UNSIGNED(rr, 8))
				& STD_LOGIC_VECTOR(TO_UNSIGNED(gg, 8))
				& STD_LOGIC_VECTOR(TO_UNSIGNED(bb, 8));
		END LOOP;
		rom(255) := (OTHERS => '0');
		RETURN rom;
	END FUNCTION;

	CONSTANT TABLE : rom_t := build_rom;
BEGIN
	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			rgb <= TABLE(TO_INTEGER(UNSIGNED(iter)));
		END IF;
	END PROCESS;
END behavioral;
