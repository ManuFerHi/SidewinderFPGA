-------------------------------------------------------------------[16.03.2011]
-- KEYBOARD CONTROLLER PS/2 scancode to Spectrum matrix conversion
-------------------------------------------------------------------------------
-- V0.1 	05.10.2011	первая версия
-- V0.2		16.03.2014	измененмия в key_f (активная клавиша теперь устанавливается в '1')

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity keyboard is
generic (
	-- Include code for LED status updates
	ledStatusSupport : boolean := true;
	-- Number of system-cycles used for PS/2 clock filtering
	clockFilter : integer := 15;
	-- Timer calibration
	ticksPerUsec : integer := 28 );  -- 28Mhz clock
port (
	CLK			: in std_logic;
	RESET		: in std_logic;
	
	A			: in std_logic_vector(7 downto 0);
	KEYB		: out std_logic_vector(4 downto 0);
	
	KEYF		: out std_logic_vector(12 downto 1);
	KEYJOY		: out std_logic_vector(4 downto 0);
	KEYNUMLOCK	: out std_logic;
	KEYRESET	: out std_logic;
	KEYLED		: in std_logic_vector(2 downto 0);
	
	PS2_KBCLK	: inout std_logic;
	PS2_KBDAT	: inout std_logic );
end keyboard;

architecture rtl of keyboard is
type key_matrix is array (7 downto 0) of std_logic_vector(4 downto 0);
signal keys			: key_matrix;
signal release		: std_logic;
signal extended		: std_logic;
-- This pulses high for one tick when a new byte is received from the keyboard
signal data			: std_logic_vector(7 downto 0);
signal valid		: std_logic;
signal key_f		: std_logic_vector(12 downto 1) := "000000000000";
signal key_reset	: std_logic := '1';
signal key_num		: std_logic := '1';
signal key_joy		: std_logic_vector(4 downto 0) := "00000";
signal flag_num		: std_logic := '0';
signal caps_lock	: std_logic;
signal num_lock		: std_logic;
signal scroll_lock	: std_logic;
signal ps2_clk_out	: std_logic;
signal ps2_dat_out	: std_logic;
signal row0, row1, row2, row3, row4, row5, row6, row7 : std_logic_vector(4 downto 0);
begin
	Ps2Keyboard : entity work.io_ps2_keyboard
	generic map (
		ledStatusSupport => ledStatusSupport,
		clockFilter => clockFilter,
		ticksPerUsec => ticksPerUsec )
	port map (
		clk => CLK,
		reset => RESET,
		
		-- PS/2 connector
		ps2_clk_in => PS2_KBCLK,
		ps2_dat_in => PS2_KBDAT,
		ps2_clk_out => ps2_clk_out,
		ps2_dat_out => ps2_dat_out,

		-- LED status
		caps_lock => caps_lock,
		num_lock => num_lock,
		scroll_lock => scroll_lock,

		-- Read scancode
		trigger => valid,
		scancode => data );

	-- Output addressed row to ULA
--	KEYB <= keys(0) when A(0) = '0' else
--			keys(1) when A(1) = '0' else
--			keys(2) when A(2) = '0' else
--			keys(3) when A(3) = '0' else
--			keys(4) when A(4) = '0' else
--			keys(5) when A(5) = '0' else
--			keys(6) when A(6) = '0' else
--			keys(7) when A(7) = '0' else
--			(others => '1');

	row0 <= keys(0) when A(0) = '0' else (others => '1');
	row1 <= keys(1) when A(1) = '0' else (others => '1');
	row2 <= keys(2) when A(2) = '0' else (others => '1');
	row3 <= keys(3) when A(3) = '0' else (others => '1');
	row4 <= keys(4) when A(4) = '0' else (others => '1');
	row5 <= keys(5) when A(5) = '0' else (others => '1');
	row6 <= keys(6) when A(6) = '0' else (others => '1');
	row7 <= keys(7) when A(7) = '0' else (others => '1');
	KEYB <= row0 and row1 and row2 and row3 and row4 and row5 and row6 and row7;
		
	KEYJOY 		<= key_joy;
	KEYNUMLOCK 	<= flag_num;
	KEYRESET 	<= not key_reset;
	KEYF 		<= key_f;

	flag_num 	<= not(flag_num) when (key_num'event and key_num = '0');
	num_lock 	<= KEYLED(2);
	caps_lock 	<= KEYLED(1);
	scroll_lock <= KEYLED(0);

	PS2_KBCLK <= '0' when ps2_clk_out = '0' else 'Z';
	PS2_KBDAT <= '0' when ps2_dat_out = '0' else 'Z';

	process (RESET, CLK)
	begin
		if RESET = '1' then
			release <= '0';
			extended <= '0';
			
			keys(0) <= (others => '1');
			keys(1) <= (others => '1');
			keys(2) <= (others => '1');
			keys(3) <= (others => '1');
			keys(4) <= (others => '1');
			keys(5) <= (others => '1');
			keys(6) <= (others => '1');
			keys(7) <= (others => '1');
			
			key_f 	<= (others => '0');
			key_joy <= (others => '0');
			
		elsif rising_edge (CLK) then
			if valid = '1' then
				if data = X"E0" then
					-- Extended key code follows
					extended <= '1';
				elsif data = X"F0" then
					-- Release code follows
					release <= '1';
				else
					-- Cancel extended/release flags for next time
					release <= '0';
					extended <= '0';
				end if;
				case extended & std_logic_vector(data) is					
					when '0' & X"12" => keys(0)(0) <= release; -- Left shift (CAPS SHIFT)
					when '0' & X"59" => keys(0)(0) <= release; -- Right shift (CAPS SHIFT)
					when '0' & X"1A" => keys(0)(1) <= release; -- Z
					when '0' & X"22" => keys(0)(2) <= release; -- X
					when '0' & X"21" => keys(0)(3) <= release; -- C
					when '0' & X"2A" => keys(0)(4) <= release; -- V
					
					when '0' & X"1C" => keys(1)(0) <= release; -- A
					when '0' & X"1B" => keys(1)(1) <= release; -- S
					when '0' & X"23" => keys(1)(2) <= release; -- D
					when '0' & X"2B" => keys(1)(3) <= release; -- F
					when '0' & X"34" => keys(1)(4) <= release; -- G
					
					when '0' & X"15" => keys(2)(0) <= release; -- Q
					when '0' & X"1D" => keys(2)(1) <= release; -- W
					when '0' & X"24" => keys(2)(2) <= release; -- E
					when '0' & X"2D" => keys(2)(3) <= release; -- R
					when '0' & X"2C" => keys(2)(4) <= release; -- T				
				
					when '0' & X"16" => keys(3)(0) <= release; -- 1
					when '0' & X"1E" => keys(3)(1) <= release; -- 2
					when '0' & X"26" => keys(3)(2) <= release; -- 3
					when '0' & X"25" => keys(3)(3) <= release; -- 4
					when '0' & X"2E" => keys(3)(4) <= release; -- 5			
					
					when '0' & X"45" => keys(4)(0) <= release; -- 0
					when '0' & X"46" => keys(4)(1) <= release; -- 9
					when '0' & X"3E" => keys(4)(2) <= release; -- 8
					when '0' & X"3D" => keys(4)(3) <= release; -- 7
					when '0' & X"36" => keys(4)(4) <= release; -- 6
					
					when '0' & X"4D" => keys(5)(0) <= release; -- P
					when '0' & X"44" => keys(5)(1) <= release; -- O
					when '0' & X"43" => keys(5)(2) <= release; -- I
					when '0' & X"3C" => keys(5)(3) <= release; -- U
					when '0' & X"35" => keys(5)(4) <= release; -- Y
					
					when '0' & X"5A" => keys(6)(0) <= release; -- ENTER
					when '0' & X"4B" => keys(6)(1) <= release; -- L
					when '0' & X"42" => keys(6)(2) <= release; -- K
					when '0' & X"3B" => keys(6)(3) <= release; -- J
					when '0' & X"33" => keys(6)(4) <= release; -- H
					
					when '0' & X"29" => keys(7)(0) <= release; -- SPACE
					when '1' & X"14" => keys(7)(1) <= release; -- Right CTRL (Symbol Shift)
					when '0' & X"3A" => keys(7)(2) <= release; -- M
					when '0' & X"31" => keys(7)(3) <= release; -- N
					when '0' & X"32" => keys(7)(4) <= release; -- B

					-- Kempston keys
					when '0' & X"74" =>	key_joy(0) <= not release; -- [6] (Right)
					when '0' & X"6B" =>	key_joy(1) <= not release; -- [4] (Left)
					when '0' & X"73" =>	key_joy(2) <= not release; -- [5] (Down)
					when '0' & X"75" =>	key_joy(3) <= not release; -- [8] (Up)
					when '1' & X"11" =>	key_joy(4) <= not release; -- Right Alt (Fire)
					
					-- Cursor keys - these are actually extended (E0 xx), but
					-- the scancodes for the numeric keypad cursor keys are
					-- are the same but without the extension, so we'll accept
					-- the codes whether they are extended or not
					when '1' & X"6B" => keys(0)(0) <= release; -- Left (CAPS 5)
										keys(3)(4) <= release;
					when '1' & X"72" =>	keys(0)(0) <= release; -- Down (CAPS 6)
										keys(4)(4) <= release;
					when '1' & X"75" =>	keys(0)(0) <= release; -- Up (CAPS 7)
										keys(4)(3) <= release;
					when '1' & X"74" =>	keys(0)(0) <= release; -- Right (CAPS 8)
										keys(4)(2) <= release;
								
					-- Other special keys sent to the ULA as key combinations
					when '0' & X"66" =>	keys(0)(0) <= release; -- Backspace (CAPS 0)
										keys(4)(0) <= release;
					when '0' & X"58" =>	keys(0)(0) <= release; -- Caps lock (CAPS 2)
										keys(3)(1) <= release;
					when '0' & X"76" =>	keys(0)(0) <= release; -- Escape (CAPS SPACE)
										keys(7)(0) <= release;
					when '0' & X"49" =>	keys(7)(2) <= release; -- .
										keys(7)(1) <= release;
					when '0' & X"71" =>	keys(7)(2) <= release; -- .
										keys(7)(1) <= release;
					when '0' & X"7C" =>	keys(7)(4) <= release; -- *
										keys(7)(1) <= release;
					when '0' & X"79" =>	keys(6)(2) <= release; -- +
										keys(7)(1) <= release;
					when '0' & X"7B" =>	keys(6)(3) <= release; -- -
										keys(7)(1) <= release;
					when '0' & X"4E" =>	keys(6)(3) <= release; -- -
										keys(7)(1) <= release;
					when '0' & X"0D" =>	keys(3)(0) <= release; -- Tab (EDIT)
										keys(0)(0) <= release;
					when '0' & X"41" =>	keys(7)(3) <= release; -- ,
										keys(7)(1) <= release;
					when '0' & X"4C" =>	keys(5)(1) <= release; -- ;
										keys(7)(1) <= release;
					when '0' & X"52" =>	keys(5)(0) <= release; -- "
										keys(7)(1) <= release;
					when '0' & X"5D" =>	keys(0)(1) <= release; -- :
										keys(7)(1) <= release;
					when '0' & X"55" =>	keys(6)(1) <= release; -- =
										keys(7)(1) <= release;
					when '0' & X"54" =>	keys(4)(2) <= release; -- (
										keys(7)(1) <= release;
					when '0' & X"5B" =>	keys(4)(1) <= release; -- )
										keys(7)(1) <= release;

					-- Soft keys
					when '0' & X"05" =>	key_f( 1) <= not release; -- F1
					when '0' & X"06" =>	key_f( 2) <= not release; -- F2
					when '0' & X"04" =>	key_f( 3) <= not release; -- F3
					when '0' & X"0C" =>	key_f( 4) <= not release; -- F4
					when '0' & X"03" =>	key_f( 5) <= not release; -- F5
					when '0' & X"0B" =>	key_f( 6) <= not release; -- F6
					when '0' & X"83" =>	key_f( 7) <= not release; -- F7
					when '0' & X"0A" =>	key_f( 8) <= not release; -- F8
					when '0' & X"01" =>	key_f( 9) <= not release; -- F9
					when '0' & X"09" =>	key_f(10) <= not release; -- F10
					when '0' & X"78" =>	key_f(11) <= not release; -- F11
					when '0' & X"07" =>	key_f(12) <= not release; -- F12
					 
					-- Hardware keys
					when '0' & X"77" =>	key_num   <= release; -- Num Lock
					when '0' & X"7E" =>	key_reset <= release; -- Scroll Lock
				
					when others => null;
				end case;
			end if;
		end if;
	end process;

end architecture;