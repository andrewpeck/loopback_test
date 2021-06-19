library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity loopback is
  generic (
    USE_IDELAY : boolean := true
    );
  port(

    clk33 : in std_logic;

    clock_i_p : in std_logic;
    clock_i_n : in std_logic;

    clock_o_p : out std_logic;
    clock_o_n : out std_logic;

    data_i_p : in std_logic;
    data_i_n : in std_logic;

    data_o_p : out std_logic;
    data_o_n : out std_logic

    );
end loopback;

architecture behavioral of loopback is

  -- clocks
  signal clk200                                          : std_logic := '0';
  signal clock_i, clock_idelay, clock_i_io, clock_ibufds : std_logic := '0';
  signal clock_oddr, clock_o                             : std_logic := '0';
  signal reset, locked                                   : std_logic := '0';
  signal ready                                           : std_logic := '0';

  -- data input
  signal data_idelay, data_ibufds        : std_logic                     := '0';
  signal data_i, data_i_r                : std_logic_vector (1 downto 0) := (others => '0');
  signal clock_tap_delay, data_tap_delay : std_logic_vector (4 downto 0) := (others => '0');

  -- place a keep on this, otherwise it merges into the odelay and changes the
  -- name for the vio
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of clock_tap_delay, data_tap_delay : signal is "true";

  -- data output
  signal data_o   : std_logic                     := '0';
  signal data_gen : std_logic_vector (1 downto 0) := (others => '0');

  -- prbs / monitoring
  signal inject_error, error_inject, error_inject_ff : std_logic := '0';
  signal prbs_locked                                 : std_logic := '0';
  signal prbs_error, prbs_error_r, not_prbs_error    : std_logic_vector (1 downto 0);

  signal count_reset, count_reset_vio : std_logic := '0';

  signal total_count            : std_logic_vector (47 downto 0) := (others => '0');
  signal bad_count, bad_count_r : std_logic_vector (15 downto 0) := (others => '0');

  -- frequency monitor
  signal rate_i, rate_o : std_logic_vector (31 downto 0) := (others => '0');

  -- components

  component clk_wiz_0
    port (
      -- Clock out ports
      clk_out1 : out std_logic;
      clk_out2 : out std_logic;
      -- Status and control signals
      reset    : in  std_logic;
      locked   : out std_logic;
      clk_in1  : in  std_logic
      );
  end component;

  component vio_0
    port (
      clk        : in  std_logic;
      probe_in0  : in  std_logic_vector (47 downto 0);
      probe_in1  : in  std_logic_vector (15 downto 0);
      probe_in2  : in  std_logic_vector (31 downto 0);
      probe_in3  : in  std_logic_vector (31 downto 0);
      probe_out0 : out std_logic_vector(0 downto 0);
      probe_out1 : out std_logic_vector(4 downto 0);
      probe_out2 : out std_logic_vector(4 downto 0);
      probe_out3 : out std_logic_vector(0 downto 0)
      );
  end component;

begin

  delayctrl_inst : IDELAYCTRL
    port map (
      RDY    => ready,
      REFCLK => clk200,
      RST    => not locked
      );

  reset <= not locked;

  --------------------------------------------------------------------------------
  -- system clock
  --------------------------------------------------------------------------------
  -- • always keep the 200mhz clock for the iodelay calibration
  -- • adjust clk_out1 frequency as needed for testing
  --    • Frequency should be HALF of the line rate requested,
  --      e.g. for 100Mbps choose a 50MHz clock since it is DDR
  -- • lock input is fixed at 100MHz
  --------------------------------------------------------------------------------

  clock_wizard : clk_wiz_0
    port map (
      -- Clock out ports
      clk_out1 => clock_o,
      clk_out2 => clk200,
      -- Status and control signals
      reset    => '0',
      locked   => locked,
      -- Clock in ports
      clk_in1  => clk33
      );

  --------------------------------------------------------------------------------
  -- PRBS-7 Data Generation
  --------------------------------------------------------------------------------

  prbs_any_gen : entity work.prbs_any
    generic map (
      chk_mode    => false,
      inv_pattern => false,
      poly_lenght => 7,
      poly_tap    => 6,
      nbits       => 2
      )
    port map (
      rst      => reset,
      clk      => clock_o,
      data_in  => (others => '0'),
      en       => '1',
      data_out => data_gen
      );

  --------------------------------------------------------------------------------
  -- Output Data
  --
  -- PRBS → ODDR → OBUFDS
  --------------------------------------------------------------------------------

  data_oddr : ODDR
    generic map (                          --
      DDR_CLK_EDGE => "SAME_EDGE",         -- "OPPOSITE_EDGE" or "SAME_EDGE"
      INIT         => '0',                 -- Initial value of Q: 1'b0 or 1'b1
      SRTYPE       => "SYNC"               -- Set/Reset type: "SYNC" or "ASYNC"
      )
    port map (
      Q  => data_o,                        -- 1-bit DDR output
      C  => clock_o,                       -- 1-bit clock input
      CE => '1',                           -- 1-bit clock enable input
      D1 => data_gen(0) xor inject_error,  -- 1-bit data input (positive edge)
      D2 => data_gen(1),                   -- 1-bit data input (negative edge)
      R  => '0',                           -- 1-bit reset
      S  => '0'                            -- 1-bit set
      );

  obufdata : OBUFDS
    port map (
      I  => data_o,
      O  => data_o_p,
      OB => data_o_n
      );

  --------------------------------------------------------------------------------
  -- Clock Output
  --
  -- Clock → ODDR → ODELAY → OBUFDS
  --------------------------------------------------------------------------------

  clk_oddr : ODDR
    generic map (                       --
      DDR_CLK_EDGE => "OPPOSITE_EDGE",  -- "OPPOSITE_EDGE" or "SAME_EDGE"
      INIT         => '0',              -- Initial value of Q: 1'b0 or 1'b1
      SRTYPE       => "SYNC"            -- Set/Reset type: "SYNC" or "ASYNC"
      )
    port map (
      Q  => clock_oddr,                 -- 1-bit DDR output
      C  => clock_o,                    -- 1-bit clock input
      CE => '1',                        -- 1-bit clock enable input
      D1 => '1',                        -- 1-bit data input (positive edge)
      D2 => '0',                        -- 1-bit data input (negative edge)
      R  => '0',                        -- 1-bit reset
      S  => '0'                         -- 1-bit set
      );

  obufclk : OBUFDS
    port map (
      I  => clock_oddr,
      O  => clock_o_p,
      OB => clock_o_n
      );

  --------------------------------------------------------------------------------
  -- RX Data
  --
  -- IBUFDS → IDELAY → IDDR
  --------------------------------------------------------------------------------

  ibufdata : IBUFDS
    generic map (                       --
      DIFF_TERM    => true,             -- Differential Termination
      IBUF_LOW_PWR => true              -- Low power="TRUE", Highest performance="FALSE"
      )
    port map (
      O  => data_ibufds,
      I  => data_i_p,
      IB => data_i_n
      );

  IDDR_data : IDDR
    generic map (
      DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",  -- IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
      INIT_Q1      => '0',                    -- Initial value of Q1: '0' or '1'
      INIT_Q2      => '0',                    -- Initial value of Q2: '0' or '1'
      SRTYPE       => "SYNC"                  -- Set/Reset type: "SYNC" or "ASYNC"
      )
    port map (
      Q1 => data_i(0),                        -- 1-bit output: Registered parallel output 1
      Q2 => data_i(1),                        -- 1-bit output: Registered parallel output 2
      C  => clock_i_io,                       -- 1-bit input: High-speed clock
      CE => '1',                              -- 1-bit input: Inversion of High-speed clock C
      D  => data_idelay,                      -- 1-bit input: Serial Data Input
      R  => '0',                              -- 1-bit input: Active-High Async Reset
      S  => '0'
      );

  --------------------------------------------------------------------------------
  -- RX Clock
  --
  -- IBUFGDS → BUFGCE
  --------------------------------------------------------------------------------

  ibufclock : IBUFGDS
    generic map (                       --
      DIFF_TERM    => true,             -- Differential Termination
      IBUF_LOW_PWR => false             -- Low power="TRUE", Highest performance="FALSE"
      )
    port map (
      O  => clock_ibufds,
      I  => clock_i_p,
      IB => clock_i_n
      );


  iclk_bufio_inst : BUFIO
    port map (
      O => clock_i_io,
      I => clock_idelay
      );

  iclk_bufg_inst : BUFG
    port map (
      O => clock_i,
      I => clock_idelay
      );

  --------------------------------------------------------------------------------
  -- Optional Input Delays
  --------------------------------------------------------------------------------

  nodelay : if (not USE_IDELAY) generate
    clock_idelay <= clock_ibufds;
    data_idelay  <= data_ibufds;
  end generate;

  yesdelay : if (USE_IDELAY) generate

    delaygen : for I in 0 to 1 generate

      function if_then_else (bool : boolean; a : string; b : string) return string is
      begin
        if (bool) then return a;
        else return b;
        end if;
      end if_then_else;

      signal s_in      : std_logic;
      signal s_out     : std_logic;
      signal taps      : std_logic_vector (4 downto 0);
      constant PATTERN : string := if_then_else (I = 0, "DATA", "CLOCK");

    begin

      dassign : if (I = 0) generate
        s_in        <= data_ibufds;
        taps        <= data_tap_delay;
        data_idelay <= s_out;
      end generate;

      cassign : if (I = 1) generate
        s_in         <= clock_ibufds;
        taps         <= clock_tap_delay;
        clock_idelay <= s_out;
      end generate;

      -- 78 ps per tap
      idelay_inst : idelaye2
        generic map (
          CINVCTRL_SEL          => "FALSE",     -- Enable dynamic clock inversion (FALSE, TRUE)
          DELAY_SRC             => "IDATAIN",   -- Delay input (IDATAIN, DATAIN)
          HIGH_PERFORMANCE_MODE => "FALSE",     -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
          IDELAY_TYPE           => "VAR_LOAD",  -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
          IDELAY_VALUE          => 0,           -- Input delay tap setting (0-31)
          PIPE_SEL              => "FALSE",     -- Select pipelined mode, FALSE, TRUE
          REFCLK_FREQUENCY      => 200.0,       -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
          SIGNAL_PATTERN        => PATTERN      -- DATA, CLOCK input signal
          )
        port map (
          CNTVALUEOUT => open,                  -- 5-bit output: Counter value output
          DATAOUT     => s_out,                 -- 1-bit output: Delayed data output
          C           => clk200,                -- 1-bit input: Clock input
          CE          => '0',                   -- 1-bit input: Active high enable increment/decrement input
          CINVCTRL    => '0',                   -- 1-bit input: Dynamic clock inversion input
          CNTVALUEIN  => taps,                  -- 5-bit input: Counter value input
          DATAIN      => '0',                   -- 1-bit input: Internal delay data input
          IDATAIN     => s_in,                  -- 1-bit input: Data input from the I/O
          INC         => '0',                   -- 1-bit input: Increment / Decrement tap delay input
          LD          => '1',                   -- 1-bit input: Load IDELAY_VALUE input
          LDPIPEEN    => '0',                   -- 1-bit input: Enable PIPELINE register to load data input
          REGRST      => '1'                    -- 1-bit input: Active-high reset tap-delay input
          );
    end generate;

  end generate;

  --------------------------------------------------------------------------------
  -- PRBS-7 Checking
  --------------------------------------------------------------------------------

  prbs_any_check : entity work.prbs_any
    generic map (
      chk_mode    => true,
      inv_pattern => false,
      poly_lenght => 7,
      poly_tap    => 6,
      nbits       => 2
      )
    port map (
      rst      => reset,
      clk      => clock_i,
      data_in  => data_i_r,
      en       => '1',
      data_out => prbs_error
      );

  process (clock_i) is
  begin
    if (rising_edge(clock_i)) then
      error_inject_ff <= error_inject;
    end if;
  end process;

  inject_error <= '1' when error_inject_ff = '0' and error_inject = '1';

  -- only start checking once the prbs has locked onto the datastream
  -- ... it takes some time when looking 1 bit at a time to figure out the pattern
  process (clock_i) is
  begin
    if (rising_edge(clock_i)) then
      if (locked = '0') then
        prbs_locked <= '0';
      elsif (prbs_locked = '0' and prbs_error = "00") then
        prbs_locked <= '1';
      end if;
    end if;
  end process;

  -- registers for timing
  process (clock_i) is
  begin
    if (rising_edge(clock_i)) then
      data_i_r       <= data_i;
      count_reset    <= count_reset_vio or not (locked and prbs_locked);
      prbs_error_r   <= prbs_error;
      not_prbs_error <= not prbs_error;
      bad_count_r    <= bad_count;
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- Counters
  --------------------------------------------------------------------------------

  counter_good : entity work.counter
    generic map (
      g_COUNTER_WIDTH  => total_count'length,
      g_INCREMENT_STEP => 1
      )
    port map (
      clock   => clock_i,
      reset_i => count_reset,
      en_i    => '1',
      count_o => total_count
      );

  -- make this counter smaller for speed
  counter_bad : entity work.counter
    generic map (
      g_COUNTER_WIDTH => bad_count'length
      )
    port map (
      clock   => clock_i,
      reset_i => count_reset,
      en_i    => or_reduce(prbs_error_r),
      count_o => bad_count
      );

  --------------------------------------------------------------------------------
  -- VIO
  --------------------------------------------------------------------------------

  vio : vio_0
    port map (
      clk           => clock_i,
      probe_in0     => total_count,
      probe_in1     => bad_count_r,
      probe_in2     => rate_i,
      probe_in3     => rate_o,
      probe_out0(0) => count_reset_vio,
      probe_out1    => data_tap_delay,
      probe_out2    => clock_tap_delay,
      probe_out3(0) => error_inject
      );

  --------------------------------------------------------------------------------
  -- Frequency monitor
  --------------------------------------------------------------------------------

  frequency_counter_i_inst : entity work.frequency_counter
    generic map (clk_a_freq => 33333333)
    port map (
      reset => locked,
      clk_a => clk33,
      clk_b => clock_i,
      rate  => rate_i
      );

  frequency_counter_o_inst : entity work.frequency_counter
    generic map (clk_a_freq => 33333333)
    port map (
      reset => locked,
      clk_a => clk33,
      clk_b => clock_o,
      rate  => rate_o
      );

end behavioral;
