-- transmissor DVI (compativel com HDMI): 3 canais TMDS + clock, serializados 10:1 com OSER10
-- pclk e o clock de pixel e sclk deve ser exatamente 5x pclk (OSER10 trabalha em DDR)
-- canal 0 = azul (leva h_sync e v_sync), canal 1 = verde, canal 2 = vermelho

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY hdmi_tx IS
	PORT (
		pclk       : IN    std_logic;
		sclk       : IN    std_logic;
		rst        : IN    std_logic;
		rgb        : IN    std_logic_vector(23 DOWNTO 0);
		de         : IN    std_logic;
		h_sync     : IN    std_logic;
		v_sync     : IN    std_logic;
		tmds_clk_p : OUT   std_logic;
		tmds_clk_n : OUT   std_logic;
		tmds_d_p   : OUT   std_logic_vector(2 DOWNTO 0);
		tmds_d_n   : OUT   std_logic_vector(2 DOWNTO 0)
	);
END ENTITY hdmi_tx;

ARCHITECTURE structural OF hdmi_tx IS

	COMPONENT oser10 IS
		GENERIC (
			gsren : string := "false";
			lsren : string := "true"
		);
		PORT (
			d0    : IN    std_logic;
			d1    : IN    std_logic;
			d2    : IN    std_logic;
			d3    : IN    std_logic;
			d4    : IN    std_logic;
			d5    : IN    std_logic;
			d6    : IN    std_logic;
			d7    : IN    std_logic;
			d8    : IN    std_logic;
			d9    : IN    std_logic;
			pclk  : IN    std_logic;
			reset : IN    std_logic;
			fclk  : IN    std_logic;
			q     : OUT   std_logic
		);
	END COMPONENT oser10;

	COMPONENT elvds_obuf IS
		PORT (
			o  : OUT   std_logic;
			ob : OUT   std_logic;
			i  : IN    std_logic
		);
	END COMPONENT elvds_obuf;

	TYPE word_arr IS ARRAY(0 TO 3) OF std_logic_vector(9 DOWNTO 0);

	SIGNAL palavra : word_arr;
	SIGNAL serial  : std_logic_vector(3 DOWNTO 0);

BEGIN

	ENC_B : ENTITY work.tmds_encoder
		PORT MAP (
			clk   => pclk,
			data  => rgb(7 DOWNTO 0),
			c0    => h_sync,
			c1    => v_sync,
			de    => de,
			q_out => palavra(0)
		);

	ENC_G : ENTITY work.tmds_encoder
		PORT MAP (
			clk   => pclk,
			data  => rgb(15 DOWNTO 8),
			c0    => '0',
			c1    => '0',
			de    => de,
			q_out => palavra(1)
		);

	ENC_R : ENTITY work.tmds_encoder
		PORT MAP (
			clk   => pclk,
			data  => rgb(23 DOWNTO 16),
			c0    => '0',
			c1    => '0',
			de    => de,
			q_out => palavra(2)
		);

	palavra(3) <= "0000011111"; -- clock TMDS: 5 bits altos e 5 baixos por pixel

	GEN_SER : FOR i IN 0 TO 3 GENERATE

		SER : COMPONENT oser10
			PORT MAP (
				d0    => palavra(i)(0),
				d1    => palavra(i)(1),
				d2    => palavra(i)(2),
				d3    => palavra(i)(3),
				d4    => palavra(i)(4),
				d5    => palavra(i)(5),
				d6    => palavra(i)(6),
				d7    => palavra(i)(7),
				d8    => palavra(i)(8),
				d9    => palavra(i)(9),
				pclk  => pclk,
				reset => rst,
				fclk  => sclk,
				q     => serial(i)
			);

	END GENERATE GEN_SER;

	GEN_BUF : FOR i IN 0 TO 2 GENERATE

		BUF : COMPONENT elvds_obuf
			PORT MAP (
				i  => serial(i),
				o  => tmds_d_p(i),
				ob => tmds_d_n(i)
			);

	END GENERATE GEN_BUF;

	BUF_CLK : COMPONENT elvds_obuf
		PORT MAP (
			i  => serial(3),
			o  => tmds_clk_p,
			ob => tmds_clk_n
		);

END ARCHITECTURE structural;
