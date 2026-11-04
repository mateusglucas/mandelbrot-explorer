--a cada clock, incrementa o valor de "b". a cada estouro de "b", incrementa "a"
--"a" varia de 0 a 239 e "b" varia de 0 a 319
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY contador IS
	PORT
	(
		clock			: IN STD_LOGIC;
		reset			: IN STD_LOGIC;
		en				: IN STD_LOGIC;
		a				: OUT UNSIGNED (7 DOWNTO 0);
		b				: OUT UNSIGNED (8 DOWNTO 0)
	);
END contador;

ARCHITECTURE behavioral OF contador IS
SIGNAL a_aux: UNSIGNED (7 DOWNTO 0);
SIGNAL b_aux: UNSIGNED (8 DOWNTO 0);
BEGIN

a<=a_aux;
b<=b_aux;

PROCESS(clock,reset,en)
BEGIN
	IF(reset='1') THEN
		a_aux<=(OTHERS=>'0');
		b_aux<=(OTHERS=>'0');
	ELSIF(RISING_EDGE(clock) AND en='1') THEN
		IF(b_aux<319) THEN
			b_aux<=b_aux+1;
			a_aux<=a_aux;
		ELSE
			b_aux<=(OTHERS=>'0');
			IF(a_aux<239) THEN a_aux<=a_aux+1;
			ELSE a_aux<=(OTHERS=>'0');
			END IF;
		END IF;
	END IF;
END PROCESS;

END behavioral;