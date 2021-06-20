proc get_vio {} {
    return [get_hw_vios -of_objects [get_hw_devices xc7z020_1] -filter {CELL_NAME=~"vio"}]
}

proc get_probe {probe} {
    return [get_hw_probes $probe -of_objects [get_vio]]
}

proc init_vio {} {
    set_property INPUT_VALUE_RADIX UNSIGNED [get_probe rate_i]
    set_property INPUT_VALUE_RADIX UNSIGNED [get_probe rate_o]
    set_property INPUT_VALUE_RADIX UNSIGNED [get_probe bad_count_r]
    set_property INPUT_VALUE_RADIX UNSIGNED [get_probe total_count]
    set_property OUTPUT_VALUE_RADIX UNSIGNED [get_probe clock_tap_delay]
    set_property OUTPUT_VALUE_RADIX UNSIGNED [get_probe data_tap_delay]
}

proc set_clk_delay {delay} {
    set_prop clock_tap_delay $delay
}

proc set_data_delay {delay} {
    set_prop data_tap_delay $delay
}

proc reset_counters {} {
    set_prop count_reset_vio 1
    set_prop count_reset_vio 0
}

proc read_errs {} {
    return [read_prop bad_count_r]
}

proc read_frames {} {
    return [read_prop total_count]
}

proc read_rate_o {} {
    read_prop rate_o
}

proc read_rate_i {} {
    read_prop rate_i
}

proc set_prop {prop value} {
    set_property OUTPUT_VALUE $value [get_probe $prop]
    commit_hw_vio [get_probe $prop]
}

proc read_prop {prop} {
    get_property INPUT_VALUE [get_probe $prop]
}

proc read_bits {} {

    set errs [read_errs]
    set bits [expr 2*[read_frames]]

    if {$bits > 1000000000000} {
        set unit "Tb"
        set div 1000000000000.0
    } elseif {$bits > 1000000000} {
        set unit "Gb"
        set div 1000000000.0
    } else {
        set unit "Mb"
        set div 1000000.0
    }

    puts [format "%f %s (%d errors)" [expr $bits / $div] $unit $errs]
}

proc read_ber {} {
    set errs [read_errs]
    set frames [read_frames]

    if {$errs == 0} {
        set ber [format "<%e" [expr 1.0/(2.0*$frames)]]
        return $ber
    } else {
        set ber [format "%e" [expr $errs/(2.0*$frames)]]
        return $ber
    }
}

proc 1d_scan {func skip depth} {

    set err_array {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}

    puts "\n1D Scan:"

    for {set dly 0} {$dly < 32} {incr dly $skip} {

        eval "$func $dly"

        #reset counter
        reset_counters

        after $depth

        set errs [read_errs]
        set frames [read_frames]

        puts [format "   > dly=%2d errs=\[%d/%d\]" $dly $errs $frames]
    }
    set_data_delay 0
    set_clk_delay 0
}

proc 2d_scan {skip depth} {
    set err_array {
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
        {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
    }

    for {set clk_dly 0} {$clk_dly < 32} {incr clk_dly $skip} {

        set_clk_delay $clk_dly

        for {set data_dly 0} {$data_dly < 32} {incr data_dly $skip} {

            set_data_delay $data_dly

            #reset counter
            reset_counters

            after $depth

            set errs [read_errs]
            set frames [read_frames]

            puts [format "clock=%2d data=%2d errs=\[%d/%d\]" $clk_dly $data_dly $errs $frames]

            lset err_array $clk_dly $data_dly $errs
        }}

    puts "\n\n         data 0 ---> 31"
    for {set clk_dly 0} {$clk_dly < 32} {incr clk_dly $skip} {
        for {set data_dly 0} {$data_dly < 32} {incr data_dly $skip} {
            if {[expr $data_dly == 0] && [expr $clk_dly != 0]} {
                puts -nonewline "\n"
            }
            puts -nonewline "[lindex $err_array $clk_dly $data_dly] "
        }}
    puts "\n"
    set_data_delay 0
    set_clk_delay 0
}

2d_scan 12 1000
1d_scan "set_clk_delay" 4 2000
1d_scan "set_data_delay" 4 100
