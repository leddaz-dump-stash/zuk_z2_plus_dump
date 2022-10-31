#!/vendor/bin/sh

######################################################################
# 0              1    2      3           4         5           6           7       8            9
# batterylog.sh date uptime output_file dumper_en dumper_flag prop_length log_cnt record_count pause_time
######################################################################

VER=7

if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ] && [ -n "$5" ] && [ -n "$6" ] && [ -n "$7" ] && [ -n "$8" ] && [ -n "$9" ]; then
    bc_date="$1"
    bc_uptime="$2"
    out_file="$3"
    out_dumper="$3.qc"
    tmp_file="$3.tmp"
    dumper_en="$4"
    dumper_flag="$5"
    raw_prop_len="$6"
    log_cnt="$7"
    rec_cnt="$8"
    pause_time="$9"
else
    exit
fi

product=""
platform=""
tz_num=0
cpu_num=0
no_len=0
cpu_buf=""
total_module=7
local utime
local ktime

THERMAL_ZONE_PATH="/sys/devices/virtual/thermal"
CPU_PATH="/sys/devices/system/cpu/"
GPU_PATH="/sys/devices/soc/*.qcom,kgsl-3d0/kgsl/kgsl-3d0/gpuclk"
ADC_PATH="/sys/devices/soc/qpnp-vadc-*"
PROP_PRODUCT_NANME='ro.product.name'
PROP_PLATFORM='ro.board.platform'

get_product() {
    a=`getprop|grep ${PROP_PRODUCT_NANME}`
    b=`echo ${a##*\[}`
    product=`echo ${b%]*}`
}

get_platform() {
    a=`getprop|grep ${PROP_PLATFORM}`
    b=`echo ${a##*\[}`
    platform=`echo ${b%]*}`
}
get_product
get_platform

get_tz_max_num() {
    i=0
    for dir in $(ls ${THERMAL_ZONE_PATH})
    do
        if [[ "$product" == "jd2018" ]]; then
            if [[ "$dir" == "thermal_zone22" ]] || [[ "$dir" == "thermal_zone23" ]]; then
                continue
            fi
        fi
        if [[ "$dir" == "cooling_device"* ]] && [ -f ${THERMAL_ZONE_PATH}/"$dir/cur_state" ]; then
            let i=${i}+1
        fi
        if [[ "$dir" == "cooling_device"* ]] && [ -f ${THERMAL_ZONE_PATH}/"$dir/max_state" ]; then
            let i=${i}+1
        fi
        if [[ "$dir" == "thermal_zone"* ]]; then
            let i=${i}+1
        fi
    done
    tz_num=$i
}

get_cpu_max_num() {
    cpu_num=`cat ${CPU_PATH}/kernel_max`
    i=0
    cpu_buf=
    while true
    do
        if [ $i -gt $cpu_num ]; then
            break
        fi
        cpu_buf=${cpu_buf}",cpu${i}_max"
        let i=${i}+1
    done
    i=0
    while true
    do
        if [ $i -gt $cpu_num ]; then
            break
        fi
        cpu_buf=${cpu_buf}",cpu${i}_cur"
        let i=${i}+1
    done
}

get_tz_max_num
get_cpu_max_num

get_temp_prop() {
    local p1=
    local p2=
    for dir in $(ls ${THERMAL_ZONE_PATH})
    do
        if [[ "$product" == "jd2018" ]]; then
            if [[ "$dir" == "thermal_zone22" ]] || [[ "$dir" == "thermal_zone23" ]]; then
                continue
            fi
        fi
        if [[ "$dir" == "cooling_device"* ]] && [ -f ${THERMAL_ZONE_PATH}/"$dir/cur_state" ]; then
            p2+="${dir}_cur_state,"
        fi
        if [[ "$dir" == "cooling_device"* ]] && [ -f ${THERMAL_ZONE_PATH}/"$dir/max_state" ]; then
            p2+="${dir}_max_state,"
        fi
        if [[ "$dir" == "thermal_zone"* ]]; then
            p1+=" "${THERMAL_ZONE_PATH}/$dir/type
        fi
    done
    prop=`cat $p1 | tr '\n' ','`
    prop=`echo ${prop%,*}`
    prop=$p2$prop
}

get_temp_value() {
    local p1=
    for dir in $(ls ${THERMAL_ZONE_PATH})
    do
        if [[ "$product" == "jd2018" ]]; then
            if [[ "$dir" == "thermal_zone22" ]] || [[ "$dir" == "thermal_zone23" ]]; then
                continue
            fi
        fi
        if [[ "$dir" == "cooling_device"* ]] && [ -f ${THERMAL_ZONE_PATH}/"$dir/cur_state" ]; then
            p1+=" "${THERMAL_ZONE_PATH}/${dir}/cur_state
        fi
        if [[ "$dir" == "cooling_device"* ]] && [ -f ${THERMAL_ZONE_PATH}/"$dir/max_state" ]; then
            p1+=" "${THERMAL_ZONE_PATH}/${dir}/max_state
        fi
        if [[ "$dir" == "thermal_zone"* ]]; then
            p1+=" "${THERMAL_ZONE_PATH}/$dir/temp
        fi
    done
    value=`cat $p1 | tr '\n' ','`
    value=`echo ${value%,*}`
}

get_value_len() {
    local arr
    OLD_IFS="$IFS"
    IFS=$','
    arr=($value)
    echo ${#arr[@]}
    IFS=$OLD_IFS
}

get_freq_value() {
    local p1=
    local i=0
    echo 0 >$tmp_file

    if [ -f "${CPU_PATH}/online" ]; then
        p1+=" "${CPU_PATH}/online
    fi

    while [ $i -le ${cpu_num} ]
    do
        if [ -f "${CPU_PATH}/cpu$i/cpufreq/scaling_max_freq" ]; then
            p1+=" "${CPU_PATH}/cpu$i/cpufreq/scaling_max_freq
        else
            p1+=" "$tmp_file
        fi
        i=$(($i+1))
    done

    i=0
    while [ $i -le ${cpu_num} ]
    do
        if [ -f "${CPU_PATH}/cpu$i/cpufreq/scaling_cur_freq" ]; then
            p1+=" "${CPU_PATH}/cpu$i/cpufreq/scaling_cur_freq
        else
            p1+=" "$tmp_file
        fi
        i=$(($i+1))
    done
    p1+=" ""${GPU_PATH}"

    value=`cat $p1  | tr '\n' ','`
    value=`echo ${value%,*}`
    rm $tmp_file
}

get_usbin_value() {
    value=`cat ${ADC_PATH}/chg_temp ${ADC_PATH}/usb_dm ${ADC_PATH}/usb_dp ${ADC_PATH}/usbin | tr '\n' ',' | tr ' ' ',' |  tr ':' ',' | cut -d "," -f  2,6,10,14`","
    value=`echo ${value%,*}`
}

get_vph_pwr_value() {
    value=`cat ${ADC_PATH}/vph_pwr | tr '\n' ',' | tr ' ' ',' |  tr ':' ',' | cut -d "," -f  2,6,10,14`","
    value=`echo ${value%,*}`
}

get_ps_prop() {
    local a b arr i
    a=`cat $1`
    b=""
    OLD_IFS="$IFS"
    IFS=$'\n'
    arr=($a)
    for i in ${arr[@]}
    do
        c=${i%=*}
        b=$b"${c:13},"
    done
    IFS=$OLD_IFS
    prop=`echo $(echo $b | tr '[A-Z]' '[a-z]')`
    prop=`echo ${prop%,*}`
    IFS=$OLD_IFS
}

get_ps_value() {
    local a arr i
    a=`cat $1`
    value=""
    OLD_IFS="$IFS"
    IFS=$'\n'
    arr=($a)
    for i in ${arr[@]}
    do
        value=$value${i#*=}","
    done;
    IFS=$OLD_IFS
    value=`echo ${value%,*}`
}

get_new_prop() {
    local prop_arr raw_prop_arr i j
    OLD_IFS="$IFS"
    IFS=","
    prop_arr=($prop)
    raw_prop_arr=($raw_prop)
    IFS="$OLD_IFS"

    for i in ${prop_arr[@]}
    do
        raw_prop="$raw_prop"",$1""_$i"
    done
    return ${#prop_arr[@]}
}

get_virtual_value() {
    local v=
    local i=1
    while true
    do
        if [ $i -lt $1 ]; then
            v=",""$v"
            i=$(($i+1))
        else
            break
        fi
    done
    echo "$v"
}

dump_peripheral () {
    local base=$1
    local size=$2
    local dump_path=$3
    echo $base > $dump_path/address
    echo $size > $dump_path/count
    value=`cat $dump_path/data`
}

dump_smbchg_fg_regs () {
    echo $1 >$2
    value=`cat $2`
}

build_dumper_log() {
    if [ ! -s $out_dumper ] || [ ! -e $out_dumper ]; then
        qc_buf="Starting dumps! flag = $log_cnt""\n"
        qc_buf="$qc_buf""Dump path = $dump_path, pause time = $pause_time""\n"

        qc_buf="$qc_buf""Time is $bc_date""\n"
        qc_buf="$qc_buf""SRAM and SPMI Dump""\n"
        dump_smbchg_fg_regs 0 "/proc/fg_regs"
        qc_buf="$qc_buf""$value""\n"
        echo "$qc_buf" >$out_dumper
    fi

    qc_buf="Time is $bc_date""\n"
    if [ $dumper_flag -eq 1 ]; then
        qc_buf="$qc_buf""Charger Dump Started at $bc_uptime""\n"
        dump_smbchg_fg_regs 0 "/proc/smbchg_regs"
        qc_buf="$qc_buf""$value""\n"
        dump_smbchg_fg_regs 1 "/proc/smbchg_regs"
        qc_buf="$qc_buf""$value""\n"
        qc_buf="$qc_buf""Charger Dump done at $bc_uptime""\n"
        qc_buf="$qc_buf""FG Dump Started at $bc_uptime""\n"
        dump_smbchg_fg_regs 2 "/proc/smbchg_regs"
        qc_buf="$qc_buf""$value""\n"
        qc_buf="$qc_buf""FG Dump done at $bc_uptime""\n"
        qc_buf="$qc_buf""PS Capture Started at $bc_uptime""\n"
        qc_buf="$qc_buf"`cat /sys/class/power_supply/bms/uevent`"\n"
        qc_buf="$qc_buf"`cat /sys/class/power_supply/battery/uevent`"\n"
        qc_buf="$qc_buf""PS Capture done at $bc_uptime""\n"

        qc_buf="$qc_buf""SRAM Dump Started at $bc_uptime""\n"
        dump_smbchg_fg_regs 1 "/proc/fg_regs"
        qc_buf="$qc_buf""$value""\n"
        qc_buf="$qc_buf""SRAM Dump done at $bc_uptime""\n"
    else
        qc_buf="$qc_buf""SRAM Dump Started at $bc_uptime""\n"
        dump_smbchg_fg_regs 1 "/proc/fg_regs"
        qc_buf="$qc_buf""$value""\n"
        qc_buf="$qc_buf""SRAM Dump done at $bc_uptime""\n"
    fi
    echo "$qc_buf" >>$out_dumper
}

build_battery_log() {
    if [ ! -s $out_file ] || [ ! -e $out_file ]; then
        raw_prop="version,log_cnt,rec_cnt,platform,product,date,uptime"

        # battery
        get_ps_prop "/sys/class/power_supply/battery/uevent"
        get_new_prop "battery"
        ps_battery_len=$?
        raw_prop_len="$ps_battery_len"

        # bms
        get_ps_prop "/sys/class/power_supply/bms/uevent"
        get_new_prop "bms"
        ps_bms_len=$?
        raw_prop_len="$raw_prop_len"",$ps_bms_len"

        # usb
        get_ps_prop "/sys/class/power_supply/usb/uevent"
        get_new_prop "usb"
        ps_usb_len=$?
        raw_prop_len="$raw_prop_len"",$ps_usb_len"

        # cpu
        prop="online,${cpu_buf:1},gpu"
        get_new_prop "freq"
        freq_len=$?
        raw_prop_len="$raw_prop_len"",$freq_len"

        if [[ "$product" != "jd2018" ]]; then
            # usbin
            prop="chg_temp,usb_dm,usb_dp,usbin"
            get_new_prop "adc"
            usbin_len=$?
            raw_prop_len="$raw_prop_len"",$usbin_len"

            # vPhone_Power
            prop="vph_pwr"
            get_new_prop "adc"
            vph_pwr_len=$?
            raw_prop_len="$raw_prop_len"",$vph_pwr_len"
        else
            # usbin
            prop=""
            get_new_prop "adc"
            usbin_len=$?
            raw_prop_len="$raw_prop_len"",$usbin_len"

            # vPhone_Power
            prop=""
            get_new_prop "adc"
            vph_pwr_len=$?
            raw_prop_len="$raw_prop_len"",$vph_pwr_len"
        fi

        # Temp
        get_temp_prop
        get_new_prop "temp"
        temp_len=$?
        raw_prop_len="$raw_prop_len"",$temp_len"

        echo "$raw_prop" >$out_file
        raw_prop_len="$total_module,$raw_prop_len"
    else
        if [[ "$raw_prop_len" == "0" ]]; then
            no_len=1
        else
            OLD_IFS="$IFS"
            IFS=$','
            arr=($raw_prop_len)
            IFS=$OLD_IFS

            for i in ${arr[@]}
            do
                if [[ ${arr[i]} == *[!0-9]* ]]; then
                    no_len=1
                    break
                fi
            done

            if [ $no_len -eq 0 ]; then
                ((j = ${arr[@]} - 1))
                if [ $j -ne ${arr[0]} ] || [ $j -ne $total_module ]; then
                    no_len=1
                fi
            fi
        fi

        if [ $no_len -eq 0 ]; then
            ps_battery_len=${arr[1]}
            ps_bms_len=${arr[2]}
            ps_usb_len=${arr[3]}
            freq_len=${arr[4]}
            usbin_len=${arr[5]}
            vph_pwr_len=${arr[6]}
            temp_len=${arr[7]}
        fi
    fi

    raw_value="$VER,$log_cnt,$rec_cnt,${platform},${product},$bc_date,$bc_uptime"

    if [ $no_len -eq 1 ]; then
        echo $raw_value >>$out_file
        return
    fi

    get_ps_value "/sys/class/power_supply/battery/uevent"
    if [[ `get_value_len` -eq $ps_battery_len ]]; then
        raw_value="$raw_value"",$value"
    else
        raw_value="$raw_value"",`get_virtual_value $ps_battery_len`"
    fi

    get_ps_value "/sys/class/power_supply/bms/uevent"
    if [[ `get_value_len` -eq $ps_bms_len ]]; then
        raw_value="$raw_value"",$value"
    else
        raw_value="$raw_value"",`get_virtual_value $ps_bms_len`"
    fi

    get_ps_value "/sys/class/power_supply/usb/uevent"
    if [[ `get_value_len` -eq $ps_usb_len ]]; then
        raw_value="$raw_value"",$value"
    else
        raw_value="$raw_value"",`get_virtual_value $ps_usb_len`"
    fi

    get_freq_value
    if [[ `get_value_len` -eq $freq_len ]]; then
        raw_value="$raw_value"",$value"
    else
        raw_value="$raw_value"",`get_virtual_value $freq_len`"
    fi

    if [[ "$product" != "jd2018" ]]; then
        get_usbin_value
        if [[ `get_value_len` -eq $usbin_len ]]; then
            raw_value="$raw_value"",$value"
        else
            raw_value="$raw_value"",`get_virtual_value $usbin_len`"
        fi

        get_vph_pwr_value
        if [[ `get_value_len` -eq $vph_pwr_len ]]; then
            raw_value="$raw_value"",$value"
        else
            raw_value="$raw_value"",`get_virtual_value $vph_pwr_len`"
        fi
    fi

    get_temp_value
    if [[ `get_value_len` -eq $temp_len ]]; then
        raw_value="$raw_value"",$value"
    else
        raw_value="$raw_value"",`get_virtual_value $temp_len`"
    fi

    echo $raw_value >>$out_file
}

build_battery_log
if [[ $dumper_en -eq 1 ]]; then
    build_dumper_log
fi
echo "prop_len=[""$raw_prop_len""]=prop_len"

