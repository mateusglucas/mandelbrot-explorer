--conversor com pipeline total de 9 estagios

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY conversor_x IS
	GENERIC(
		K	: NATURAL:=36; --quantidade de bit para usar na representacao dos numeros
		z_1: NATURAL:= 9 -- quantidade de bits para representar RES_H-1
	);
	PORT
	(
		centro_x		: IN SIGNED (K-1 DOWNTO 0);
		b				: IN UNSIGNED (z_1-1 DOWNTO 0); -- conta de 0 a RES_H-1
		zoom			: IN UNSIGNED (4 DOWNTO 0);
		x				: OUT SIGNED (K-1 DOWNTO 0);
		--overflow		: OUT STD_LOGIC;
		clk			: IN STD_LOGIC;
		b_out			:	OUT UNSIGNED (z_1-1 DOWNTO 0);
		en				: IN STD_LOGIC
	);
END conversor_x;

ARCHITECTURE structural OF conversor_x IS
CONSTANT z_2	: 	NATURAL:=34; -- negativo do expoente de 2 na representacao de n (n=34252364186*2**-34, entao z_2=34)
CONSTANT z_3	: 	NATURAL:=44; -- idem ao caso acima, mas agora para inv_res_x
CONSTANT n : UNSIGNED (K-2 DOWNTO 0):="111"&X"F999999A"; -- n=(320-1)*2/320=34252364186*2**-34 (o numero 2 se refere ao x maximo observavel quando zoom=0)
CONSTANT inv_res_x: UNSIGNED (K-1 DOWNTO 0):=X"CD712752B";-- inv_res_x=1/(320-1)=55147918635*2**-44

SIGNAL aux_1: UNSIGNED (z_1+K-1 DOWNTO 0);
SIGNAL aux_2: SIGNED (K-1 DOWNTO 0);
SIGNAL aux_3: SIGNED (2*K-1 DOWNTO 0);
SIGNAL aux_4: SIGNED (K DOWNTO 0);
SIGNAL aux_5: SIGNED (K+1 DOWNTO 0);
SIGNAL aux_6: SIGNED (z_3-z_1-1 DOWNTO 0):=(OTHERS=>'0');--para fazer 2**(z_3-z_1-2) (deu maior do que 2**33)
SIGNAL aux_7: UNSIGNED (11-z_1-1 DOWNTO 0):=(OTHERS=>'0'); --zeros auxiliares para serem concatenados a "b" na entrada do multiplicador de modo que resulte em 11 bits (ja  estou preparando para full hd)

TYPE data_c IS ARRAY (0 TO 8) OF UNSIGNED (z_1-1 DOWNTO 0);
SIGNAL latch: data_c;

BEGIN
	aux_6(aux_6'LENGTH-2)<='1';
	x<=aux_5(K+1) & aux_5(K-2 DOWNTO 0);
	b_out<=latch(8);
	--overflow<= '0' WHEN(aux_5(K-1)=aux_5(K+1) AND aux_5(K)=aux_5(K+1)) ELSE '1';
	
	--multiplicador com pipeline de 3 estagios
	MULT1: entity work.mult_3 PORT MAP(
	clock => clk,
	dataa => STD_LOGIC_VECTOR(inv_res_x),
	datab => STD_LOGIC_VECTOR(UNSIGNED'(aux_7 & b)),
	UNSIGNED(result(z_1+K-1 DOWNTO 0)) => aux_1);
	
	--multiplicador com pipeline de 3 estagios
	MULT2: entity work.mult_2 PORT MAP(
	clock => clk,
	dataa => STD_LOGIC_VECTOR('0' & n),
	datab => STD_LOGIC_VECTOR(aux_2),
	SIGNED(result) => aux_3);
PROCESS(clk,en)
BEGIN
IF(RISING_EDGE(clk) AND en='1') THEN
	--aux_1<=b*inv_res_x;
	aux_2<=SIGNED('0' & aux_1(z_1+K-1 DOWNTO z_1+1))-aux_6;
	--aux_3<=SIGNED('0' & n)*aux_2;
	aux_4<=SHIFT_RIGHT(aux_3(2*K-1 DOWNTO z_2+z_3-z_1-K+2),TO_INTEGER(zoom));
	aux_5<=(centro_x)+(aux_4(K-1) & aux_4);
	
	--as linhas abaixo é pra salvar qual o valor de "a" de cada saida, pra poder calcular o endereço do pixel, juntamente 
	--com o valor de "b" que o conversor_x vai colocar na saida e passar isso pro iterador, par que quando o iterador
	--complete de iterar um pixel, ele saiba onde escrever na memoria, pq agora a priori as escritas nao vai mais ser consecutivas
	latch<=b & latch(0 TO 7);

END IF;
END PROCESS;
END structural;