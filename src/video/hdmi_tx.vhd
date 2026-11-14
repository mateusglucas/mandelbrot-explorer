--transmissor DVI (compativel com HDMI): 3 canais TMDS + clock, serializados 10:1 com OSER10
--pclk e o clock de pixel e sclk deve ser exatamente 5x pclk (OSER10 trabalha em DDR)
--canal 0 = azul (leva h_sync e v_sync), canal 1 = verde, canal 2 = vermelho
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY hdmi_tx IS
	PORT
	(
		pclk			: IN STD_LOGIC;
		sclk			: IN STD_LOGIC;
		rst			: IN STD_LOGIC;
		rgb			: IN STD_LOGIC_VECTOR (23 DOWNTO 0);
		de				: IN STD_LOGIC;
		h_sync		: IN STD_LOGIC;
		v_sync		: IN STD_LOGIC;
		tmds_clk_p	: OUT STD_LOGIC;
		tmds_clk_n	: OUT STD_LOGIC;
		tmds_d_p		: OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
		tmds_d_n		: OUT STD_LOGIC_VECTOR (2 DOWNTO 0)
	);
END hdmi_tx;

ARCHITECTURE structural OF hdmi_tx IS

COMPONENT OSER10
	GENERIC (
		GSREN : STRING := "false";
		LSREN : STRING := "true"
	);
	PORT (
		D0, D1, D2, D3, D4, D5, D6, D7, D8, D9 : IN STD_LOGIC;
		PCLK : IN STD_LOGIC;
		RESET : IN STD_LOGIC;
		FCLK : IN STD_LOGIC;
		Q : OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT ELVDS_OBUF
	PORT (
		O : OUT STD_LOGIC;
		OB : OUT STD_LOGIC;
		I : IN STD_LOGIC
	);
END COMPONENT;

TYPE word_arr IS ARRAY (0 TO 3) OF STD_LOGIC_VECTOR (9 DOWNTO 0);
SIGNAL palavra: word_arr;
SIGNAL serial: STD_LOGIC_VECTOR (3 DOWNTO 0);
BEGIN

	ENC_B: entity work.tmds_encoder PORT MAP(clk => pclk, data => rgb(7 DOWNTO 0),
		c0 => h_sync, c1 => v_sync, de => de, q_out => palavra(0));
	ENC_G: entity work.tmds_encoder PORT MAP(clk => pclk, data => rgb(15 DOWNTO 8),
		c0 => '0', c1 => '0', de => de, q_out => palavra(1));
	ENC_R: entity work.tmds_encoder PORT MAP(clk => pclk, data => rgb(23 DOWNTO 16),
		c0 => '0', c1 => '0', de => de, q_out => palavra(2));
	palavra(3)<="0000011111"; --clock TMDS: 5 bits altos e 5 baixos por pixel

	GEN_SER: FOR i IN 0 TO 3 GENERATE
		SER: OSER10 PORT MAP(
			D0 => palavra(i)(0), D1 => palavra(i)(1), D2 => palavra(i)(2), D3 => palavra(i)(3),
			D4 => palavra(i)(4), D5 => palavra(i)(5), D6 => palavra(i)(6), D7 => palavra(i)(7),
			D8 => palavra(i)(8), D9 => palavra(i)(9),
			PCLK => pclk, RESET => rst, FCLK => sclk, Q => serial(i));
	END GENERATE;

	GEN_BUF: FOR i IN 0 TO 2 GENERATE
		BUF: ELVDS_OBUF PORT MAP(I => serial(i), O => tmds_d_p(i), OB => tmds_d_n(i));
	END GENERATE;
	BUF_CLK: ELVDS_OBUF PORT MAP(I => serial(3), O => tmds_clk_p, OB => tmds_clk_n);

END structural;
