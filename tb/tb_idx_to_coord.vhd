-- VUnit testbench for idx_to_coord:
--   coord = center + (2*idx - (RES-1)) * RATIO / 2^(zoom+1)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_idx_to_coord IS
	GENERIC(
		runner_cfg	: STRING;
		K			: NATURAL := 16;
		RES			: NATURAL := 5;
		W_ZOOM		: NATURAL := 3;
		-- RATIO in Q fixed-point as integer bit pattern (default 1.0 with F=K-4)
		RATIO_FP	: INTEGER := 4096  -- 2^12 with K=16
	);
END tb_idx_to_coord;

ARCHITECTURE sim OF tb_idx_to_coord IS
	CONSTANT ONE		: SIGNED(K - 1 DOWNTO 0) := to_signed(2 ** (K - 4), K);  -- 1.0 in Q(4.F)
	CONSTANT W_IDX		: NATURAL := bits_of(RES - 1);
	CONSTANT CLK_PERIOD	: TIME := 10 ns;
	CONSTANT RATIO_C	: SIGNED(K - 1 DOWNTO 0) := to_signed(RATIO_FP, K);

	SIGNAL clk		: STD_LOGIC := '0';
	SIGNAL en		: STD_LOGIC := '0';
	SIGNAL center	: SIGNED(K - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL idx		: UNSIGNED(W_IDX - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL zoom		: UNSIGNED(W_ZOOM - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL coord	: SIGNED(K - 1 DOWNTO 0);
	SIGNAL idx_out	: UNSIGNED(W_IDX - 1 DOWNTO 0);
	SIGNAL valid	: STD_LOGIC;

	FUNCTION expected_coord(
		CONSTANT c		: SIGNED;
		CONSTANT idx_n	: NATURAL;
		CONSTANT z		: NATURAL
	) RETURN SIGNED IS
		-- widths match DUT: diff is SIGNED(bits_of(RES-1) DOWNTO 0)
		-- numeric_std "*" returns L+R bits (= SIGNED(L+R-1 downto 0))
		CONSTANT DIFF_W	: NATURAL := bits_of(RES - 1) + 1;
		VARIABLE diff_v	: SIGNED(DIFF_W - 1 DOWNTO 0);
		VARIABLE prod_v	: SIGNED(RATIO_C'LENGTH + DIFF_W - 1 DOWNTO 0);
		VARIABLE shift_v	: SIGNED(K - 1 DOWNTO 0);
	BEGIN
		diff_v := to_signed(2 * idx_n - (RES - 1), DIFF_W);
		prod_v := diff_v * RATIO_C;
		shift_v := resize(shift_right(prod_v, z + 1), K);
		RETURN resize(c + shift_v, K);
	END FUNCTION;

	PROCEDURE apply(
		CONSTANT c		: SIGNED;
		CONSTANT idx_n	: NATURAL;
		CONSTANT z		: NATURAL;
		SIGNAL center_s	: OUT SIGNED(K - 1 DOWNTO 0);
		SIGNAL idx_s	: OUT UNSIGNED(W_IDX - 1 DOWNTO 0);
		SIGNAL zoom_s	: OUT UNSIGNED(W_ZOOM - 1 DOWNTO 0);
		SIGNAL en_s		: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		center_s	<= c;
		idx_s		<= to_unsigned(idx_n, W_IDX);
		zoom_s		<= to_unsigned(z, W_ZOOM);
		en_s		<= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s		<= '0';
		WAIT FOR 1 ns;  -- combo after registered inputs
	END PROCEDURE;

	PROCEDURE check_point(
		CONSTANT c		: SIGNED;
		CONSTANT idx_n	: NATURAL;
		CONSTANT z		: NATURAL;
		CONSTANT msg	: STRING;
		SIGNAL center_s	: OUT SIGNED(K - 1 DOWNTO 0);
		SIGNAL idx_s	: OUT UNSIGNED(W_IDX - 1 DOWNTO 0);
		SIGNAL zoom_s	: OUT UNSIGNED(W_ZOOM - 1 DOWNTO 0);
		SIGNAL en_s		: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC;
		SIGNAL coord_s	: IN SIGNED(K - 1 DOWNTO 0);
		SIGNAL idx_out_s: IN UNSIGNED(W_IDX - 1 DOWNTO 0);
		SIGNAL valid_s	: IN STD_LOGIC
	) IS
		VARIABLE exp : SIGNED(K - 1 DOWNTO 0);
	BEGIN
		apply(c, idx_n, z, center_s, idx_s, zoom_s, en_s, clk_s);
		exp := expected_coord(c, idx_n, z);
		check_equal(coord_s, exp, msg);
		check_equal(idx_out_s, idx_n, msg & " idx_out");
		check_equal(valid_s, '1', msg & " valid");
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.idx_to_coord
		GENERIC MAP(
			K		=> K,
			RES		=> RES,
			W_IDX	=> W_IDX,
			W_ZOOM	=> W_ZOOM,
			RATIO	=> RATIO_C
		)
		PORT MAP(
			clk		=> clk,
			en		=> en,
			center	=> center,
			idx		=> idx,
			zoom	=> zoom,
			coord	=> coord,
			idx_out	=> idx_out,
			valid	=> valid
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE held : SIGNED(K - 1 DOWNTO 0);
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("corners_zoom0") THEN
				check_point(to_signed(0, K), 0, 0, "idx=0 zoom=0 center=0",
					center, idx, zoom, en, clk, coord, idx_out, valid);
				check_point(to_signed(0, K), RES - 1, 0, "idx=RES-1 zoom=0 center=0",
					center, idx, zoom, en, clk, coord, idx_out, valid);
				check_point(ONE, 0, 0, "idx=0 zoom=0 center=1.0",
					center, idx, zoom, en, clk, coord, idx_out, valid);
				check_point(-ONE, RES - 1, 0, "idx=RES-1 zoom=0 center=-1.0",
					center, idx, zoom, en, clk, coord, idx_out, valid);

			ELSIF run("mid_pixel") THEN
				-- odd RES: middle idx has diff=0 => coord=center
				check_point(resize(3 * ONE, K), RES / 2, 0, "mid idx => coord=center",
					center, idx, zoom, en, clk, coord, idx_out, valid);

			ELSIF run("zoom") THEN
				check_point(to_signed(0, K), 0, 1, "idx=0 zoom=1",
					center, idx, zoom, en, clk, coord, idx_out, valid);
				check_point(to_signed(0, K), RES - 1, 1, "idx=RES-1 zoom=1",
					center, idx, zoom, en, clk, coord, idx_out, valid);
				check_point(to_signed(0, K), 0, 2, "idx=0 zoom=2",
					center, idx, zoom, en, clk, coord, idx_out, valid);
				check_point(to_signed(0, K), RES - 1, 2, "idx=RES-1 zoom=2",
					center, idx, zoom, en, clk, coord, idx_out, valid);

			ELSIF run("en_hold") THEN
				check_point(to_signed(0, K), 0, 0, "load before hold",
					center, idx, zoom, en, clk, coord, idx_out, valid);
				held := coord;
				-- change inputs with en=0: registered state must hold; valid clears
				center	<= ONE;
				idx		<= to_unsigned(RES - 1, W_IDX);
				zoom	<= to_unsigned(1, W_ZOOM);
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(coord, held, "coord must hold when en=0");
				check_equal(idx_out, 0, "idx_out must hold when en=0");
				check_equal(valid, '0', "valid must clear when en=0");

			ELSIF run("sweep_idx") THEN
				-- hits every pixel (small RES) or a few samples (large RES)
				IF RES <= 16 THEN
					FOR n IN 0 TO RES - 1 LOOP
						check_point(to_signed(0, K), n, 0, "sweep zoom=0",
							center, idx, zoom, en, clk, coord, idx_out, valid);
						check_point(to_signed(0, K), n, 1, "sweep zoom=1",
							center, idx, zoom, en, clk, coord, idx_out, valid);
					END LOOP;
				ELSE
					check_point(to_signed(0, K), 1, 0, "sweep idx=1",
						center, idx, zoom, en, clk, coord, idx_out, valid);
					check_point(to_signed(0, K), RES / 4, 0, "sweep idx=RES/4",
						center, idx, zoom, en, clk, coord, idx_out, valid);
					check_point(to_signed(0, K), (3 * RES) / 4, 1, "sweep idx=3RES/4 zoom=1",
						center, idx, zoom, en, clk, coord, idx_out, valid);
				END IF;
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
