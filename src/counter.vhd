library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
  generic(
    g_COUNTER_WIDTH  : integer := 32;
    g_ALLOW_ROLLOVER : boolean := false;
    g_INCREMENT_STEP : integer := 1
    );
  port(
    clock   : in  std_logic;
    reset_i : in  std_logic;
    en_i    : in  std_logic;
    count_o : out std_logic_vector(g_COUNTER_WIDTH - 1 downto 0)
    );
end counter;

architecture counter_arch of counter is

  signal en          : std_logic                              := '0';
  constant max_count : unsigned(g_COUNTER_WIDTH - 1 downto 0) := (others => '1');
  signal count       : unsigned(g_COUNTER_WIDTH - 1 downto 0);

begin

  process(clock)
  begin
    if rising_edge(clock) then

      -- io registers
      en      <= en_i;
      count_o <= std_logic_vector(count);

      --------------------------------------------------------------------------------
      -- Counter
      --------------------------------------------------------------------------------

      if en = '1' and (count /= max_count or g_ALLOW_ROLLOVER) then
        count <= count + g_INCREMENT_STEP;
      end if;

      --------------------------------------------------------------------------------
      -- Reset
      --------------------------------------------------------------------------------

      if reset_i = '1' then
        count_o <= (others => '0');
        count   <= (others => '0');
      end if;

    end if;
  end process;

end counter_arch;
