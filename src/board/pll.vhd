-- PLL do GW2AR-18C (rPLL)
-- CLKOUT = FCLKIN*(FBDIV_SEL+1)/(IDIV_SEL+1); VCO = CLKOUT*ODIV_SEL (deve ficar entre 500 e 1250 MHz)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;

ENTITY pll IS
	GENERIC (
		fclkin    : string  := "27";
		idiv_sel  : integer := 0;
		fbdiv_sel : integer := 2;
		odiv_sel  : integer := 8
	);
	PORT (
		clkin  : IN    std_logic;
		clkout : OUT   std_logic;
		lock   : OUT   std_logic
	);
END ENTITY pll;

ARCHITECTURE structural OF pll IS

	COMPONENT rpll IS
		GENERIC (
			fclkin           : string := "100.0";
			device           : string := "GW2A-18";
			dyn_idiv_sel     : string := "false";
			idiv_sel         : integer := 0;
			dyn_fbdiv_sel    : string := "false";
			fbdiv_sel        : integer := 0;
			dyn_odiv_sel     : string := "false";
			odiv_sel         : integer := 8;
			psda_sel         : string := "0000";
			dyn_da_en        : string := "false";
			dutyda_sel       : string := "1000";
			clkout_ft_dir    : bit := '1';
			clkoutp_ft_dir   : bit := '1';
			clkout_dly_step  : integer := 0;
			clkoutp_dly_step : integer := 0;
			clkoutd3_src     : string := "CLKOUT";
			clkfb_sel        : string := "internal";
			clkout_bypass    : string := "false";
			clkoutp_bypass   : string := "false";
			clkoutd_bypass   : string := "false";
			clkoutd_src      : string := "CLKOUT";
			dyn_sdiv_sel     : integer := 2
		);
		PORT (
			clkin    : IN    std_logic;
			clkfb    : IN    std_logic;
			idsel    : IN    std_logic_vector(5 DOWNTO 0);
			fbdsel   : IN    std_logic_vector(5 DOWNTO 0);
			odsel    : IN    std_logic_vector(5 DOWNTO 0);
			reset    : IN    std_logic;
			reset_p  : IN    std_logic;
			psda     : IN    std_logic_vector(3 DOWNTO 0);
			fdly     : IN    std_logic_vector(3 DOWNTO 0);
			dutyda   : IN    std_logic_vector(3 DOWNTO 0);
			lock     : OUT   std_logic;
			clkout   : OUT   std_logic;
			clkoutd  : OUT   std_logic;
			clkoutp  : OUT   std_logic;
			clkoutd3 : OUT   std_logic
		);
	END COMPONENT rpll;

BEGIN

	PLL_INST : COMPONENT rpll
		GENERIC MAP (
			fclkin    => fclkin,
			device    => "GW2AR-18C",
			idiv_sel  => idiv_sel,
			fbdiv_sel => fbdiv_sel,
			odiv_sel  => odiv_sel
		)
		PORT MAP (
			clkin    => clkin,
			clkfb    => '0',
			idsel    => (OTHERS => '0'),
			fbdsel   => (OTHERS => '0'),
			odsel    => (OTHERS => '0'),
			reset    => '0',
			reset_p  => '0',
			psda     => (OTHERS => '0'),
			fdly     => (OTHERS => '0'),
			dutyda   => (OTHERS => '0'),
			lock     => lock,
			clkout   => clkout,
			clkoutd  => OPEN,
			clkoutp  => OPEN,
			clkoutd3 => OPEN
		);

END ARCHITECTURE structural;
