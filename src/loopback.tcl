set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPPOWERDOWN ENABLE [current_design]
set_property BITSTREAM.CONFIG.USERID 32'h00000000 [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS 0000000 [current_design]

set_property PACKAGE_PIN Y6 [get_ports clk33]
set_property IOSTANDARD LVCMOS25 [get_ports clk33]
create_clock -period 30.00 -name sys_clk [get_ports clk33]

set_property IOSTANDARD LVDS_25 [get_ports {*_p}]
set_property IOSTANDARD LVDS_25 [get_ports {*_n}]

################################################################################
# CLOCK
################################################################################

# INPUT -----------------------------------------

set_property PACKAGE_PIN M19 [get_ports clock_i_p];
set_property PACKAGE_PIN M20 [get_ports clock_i_n];

# OUTPUT -----------------------------------------

set_property PACKAGE_PIN L17 [get_ports clock_o_p];
set_property PACKAGE_PIN M17 [get_ports clock_o_n];

################################################################################
# DATA
################################################################################

#-- INPUT -----------------------------------------
set_property PACKAGE_PIN M15 [get_ports data_i_p];
set_property PACKAGE_PIN M16 [get_ports data_i_n];

#-- OUTPUT -----------------------------------------
set_property PACKAGE_PIN N22 [get_ports data_o_p];
set_property PACKAGE_PIN P22 [get_ports data_o_n];

################################################################################
# Generated Clocks
################################################################################

# output clock
create_generated_clock -name clock_o [get_pins clock_wizard/inst/mmcm_adv_inst/CLKOUT0]

# Input Clock
set PERIOD [get_property PERIOD [get_clocks clock_o]]
create_clock -period $PERIOD -name clock_i [get_ports {clock_i_p}]


################################################################################
#  Outputs
#
#  Double Data Rate Source Synchronous Outputs
################################################################################

#  Source synchronous output interfaces can be constrained either by the max data skew
#  relative to the generated clock or by the destination device setup/hold requirements.
#
#  Max Skew Case:
#  The skew requirements for FPGA are known from system level analysis.
#
# forwarded                __________________________
# clock       ____________|                          |______________
#                         |                          |
#                 bre_skew|are_skew          bfe_skew|afe_skew
#                 <------>|<------>          <------>|<------>
#           ______        |        __________        |        ______
# data      ______XXXXXXXXXXXXXXXXX__________XXXXXXXXXXXXXXXXX______

create_generated_clock -name clock_oddr -source [get_pins clk_oddr/C] \
    -divide_by 1 [get_ports clock_o_p]

set fwclk            clock_oddr;          # forwarded clock name (generated using create_generated_clock at output clock port)
set fwclk_period     $PERIOD;             # forwarded clock period (full-period)
set bre_skew         0.5  ;               # skew requirement before rising edge
set are_skew         0.5  ;               # skew requirement after rising edge
set bfe_skew         0.5  ;               # skew requirement before falling edge
set afe_skew         0.5  ;               # skew requirement after falling edge
set output_ports     "data_o_p data_o_n"; # list of output ports

# -max is the required setup time of the receiving device
# -min is the negative of the required hold of the receiving device
#
# Want setup time to be PERIOD/2-<skew>
# - you want the new data valid <skew> ns after the previous edge,
# which is 2.5-0.3ns before the next edge.
# You want the hold to be -0.3ns - the data is allowed to change as early as
# 0.3ns before the clock edge.

# Output Delay Constraints
set_output_delay -clock $fwclk -max [expr $fwclk_period/2 - $afe_skew] [get_ports $output_ports];
set_output_delay -clock $fwclk -min $bre_skew                          [get_ports $output_ports];
set_output_delay -clock $fwclk -max [expr $fwclk_period/2 - $are_skew] [get_ports $output_ports] -clock_fall -add_delay;
set_output_delay -clock $fwclk -min $bfe_skew                          [get_ports $output_ports] -clock_fall -add_delay;

################################################################################
# Inputs
#
# Edge-Aligned Double Data Rate Source Synchronous Inputs
# (Using a direct FF connection)
################################################################################

# For an edge-aligned Source Synchronous interface, the clock
# transition occurs at the same time as the data transitions.
# In this template, the clock is aligned with the beginning of the
# data. The constraints below rely on the default timing
# analysis (setup = 1/2 cycle, hold = 0 cycle).
#
# input            _________________________________
# clock  _________|                                 |___________________________
#                 |                                 |
#         skew_bre|skew_are                 skew_bfe|skew_afe
#         <------>|<------>                 <------>|<------>
#        _        |        _________________        |        _________________
# data   _XXXXXXXXXXXXXXXXX____Rise_Data____XXXXXXXXXXXXXXXXX____Fall_Data____XX
#

set input_clock         clock_i;                # Name of input clock
set input_clock_period  $PERIOD;                # Period of input clock (full-period)
set skew_bre            0.5;                    # Data invalid before the rising clock edge
set skew_are            0.5;                    # Data invalid after the rising clock edge
set skew_bfe            0.5;                    # Data invalid before the falling clock edge
set skew_afe            0.5;                    # Data invalid after the falling clock edge
set input_ports         "data_i_p data_i_n";    # List of input ports

# Input Delay Constraint
set_input_delay -clock $input_clock -max [expr $input_clock_period/2 + $skew_afe] [get_ports $input_ports];
set_input_delay -clock $input_clock -min [expr $input_clock_period/2 - $skew_bfe] [get_ports $input_ports];
set_input_delay -clock $input_clock -max [expr $input_clock_period/2 + $skew_are] [get_ports $input_ports] -clock_fall -add_delay;
set_input_delay -clock $input_clock -min [expr $input_clock_period/2 - $skew_bre] [get_ports $input_ports] -clock_fall -add_delay;


################################################################################
# clock groups
################################################################################

set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks clock_i]
set_clock_groups -asynchronous -group [get_clocks clock_i] -group [get_clocks sys_clk]

set_false_path -from [get_clocks clock_i] -to [get_clocks -of_objects [get_pins clock_wizard/inst/mmcm_adv_inst/CLKOUT1]]

################################################################################
# reports
################################################################################

#report_timing -rise_from [get_ports $input_ports] -max_paths 20 -nworst 1 -delay_type min_max -name src_sync_edge_ddr_in_rise -file src_sync_edge_ddr_in_rise.txt;
#report_timing -fall_from [get_ports $input_ports] -max_paths 20 -nworst 1 -delay_type min_max -name src_sync_edge_ddr_in_fall -file src_sync_edge_ddr_in_fall.txt;
#
#report_timing -rise_to [get_ports $output_ports] -max_paths 20 -nworst 2 -delay_type min_max -name src_sync_ddr_out_rise -file src_sync_ddr_out_rise.txt;
#report_timing -fall_to [get_ports $output_ports] -max_paths 20 -nworst 2 -delay_type min_max -name src_sync_ddr_out_fall -file src_sync_ddr_out_fall.txt;
