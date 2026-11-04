--conversor com pipeline total de 9 estagios

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY conversor_y IS
	GENERIC(
		K	: NATURAL:=36; --quantidade de bit para usar na representacao dos numeros
		w_1: NATURAL:= 9 -- quantidade de bits para representar RES_V-1
	);
	PORT
	(
		centro_y		: IN SIGNED (K-1 DOWNTO 0);
		a				: IN UNSIGNED (w_1-1 DOWNTO 0);
		zoom			: IN UNSIGNED (4 DOWNTO 0);
		y				: OUT SIGNED (K-1 DOWNTO 0);
		--overflow		: OUT STD_LOGIC;
		clk			: IN STD_LOGIC;
		a_out			:	OUT UNSIGNED (w_1-1 DOWNTO 0);
		en				: IN STD_LOGIC
	);
END conversor_y;

ARCHITECTURE structural OF conversor_y IS
TYPE data_c IS ARRAY (0 TO 8) OF UNSIGNED (w_1-1 DOWNTO 0);
SIGNAL latch: data_c;

CONSTANT w_2	: 	NATURAL:=34; -- negativo do expoente de 2 na representacao de m (m=25662429594*2**-34, entao w_2=34)
CONSTANT w_3	: 	NATURAL:=43; -- idem ao caso acima, mas agora para inv_res_y
CONSTANT m : UNSIGNED (K-2 DOWNTO 0):="101"&X"F999999A"; -- m=(240-1)*1.5/240=25662429594*2**-34 (o numero 1.5 se refere ao y maximo observavel quando zoom=0)
CONSTANT inv_res_y: UNSIGNED (K-1 DOWNTO 0):=X"891AC73AF"; -- inv_res_y=1/(240-1)=36803736495*2**-43

SIGNAL aux_1: UNSIGNED (w_1+K-1 DOWNTO 0);
SIGNAL aux_2: SIGNED (K-1 DOWNTO 0);
SIGNAL aux_3: SIGNED (2*K-1 DOWNTO 0);
SIGNAL aux_4: SIGNED (K DOWNTO 0);
SIGNAL aux_5: SIGNED (K+1 DOWNTO 0);
SIGNAL aux_6: SIGNED (w_3-w_1-1 DOWNTO 0):=(OTHERS=>'0');--para fazer 2**(z_3-z_1-2) (deu maior do que 2**33)
SIGNAL aux_7: UNSIGNED (11-w_1-1 DOWNTO 0):=(OTHERS=>'0'); --zeros auxiliares para serem concatenados a "a" na entrada do multiplicador de modo que resulte em 11 bits (ja  estou preparando para full hd)

BEGIN
	aux_6(aux_6'LENGTH-2)<='1';
	y<=aux_5(K+1) & aux_5(K-2 DOWNTO 0);
	a_out<=latch(8);
	--overflow<= '0' WHEN(aux_5(K-1)=aux_5(K+1) AND aux_5(K)=aux_5(K+1)) ELSE '1';
	
	--multiplicador com pipeline de 3 estagios
	MULT1: entity work.mult_3 PORT MAP(
	clock => clk,
	dataa => STD_LOGIC_VECTOR(inv_res_y),
	datab => STD_LOGIC_VECTOR(UNSIGNED'(aux_7 & a)),
	UNSIGNED(result(w_1+K-1 DOWNTO 0)) => aux_1);

	--multiplicador com pipeline de 3 estagios
	MULT2: entity work.mult_2 PORT MAP(
	clock => clk,
	dataa => STD_LOGIC_VECTOR('0' & m),
	datab => STD_LOGIC_VECTOR(aux_2),
	SIGNED(result) => aux_3);
PROCESS(clk,en)
BEGIN
IF(RISING_EDGE(clk) AND en='1') THEN
	--aux_1<=a*inv_res_y;
	aux_2<=SIGNED('0' & aux_1(w_1+K-1 DOWNTO w_1+1))-aux_6;
	--aux_3<=SIGNED('0' & m)*aux_2;
	aux_4<=SHIFT_RIGHT(aux_3(2*K-1 DOWNTO w_2+w_3-w_1-K+2),TO_INTEGER(zoom));
	aux_5<=(centro_y)-(aux_4(K-1) & aux_4);
	
	--as linhas abaixo é pra salvar qual o valor de "a" de cada saida, pra poder calcular o endereço do pixel, juntamente 
	--com o valor de "b" que o conversor_x vai colocar na saida e passar isso pro iterador, par que quando o iterador
	--complete de iterar um pixel, ele saiba onde escrever na memoria, pq agora a priori as escritas nao vai mais ser consecutivas
	latch<=a & latch(0 TO 7);
	
END IF;
END PROCESS;
END structural;