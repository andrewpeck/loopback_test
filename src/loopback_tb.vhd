
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity loopback_tb is
end loopback_tb;

architecture behavioral of loopback_tb is

  signal clk33 : std_logic;
  signal clock_i_p  : std_logic;
  signal clock_i_n  : std_logic;
  signal clock_o_p  : std_logic;
  signal clock_o_n  : std_logic;
  signal data_i_p   : std_logic;
  signal data_i_n   : std_logic;
  signal data_o_p   : std_logic;
  signal data_o_n   : std_logic;
  signal error_o    : std_logic;

  constant clk_PERIOD : time := 25.0 ns;



begin



  clkgen : process
  begin
    clk33 <= '1';
    wait for clk_period / 2;
    clk33 <= '0';
    wait for clk_period / 2;
  end process;
  
  clock_i_p <= transport clock_o_p after 100 ns;
  clock_i_n <= transport clock_o_n after 100 ns;

  data_i_p <= transport data_o_p after 100 ns;
  data_i_n <= transport data_o_n after 100 ns;

  loopback_1 : entity work.loopback
    port map (
      clk33      => clk33,
      clock_i_p  => clock_i_p,
      clock_i_n  => clock_i_n,
      clock_o_p  => clock_o_p,
      clock_o_n  => clock_o_n,
      data_i_p   => data_i_p,
      data_i_n   => data_i_n,
      data_o_p   => data_o_p,
      data_o_n   => data_o_n
      );

end behavioral;
