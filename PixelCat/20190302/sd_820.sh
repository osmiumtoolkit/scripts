#!/system/bin/sh
# powercfg template by cjybyjk & yc9559
# License: GPL V3

project_name="橘猫调度"
prj_ver="(prj_ver)"
project_author="橘猫520 @ coolapk"
soc_model="sd_820"
generate_date="Sat Mar  2 02:05:30 CST 2019"

is_big_little="true"

DEBUG_FLAG="false"

C0_GOVERNOR_DIR="/sys/devices/system/cpu/cpu0/cpufreq/interactive"
C1_GOVERNOR_DIR="/sys/devices/system/cpu/cpu2/cpufreq/interactive"
C0_CPUFREQ_DIR="/sys/devices/system/cpu/cpu0/cpufreq"
C1_CPUFREQ_DIR="/sys/devices/system/cpu/cpu2/cpufreq"
C0_CORECTL_DIR="/sys/devices/system/cpu/cpu0/core_ctl"
C1_CORECTL_DIR="/sys/devices/system/cpu/cpu2/core_ctl"

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
		expected_value="70 480000:41 844000:56 1228000:67 1593000:74"
	elif [ "$action" = "balance" ]; then
		expected_value="60 307000:14 422000:19 652000:22 729000:24 844000:27 960000:31 1036000:35 1113000:37 1190000:41 1228000:44 1324000:54 1401000:61 1478000:73 1593000:79"
	elif [ "$action" = "performance" ]; then
		expected_value="40 480000:23 844000:31 1228000:37 1593000:49"
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
		"70 480000:41 844000:56 1228000:67 1593000:74" ) echo "powersave OK" ;;
		"60 307000:14 422000:19 652000:22 729000:24 844000:27 960000:31 1036000:35 1113000:37 1190000:41 1228000:44 1324000:54 1401000:61 1478000:73 1593000:79" ) echo "balance OK" ;;
		"40 480000:23 844000:31 1228000:37 1593000:49" ) echo "performance OK" ;;
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
	set_value 1 /sys/devices/system/cpu/cpu2/online
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
		set_param_big hispeed_freq 652000
		set_param_little hispeed_freq 307000
		set_param_big above_hispeed_delay "25000 307000:37000 652000:49000 1248000:63000 1555000:78000 1920000:89000 2150000:99000"
		set_param_little above_hispeed_delay "25000 480000:39000 844000:43000 1228000:57000 1593000:69000"
		set_param_big target_loads "70 307000:41 652000:53 1248000:41 1555000:69 1920000:78 2150000:84"
		set_param_little target_loads "70 480000:41 844000:56 1228000:67 1593000:74"

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
		set_param_big go_hispeed_load 31
		set_param_little go_hispeed_load 31
		set_param_big hispeed_freq 1036000
		set_param_little hispeed_freq 729000
		set_param_big above_hispeed_delay "15000 1785600:15000"
		set_param_little above_hispeed_delay "15000 1113600:17000"
		set_param_big target_loads "85 307000:15 403000:18 652000:21 729000:25 883000:27 940000:29 1036000:31 1190000:35 1248000:39 1324000:41 1401000:44 1478000:48 1555000:52 1785000:63 1824000:69 1920000:73 1996000:79 2073000:83 2150000:88"
		set_param_little target_loads "60 307000:14 422000:19 652000:22 729000:24 844000:27 960000:31 1036000:35 1113000:37 1190000:41 1228000:44 1324000:54 1401000:61 1478000:73 1593000:79"

	elif [ "$action" = "performance" ]; then
		echo "applying performance"
		set_param_all timer_rate 10000
		set_param_all timer_slack 40000
		set_param_all min_sample_time 1000
		set_param_all align_windows 0
		set_param_all max_freq_hysteresis 1000
		set_param_all use_sched_load 1
		set_param_all use_migration_notif 1
		set_param_all go_hispeed_load 40
		set_param_big hispeed_freq 1401000
		set_param_little hispeed_freq 940000
		set_param_big above_hispeed_delay "7000 307000:13000 652000:24000 1248000:47000 1555000:54000 1920000:64000 2150000:73000"
		set_param_little above_hispeed_delay "7000 480000:17000 844000:27000 1228000:35000 1593000:49000"
		set_param_big target_loads "40 307000:21 652000:35 1248000:411516000:53 1920000:61 2150000:69"
		set_param_little target_loads "40 480000:23 844000:31 1228000:37 1593000:49"

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
