--contador de incremento,decremento

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY contador_inc_dec IS
	GENERIC(
		N			:	NATURAL:=8;
		CNT_MAX	:	NATURAL:=10;--valor maximo de CNT_MAX é 2**N-1
		CNT_0		:	NATURAL:=5 --valor inicial do contador
	);
	PORT
	(
		clk			: IN STD_LOGIC;
		rst			: IN STD_LOGIC;
		cnt			: OUT UNSIGNED (N-1 DOWNTO 0);
		inc			: IN STD_LOGIC;
		dec			: IN STD_LOGIC
	);
END contador_inc_dec;

ARCHITECTURE behavioral OF contador_inc_dec IS
SIGNAL cnt_aux: UNSIGNED(N-1 DOWNTO 0);
BEGIN

cnt<=cnt_aux;

PROCESS(clk,rst)
BEGIN
	IF(rst='1') THEN
		cnt_aux<=TO_UNSIGNED(CNT_0,N);
	ELSIF(RISING_EDGE(clk)) THEN
		IF(inc/=dec)THEN
			IF(inc='1' AND cnt_aux<CNT_MAX) THEN cnt_aux<=cnt_aux+1;
			ELSIF(dec='1' AND cnt_aux>0) THEN cnt_aux<=cnt_aux-1;
			ELSE cnt_aux<=cnt_aux;
			END IF;
		ELSE cnt_aux<=cnt_aux;
		END IF;
	END IF;
END PROCESS;

END behavioral;