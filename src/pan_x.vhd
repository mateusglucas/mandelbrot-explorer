--bloco para fazer translação no eixo x
--a cada ciclo de clk, se inc=1 e dec=0, incrementa centro_x de uma quantidade delta 
-- se inc=0 e dec=1, decrementa centro_x de uma quantidade delta
--delta eh calculada em funcao do nivel de zoom e das constantes (eh o espaço em x ocupado por um pixel)
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY pan_x IS
	PORT
	(
		clk			: IN STD_LOGIC;
		reset			: IN STD_LOGIC;
		zoom			: IN UNSIGNED (4 DOWNTO 0);
		inc			: IN STD_LOGIC;
		dec			: IN STD_LOGIC;
		centro_x		: OUT SIGNED(35 DOWNTO 0)
	);
END pan_x;

ARCHITECTURE structural OF pan_x IS
CONSTANT delta: SIGNED (29 DOWNTO 0):="011" & X"333333"&"000"; -- 4/320 (4 eh referente a xmax-xmin quando zoom=0) = 53687091*2**(-32)
															--acrescentei tres zeros no fim pra multiplicar o delta por 8, para a translação ficar mais rapida
															--outra opção seria aumentar a frequencia do contador ligado a este bloco, mas isso aumenta muito
															--o screen tearing
SIGNAL x_aux: SIGNED(35 DOWNTO 0);
BEGIN

centro_x<=x_aux;

PROCESS(clk,reset)
BEGIN
	IF(reset='1') THEN
		x_aux<=(OTHERS=>'0');
	ELSIF(RISING_EDGE(clk)) THEN
		IF(inc='1' AND dec='0') THEN x_aux<=x_aux+(SHIFT_RIGHT(delta,TO_INTEGER(zoom)) OR "00"&X"000001"); 
		-- a condicao OR "000000001" é pra impedir q o incremento fique zero (pra zoom muito alto, 
		--o shift right aplicado ao delta vai resultar em zero), entao coloco a condicao OR pra que nunca fique zero
		ELSIF(inc='0' AND dec='1') THEN x_aux<=x_aux-(SHIFT_RIGHT(delta,TO_INTEGER(zoom)) OR "00"&X"000001");
		ELSE x_aux<=x_aux;
		END IF;
	END IF;
END PROCESS;

END structural;