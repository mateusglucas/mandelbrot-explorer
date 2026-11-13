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
USE work.utils.all;

ENTITY memory IS
	GENERIC(
		W_DATA	 : NATURAL := 3;
		MEM_SIZE : NATURAL := 76800
	);
	PORT
	(
		clk_wr	 : IN STD_LOGIC;
		wr_en	 : IN STD_LOGIC;
		wr_addr	 : IN UNSIGNED(bits_of(MEM_SIZE-1)-1 DOWNTO 0);
		wr_data	 : IN STD_LOGIC_VECTOR (W_DATA-1 DOWNTO 0);

		clk_rd	 : IN STD_LOGIC;
		rd_en	 : IN STD_LOGIC;
		rd_addr	 : IN UNSIGNED(bits_of(MEM_SIZE-1)-1 DOWNTO 0);
		rd_data	 : OUT STD_LOGIC_VECTOR (W_DATA-1 DOWNTO 0)
	);
END memory;

ARCHITECTURE behavioral OF memory IS
TYPE memory_type IS ARRAY (0 TO MEM_SIZE-1) OF STD_LOGIC_VECTOR(W_DATA-1 DOWNTO 0);
SIGNAL mem : memory_type:=(OTHERS=>(OTHERS=>'0'));

BEGIN

PROCESS(clk_wr)
BEGIN
	IF(RISING_EDGE(clk_wr)) THEN
		IF(wr_en='1') and (wr_addr<MEM_SIZE) THEN
			mem(TO_INTEGER(wr_addr))<=wr_data;
		END IF;
	END IF;
END PROCESS;

PROCESS(clk_rd)
BEGIN
	IF(RISING_EDGE(clk_rd)) THEN
		IF(rd_en='1') and (rd_addr<MEM_SIZE) THEN
			rd_data<=mem(TO_INTEGER(rd_addr));
		END IF;
	END IF;
END PROCESS;
END behavioral;