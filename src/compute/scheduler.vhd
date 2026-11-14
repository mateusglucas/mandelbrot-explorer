library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;

ENTITY scheduler IS
	GENERIC (
		RES_H : NATURAL := 320;
		RES_V : NATURAL := 240
	);
	PORT (
		clk   : IN STD_LOGIC;
		rst   : IN STD_LOGIC;
		en    : IN STD_LOGIC;
		row   : OUT UNSIGNED(bits_of(RES_V-1)-1 DOWNTO 0);
		col   : OUT UNSIGNED(bits_of(RES_H-1)-1 DOWNTO 0);
		valid : OUT STD_LOGIC
	);
END scheduler;

ARCHITECTURE behavioral OF scheduler IS
SIGNAL done: STD_LOGIC;
BEGIN
    PROCESS(clk)
    BEGIN
        IF RISING_EDGE(clk) THEN
            IF rst='1' THEN
                row <= (OTHERS => '0');
                col <= (OTHERS => '0');
                valid <= '0';
                done <= '0';
            ELSIF en='1' AND done='0' THEN
                IF valid='0' THEN
                    row <= (OTHERS => '0');
                    col <= (OTHERS => '0');
                    valid <= '1';
                ELSE
                    IF row = RES_V-1 THEN
                        IF col = RES_H-1 THEN
                            done <= '1';
                            valid <= '0';
                        ELSE
                            row <= (OTHERS => '0');
                            col <= col + 1;
                        END IF;
                    ELSE
                        row <= row + 1;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;
END behavioral;