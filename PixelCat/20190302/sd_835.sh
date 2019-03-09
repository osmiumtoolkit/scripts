#!/system/bin/sh
# powercfg template by cjybyjk & yc9559
# License: GPL V3

project_name="橘猫调度"
prj_ver="(prj_ver)"
project_author="橘猫520 @ coolapk"
soc_model="sd_835"
generate_date="Sat Mar  2 02:05:57 CST 2019"

is_big_little="true"

DEBUG_FLAG="false"

C0_GOVERNOR_DIR="/sys/devices/system/cpu/cpu0/cpufreq/interactive"
C1_GOVERNOR_DIR="/sys/devices/system/cpu/cpu4/cpufreq/interactive"
C0_CPUFREQ_DIR="/sys/devices/system/cpu/cpu0/cpufreq"
C1_CPUFREQ_DIR="/sys/devices/system/cpu/cpu4/cpufreq"
C0_CORECTL_DIR="/sys/devices/system/cpu/cpu0/core_ctl"
C1_CORECTL_DIR="/sys/devices/system/cpu/cpu4/core_ctl"

if ! $is_big_little ; then
	C0_GOVERNOR_DIR="/sys/devices/system/cpu/cpufreq/interactive"
fi

# $1:timer_rate $2:value
function set_param_little() 
{
	$DEBUG_FLAG && echo "little: set ${1} into ${2}"
	echo ${2} > ${C0_GOVERNOR_DIR}/${1}
}

function set_param_big() 
{
	$DEBUG_FLAG && echo "big: set ${1} into ${2}"
	echo ${2} > ${C1_GOVERNOR_DIR}/${1}
}

function set_param_all() 
{
	set_param_little ${1} "${2}"
	$is_big_little && set_param_big ${1} "${2}"
}

function set_param_HMP()
{
	$DEBUG_FLAG && echo "HMP: set ${1} into ${2}"
	echo ${2} > /proc/sys/kernel/${1}
}

# $1:timer_rate
function print_param() 
{
	if $is_big_little ; then
		print_value "LITTLE: ${1}" ${C0_GOVERNOR_DIR}/${1}
		print_value "big: ${1}" ${C1_GOVERNOR_DIR}/${1}
	else
		print_value "${1}" ${C0_GOVERNOR_DIR}/${1}
	fi
}

function before_modify()
{
	# disable hotplug to switch governor
	set_value 0 /sys/module/msm_thermal/core_control/enabled
	set_value N /sys/module/msm_thermal/parameters/enabled
	# Exynos hotplug
	lock_value 0 /sys/power/cpuhotplug/enabled
	lock_value 0 /sys/devices/system/cpu/cpuhotplug/enabled
	lock_value "interactive" ${C0_CPUFREQ_DIR}/scaling_governor
	chown 0.0 ${C0_GOVERNOR_DIR}/*
	chmod 0666 ${C0_GOVERNOR_DIR}/*
	if $is_big_little ; then
		lock_value "interactive" ${C1_CPUFREQ_DIR}/scaling_governor
		chown 0.0 ${C1_GOVERNOR_DIR}/*
		chmod 0666 ${C1_GOVERNOR_DIR}/*
	fi
	# before_modify_params
}

function after_modify()
{
	chmod 0444 ${C0_GOVERNOR_DIR}/*
	$is_big_little && chmod 0444 ${C1_GOVERNOR_DIR}/*
	# after_modify_params
	verify_param
}

# $1:value $2:file path
function set_value() 
{
	if [ -f $2 ]; then
		$DEBUG_FLAG && echo "set ${2} into ${1}"
		echo $1 > $2
	fi
}

# $1:value $2:file path
function lock_value()
{
	if [ -f $2 ]; then
		# chown 0.0 $2
		chmod 0666 $2
		echo $1 > $2
		chmod 0444 $2
		$DEBUG_FLAG && echo "lock ${2} into ${1}"
	fi                                                  
}

# $1:display-name $2:file path
function print_value() 
{
	if [ -f $2 ]; then
		echo -n "$1: "
		cat $2
	fi
}

function verify_param() 
{
	expected_target=${C0_GOVERNOR_DIR}/target_loads
	if [ "$action" = "powersave" ]; then
		expected_value="55 364000:44 748000:55 1036000:62 1324000:74 1670000:82 1900000:93"
	elif [ "$action" = "balance" ]; then
		expected_value="60 300000:14 364000:19 441000:22 518000:24 672000:27 748000:31 883000:35 960000:37 1036000:41 1171000:44 1324000:49 1555000:57 1670000:63 1747000:67 1824000:72 1900000:78"
	elif [ "$action" = "performance" ]; then
		expected_value="40 364000:19 748000:31 1036000:39 1324000:49 1670000:57 1900000:68"
	elif [ "$action" = "fast" ]; then
		expected_value="(fast_tload)"
	fi
	if [ "`cat ${expected_target}`" = "${expected_value}" ]; then
		echo "${action} OK"
	elif [ "${expected_value}" = "(${action}_tload)" ]; then
		echo "${action} not included"
	else
		echo "${action} FAIL"
	fi
}

function get_mode()
{
    expected_target=${C0_GOVERNOR_DIR}/target_loads
	case "`cat ${expected_target}`" in
		"55 364000:44 748000:55 1036000:62 1324000:74 1670000:82 1900000:93" ) echo "powersave OK" ;;
		"60 300000:14 364000:19 441000:22 518000:24 672000:27 748000:31 883000:35 960000:37 1036000:41 1171000:44 1324000:49 1555000:57 1670000:63 1747000:67 1824000:72 1900000:78" ) echo "balance OK" ;;
		"40 364000:19 748000:31 1036000:39 1324000:49 1670000:57 1900000:68" ) echo "performance OK" ;;
		"(fast_tload)" ) echo "fast OK" ;;
	esac
}

# RunOnce
if [ ! -f /dev/perf_runonce ]; then
	# set flag
	touch /dev/perf_runonce
	
	# HMP_params
	# runonce_params
fi

action=$1
if [ ! -n "$action" ]; then
    action="balance"
fi

# wake up clusters
if $is_big_little; then
	if [ -f "$C0_CORECTL_DIR/min_cpus" ]; then
		C0_CORECTL_MINCPUS=`cat $C0_CORECTL_DIR/min_cpus`
		cat $C0_CORECTL_DIR/max_cpus > $C0_CORECTL_DIR/min_cpus
	fi
	if [ -f "$C1_CORECTL_DIR/min_cpus" ]; then
		C1_CORECTL_MINCPUS=`cat $C1_CORECTL_DIR/min_cpus`
		cat $C1_CORECTL_DIR/max_cpus > $C1_CORECTL_DIR/min_cpus
	fi
	set_value 1 /sys/devices/system/cpu/cpu0/online
	set_value 1 /sys/devices/system/cpu/cpu4/online
fi

if [ "$action" = "debug" ]; then
	echo "$project_name"
	echo "Version: $prj_ver"
	echo "Author: $project_author"
	echo "Platform: $soc_model"
	echo "Generated at $generate_date"
	echo ""
	print_param above_hispeed_delay
	print_param target_loads
	get_mode
else
	before_modify
	if [ "$action" = "powersave" ]; then
		echo "applying powersave"
		set_param_all boostpulse_duration 25000
		set_param_all boost 1
		set_param_all timer_rate 24000
		set_param_all timer_slack 90000
		set_param_all min_sample_time 1000
		set_param_all align_windows 0
		set_param_all max_freq_hysteresis 1000
		set_param_all use_sched_load 1
		set_param_all use_migration_notif 1
		set_param_all go_hispeed_load 70
		set_param_all hispeed_freq "652000 364000"
		set_param_big above_hispeed_delay "12000 652000:49000 979000:63000 1267000:71000 1651000:82000 2035000:91000 2323000:104000 2457000:123000"
		set_param_little above_hispeed_delay "12000 364000:45000 748000:56000 1036000:68000 1324000:71000 1670000:86000 1900000:97000"
		set_param_big target_loads "55 652000:42 979000:47 1267000:62 1651000:73 2035000:81 2323000:94 2457000:100"
		set_param_little target_loads "55 364000:44 748000:55 1036000:62 1324000:74 1670000:82 1900000:93"

	elif [ "$action" = "balance" ]; then
		echo "applying balance"
		set_param_all boostpulse_duration 15000
		set_param_all boost 1
		set_param_all timer_rate 20000
		set_param_all timer_slack 140000
		set_param_all min_sample_time 3000
		set_param_all align_windows 0
		set_param_all max_freq_hysteresis 38000
		set_param_all enable_prediction 0
		set_param_all io_is_busy 0
		set_param_all ignore_hispeed_on_notif 0
		set_param_all use_sched_load 0
		set_param_all use_migration_notif 0
		set_param_big go_hispeed_load 48
		set_param_little go_hispeed_load 31
		set_param_big hispeed_freq 1267000
		set_param_little hispeed_freq 748000
		set_param_big above_hispeed_delay "15000 1651000:15000"
		set_param_little above_hispeed_delay "15000 1171000:17000"
		set_param_big target_loads "85 300000:15 345000:18 499000:21 576000:25 652000:27 729000:29 806000:31 902000:35 979000:39 1056000:41 1132000:43 1267000:48 1651000:63 1804000:69 1881000:73 2035000:79 2112000:83 2208000:88 2323000:92 2457000:96"
		set_param_little target_loads "60 300000:14 364000:19 441000:22 518000:24 672000:27 748000:31 883000:35 960000:37 1036000:41 1171000:44 1324000:49 1555000:57 1670000:63 1747000:67 1824000:72 1900000:78"

	elif [ "$action" = "performance" ]; then
		echo "applying performance"
		set_param_all boostpulse_duration 7000
		set_param_all boost 1
		set_param_all timer_rate 10000
		set_param_all timer_slack 40000
		set_param_all min_sample_time 1000
		set_param_all align_windows 0
		set_param_all max_freq_hysteresis 1000
		set_param_all use_sched_load 1
		set_param_all use_migration_notif 1
		set_param_all go_hispeed_load 40
		set_param_all hispeed_freq "1400000 960000"
		set_param_big above_hispeed_delay "7000 652000:17000 979000:35000 1267000:41000 1651000:47000 2035000:54000 2323000:75000 2457000:84000"
		set_param_little above_hispeed_delay "7000 364000:19000 748000:29000 1036000:37000 1324000:49000 1670000:57000 1900000:69000"
		set_param_big target_loads "40 652000:27 979000:39 1267000 48 1651000:53 2035000:67 2323000:75 2457000:81"
		set_param_little target_loads "40 364000:19 748000:31 1036000:39 1324000:49 1670000:57 1900000:68"

	elif [ "$action" = "fast" ]; then
		echo "applying fast"
		:
	fi
	after_modify
fi

if $is_big_little; then
	set_value $C0_CORECTL_MINCPUS $C0_CORECTL_DIR/min_cpus
	set_value $C1_CORECTL_MINCPUS $C1_CORECTL_DIR/min_cpus
fi

exit 0
