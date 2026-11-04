--calcula o endereço que o pixel deve ocupar na memoria, dados o valor de "b" (coluna) e "a" (linha) na tela da tv

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY calc_addr IS
	PORT
	(
		a				: IN UNSIGNED (7 DOWNTO 0);
		b				: IN UNSIGNED (8 DOWNTO 0);
		addr			: OUT UNSIGNED (16 DOWNTO 0)
	);
END calc_addr;

ARCHITECTURE structural OF calc_addr IS
BEGIN

addr<=("101000000"*a)+b; --320*a+b

END structural;