--divisor de clk
--retirado o sinal de reset presente no divisor do mandelbrot_v3
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY divisor IS
	GENERIC(
		N: NATURAL:=2--METADE do fator de divisao do clk original (se N=7, freq saída é freq entrada/14)
	);
	PORT
	(
		clk_in		: IN STD_LOGIC;
		clk_out		: OUT STD_LOGIC
	);
END divisor;

ARCHITECTURE behavioral OF divisor IS
SIGNAL clk_aux: STD_LOGIC;
SIGNAL cnt: NATURAL RANGE 0 TO N-1;
BEGIN

clk_out<=clk_aux;

PROCESS(clk_in)
BEGIN
	IF(RISING_EDGE(clk_in)) THEN
		IF(cnt<N-1) THEN 
			cnt<=cnt+1;
			clk_aux<=clk_aux;
		ELSE
			cnt<=0;
			clk_aux<=NOT(clk_aux);
		END IF;
	END IF;
END PROCESS;

END behavioral;