--mantem o sinal de rst ativo por 16 clks (tempo necessario para carregar dados nos pipelines
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY delay IS
	PORT
	(
		clock			: IN STD_LOGIC;
		reset			: IN STD_LOGIC;
		rst_out		: OUT STD_LOGIC
		);
END delay;

ARCHITECTURE behavioral OF delay IS
SIGNAL aux: UNSIGNED (15 DOWNTO 0);
BEGIN

rst_out<=aux(0);
PROCESS(clock,reset)
BEGIN
	IF(reset='1') THEN
		aux<=(OTHERS=>'1');
	ELSIF(RISING_EDGE(clock)) THEN
		aux<='0'&aux(15 DOWNTO 1);
	END IF;
END PROCESS;

END behavioral;