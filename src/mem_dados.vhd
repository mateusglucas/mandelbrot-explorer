-- memoria de 320*240*3 bits, com 320*240 palavras de 3 bits
-- a escrita é feita na borda de subida de wr_clk quando wr_en estiver ativo
-- a leitura é feita na borda de subida de rd, e é feita sequencialmente (primeiro coloca o dado do endereço 0,
-- depois do endereço 1, etc.
-- quando sync='1', os endereços de leitura sao resetados

--a memoria é para uma resolução de 320x240. mas utilizei resolução de 640x480 (exatamente o dobro)
--desta forma, leio cada pixel duas vezes e cada linha duas vezes para "simular" uma imagem de 640x480

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY mem_dados IS
	GENERIC(
		RES_H: NATURAL:=320;
		RES_V: NATURAL:=240
	);
	PORT
	(
		wr_data	: IN STD_LOGIC_VECTOR (2 DOWNTO 0);
		rd_data	: OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
		wr_en		: IN STD_LOGIC;
		wr_clk	: IN STD_LOGIC;
		wr_addr	: IN UNSIGNED(16 DOWNTO 0); --de 0 a 320*240-1=76799
		rd			: IN STD_LOGIC;
		sync		: IN STD_LOGIC
	);
END mem_dados;

ARCHITECTURE behavioral OF mem_dados IS
TYPE memory IS ARRAY (0 TO RES_H*RES_V-1) OF STD_LOGIC_VECTOR(2 DOWNTO 0);
SIGNAL mem : memory:=(OTHERS=>(OTHERS=>'0'));
SIGNAL cnt_rd: UNSIGNED(17 DOWNTO 0); -- conta até 2*76800-1, para ler cada pixel duas vezes
SIGNAL inc_line: STD_LOGIC; --sinal auxiliar para ler cada linha duas vezes
SIGNAL pixel_cnt: UNSIGNED(9 DOWNTO 0); --conta até 640
BEGIN

PROCESS(wr_en,wr_clk,wr_addr,mem)
BEGIN
	IF(RISING_EDGE(wr_clk) AND wr_en='1') THEN
		IF(wr_addr<76800) THEN mem(TO_INTEGER(wr_addr))<=wr_data;
		END IF;
	END IF;
END PROCESS;

PROCESS(rd,mem,sync)
BEGIN
	IF(sync='1') THEN
		cnt_rd<=(OTHERS=>'0');
		inc_line<='0';
		pixel_cnt<=(OTHERS=>'0');
	ELSIF(RISING_EDGE(rd)) THEN
		rd_data<=mem(TO_INTEGER(cnt_rd(17 DOWNTO 1)));
		
		IF(pixel_cnt<639) THEN
			pixel_cnt<=pixel_cnt+1;
			cnt_rd<=cnt_rd+1;
			inc_line<=inc_line;
		ELSE
			pixel_cnt<=(OTHERS=>'0');
			IF(inc_line='1') THEN
				inc_line<='0';
				IF(cnt_rd<153_599) THEN cnt_rd<=cnt_rd+1;
				ELSE cnt_rd<=(OTHERS=>'0');
				END IF;
			ELSE
				inc_line<='1';
				cnt_rd<=cnt_rd-639;
			END IF;
		END IF;
	END IF;
END PROCESS;

END behavioral;