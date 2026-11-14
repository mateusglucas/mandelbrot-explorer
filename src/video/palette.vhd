-- Map iteration count to 24-bit RGB (ROM built at elaboration)
-- Max-iter points (255) are black; others follow a cyclic gradient

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY palette IS
	GENERIC (
		step : natural := 8
	);
	PORT (
		clk  : IN    std_logic;
		iter : IN    std_logic_vector(7 DOWNTO 0);
		rgb  : OUT   std_logic_vector(23 DOWNTO 0)
	);
END ENTITY palette;

ARCHITECTURE behavioral OF palette IS

	TYPE rom_t IS ARRAY(0 TO 255) OF std_logic_vector(23 DOWNTO 0);

	TYPE int_arr IS ARRAY(0 TO 5) OF integer;

	CONSTANT pos : int_arr := (0, 41, 108, 164, 220, 256);
	CONSTANT r   : int_arr := (0, 32, 237, 255, 0, 0);
	CONSTANT g   : int_arr := (7, 107, 255, 170, 2, 7);
	CONSTANT b   : int_arr := (100, 203, 255, 0, 0, 100);

	FUNCTION build_rom RETURN rom_t IS

		VARIABLE rom   : rom_t;
		VARIABLE phase : integer;
		VARIABLE k     : integer;
		VARIABLE rr    : integer;
		VARIABLE gg    : integer;
		VARIABLE bb    : integer;

	BEGIN

		FOR i IN 0 TO 255 LOOP

			phase := (i * STEP) MOD 256;
			k     := 0;

			FOR j IN 0 TO 4 LOOP

				IF (phase >= POS(j)) THEN
					k := j;
				END IF;

			END LOOP;

			rr     := R(k) + ((R(k + 1) - R(k)) * (phase - POS(k))) / (POS(k + 1) - POS(k));
			gg     := G(k) + ((G(k + 1) - G(k)) * (phase - POS(k))) / (POS(k + 1) - POS(k));
			bb     := B(k) + ((B(k + 1) - B(k)) * (phase - POS(k))) / (POS(k + 1) - POS(k));
			rom(i) := STD_LOGIC_VECTOR(TO_UNSIGNED(rr, 8))
	          & STD_LOGIC_VECTOR(TO_UNSIGNED(gg, 8))
	          & STD_LOGIC_VECTOR(TO_UNSIGNED(bb, 8));

		END LOOP;

		rom(255) := (OTHERS => '0');
		RETURN rom;

	END FUNCTION build_rom;

	CONSTANT table : rom_t := build_rom;

BEGIN

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			rgb <= TABLE(TO_INTEGER(UNSIGNED(iter)));
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
