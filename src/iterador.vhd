-- a cada ciclo de clock, este bloco faz uma iteração utilizando a lei recursiva
-- z(i+1)=z(i)^2+z_c (onde z_c=x_c+j*y_c)
-- quando o modulo de z ficar maior que 2 ou o numero de iterações maximas for atingido,
-- o sinal done fica alto, até termos reset='1', que recarregará novo valor de z_c.
-- quando reset passa de alto para baixo, tem inicio um novo ciclo de iterações, com o valor de z_c
-- igual ao carregado enquanto reset estava alto.
-- a saida iter indica o numero de iterações feitas.
-- pipeline de 7 estagios

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY iterador IS
	GENERIC(
		K	:	NATURAL:=36
	);
	PORT
	(
		clock			: IN STD_LOGIC;
		load			: IN STD_LOGIC;
		x_c			: IN SIGNED (K-1 DOWNTO 0);
		y_c			: IN SIGNED (K-1 DOWNTO 0);
		iter			: OUT UNSIGNED (7 DOWNTO 0);
		done			: OUT STD_LOGIC;
		addr			: IN UNSIGNED(16 DOWNTO 0); --de 0 a 320*240-1=76799
		addr_out		: OUT UNSIGNED(16 DOWNTO 0)
	);
END iterador;

ARCHITECTURE behavioral OF iterador IS
TYPE data_c IS ARRAY (0 TO 6) OF SIGNED (K-1 DOWNTO 0);
TYPE data_iter IS ARRAY (0 TO 6) OF UNSIGNED (7 DOWNTO 0);
TYPE data_addr IS ARRAY (0 TO 6) OF UNSIGNED (16 DOWNTO 0);

SIGNAL x_c_latch : 	data_c;
SIGNAL y_c_latch : 	data_c;
SIGNAL x_latch:		data_c;
SIGNAL y_latch:		data_c;
SIGNAL iter_latch: 	data_iter;
SIGNAL addr_latch: 	data_addr;

SIGNAL xx: 			SIGNED (2*K-1 DOWNTO 0);
SIGNAL xy: 			SIGNED (2*K-1 DOWNTO 0);
SIGNAL yy: 			SIGNED (2*K-1 DOWNTO 0);
SIGNAL aux: 		SIGNED (2*K DOWNTO 0); --xx+yy
SIGNAL done_aux:	STD_LOGIC;
SIGNAL done_aux1:	STD_LOGIC;
SIGNAL done_aux2:	STD_LOGIC;

BEGIN

	--cada multiplicador tem pipeline de 3 estagios
	MULTXY: entity work.mult PORT MAP(
	clock => clock,
	dataa => STD_LOGIC_VECTOR(x_latch(0)),
	datab => STD_LOGIC_VECTOR(y_latch(0)),
	SIGNED(result) => xy);
	
	MULTXX: entity work.square PORT MAP(
	clock => clock,
	dataa => STD_LOGIC_VECTOR(x_latch(0)),
	SIGNED(result) => xx);
	
	MULTYY: entity work.square PORT MAP(
	clock => clock,
	dataa => STD_LOGIC_VECTOR(y_latch(0)),
	SIGNED(result) => yy);
	
iter<=iter_latch(6);
addr_out<=addr_latch(6);
done<=done_aux;

PROCESS(clock,load,x_c,y_c)
BEGIN
	
	IF(RISING_EDGE(clock)) THEN
		x_c_latch(1 to 6)<=x_c_latch(0 TO 5);
		y_c_latch(1 to 6)<=y_c_latch(0 TO 5);
		
		x_latch(1 TO 3)<=x_latch(0 TO 2);
		x_latch(4)<=('0' & xx(2*K-7 DOWNTO K-4))-('0' & yy(2*K-7 DOWNTO K-4))+x_c_latch(3);
		x_latch(5 TO 6)<=x_latch(4 TO 5);
		
		y_latch(1 TO 3)<=y_latch(0 TO 2);
		y_latch(4)<=(xy(2*K-1) & xy(2*K-8 DOWNTO K-5))+y_c_latch(3);
		y_latch(5 TO 6)<=y_latch(4 TO 5);

		addr_latch(1 TO 6)<=addr_latch(0 TO 5);
		iter_latch(1 TO 6)<=iter_latch(0 TO 5);
		aux<=('0' & xx)+('0' & yy);
		
		IF(iter_latch(4)<255) THEN done_aux1<='0';
		ELSE done_aux1<='1';
		END IF;
		
		IF(SHIFT_RIGHT(aux,2*(K-4))<4) THEN done_aux2<='0';
		ELSE done_aux2<='1';	
		END IF;
		
		done_aux<=done_aux1 OR done_aux2;
		
		--IF(iter_latch(6)<255 AND SHIFT_RIGHT(aux,2*(K-4))<4) THEN done_aux<='0';
		--ELSE done_aux<='1';	
		--END IF;
		
		IF (load='1') THEN 	--reset sincrono, pra que eu consiga dar o "reset" pelo 
									--proprio "done" sem glitches, se nao done fica alto e
									--faz com que reset fique alto e ja imediatamente done fica baixo, pq reset é alto.
									--com reset sincrono, done fica alto ao menos por um periodo de clock
			x_latch(0)<=x_c;
			y_latch(0)<=y_c;
			x_c_latch(0)<=x_c;
			y_c_latch(0)<=y_c;
			addr_latch(0)<=addr;
			iter_latch(0)<=(OTHERS=>'0');
		ELSE
			x_latch(0)<=x_latch(6);
			y_latch(0)<=y_latch(6);
			x_c_latch(0)<=x_c_latch(6);
			y_c_latch(0)<=y_c_latch(6);
			addr_latch(0)<=addr_latch(6);
			iter_latch(0)<=iter_latch(6)+1;
		END IF;
	END IF;
END PROCESS;

END behavioral;