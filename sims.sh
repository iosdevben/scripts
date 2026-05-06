#!/bin/zsh

iPhoneOldest="iPhone 13 Pro"
iPhonePreviousPrevious="iPhone 14 Pro"
iPhonePrevious="iPhone 16 Pro"
iPhoneCurrent="iPhone 17 Pro"
iPhoneNext="iPhone 18 Pro"

iPhoneOldestLargest="iPhone 14 Pro Max"
iPhonePreviousLargest="iPhone 16 Pro Max"
iPhoneCurrentLargest="iPhone 17 Pro Max"
iPhoneNextLargest="iPhone 18 Pro Max"

iPadOldest="iPad Air (5th generation)"
iPadPreviousPrevious="iPad Air 11-inch (M3)"
iPadPrevious="iPad Air 11-inch (M3)"
iPadMiniCurrent="iPad mini (A17 Pro)"
iPadCurrent="iPad Air 11-inch (M3)"
iPadCurrentLargest="iPad Air 13-inch (M3)"
iPadNext="iPad Air 11-inch (M3)"
iPadNextLargest="iPad Air 13-inch (M3)"

oldestOS="17.5"
previousOS="18.6"
currentOS="26.2"
nextOS="27.0"

runtimeString() { echo "com.apple.CoreSimulator.SimRuntime.iOS-${1//./-}"; }

oldestRuntime="$(runtimeString $oldestOS)"
previousRuntime="$(runtimeString $previousOS)"
currentRuntime="$(runtimeString $currentOS)"
nextRuntime="$(runtimeString $nextOS)"

oldestDevices=( $iPhoneOldest $iPadOldest )
previousPreviousDevices=( $iPhonePreviousPrevious $iPadPreviousPrevious )
previousDevices=( $iPhonePrevious $iPadPrevious )
currentDevices=( $iPhoneCurrent $iPhoneCurrentLargest $iPadMiniCurrent $iPadCurrent $iPadCurrentLargest )
currentMinimumDevices=( $iPhoneCurrent $iPadCurrent )
nextDevices=( $iPhoneNext $iPhoneNextLargest $iPadNext $iPadNextLargest )
nextMinimumDevices=( $iPhoneNext $iPadNext )
allMinimumDevices=($oldestDevices $previousDevices $currentMinimumDevices $nextMinimumDevices)
allDevices=($oldestDevices $previousDevices $currentDevices $nextDevices)

DEBUG_ENABLED=0
SUFFIX=""
FORCE_ALL=0
debug_print() {
    if [[ $DEBUG_ENABLED == 1 ]]; then
        echo $1
    fi
}

runtime_exists() {
    xcrun simctl list runtimes | grep -Fq "$1"
}

require_runtime() {
    local runtime="$1"

    if ! runtime_exists "$runtime"; then
        echo "Error: runtime '$runtime' could not be found." >&2
        exit 1
    fi
}

install_certificate() {
    if [[ -e "$PROXYING_CERTIFICATE" ]]; then
        xcrun simctl boot $1
        xcrun simctl keychain $1 add-root-cert $PROXYING_CERTIFICATE
        xcrun simctl shutdown $1
    fi
}

create_device() {
    debug_print $0

    local parameters=("$@")
    let device_count=${#parameters[@]}-1
    local runtime=$parameters[-1]
    local devices=("${parameters[@]:0:$device_count}")

    require_runtime "$runtime"

    # arrays start at 1 in zsh
    for (( i=1; i<=$device_count; i++ ))
    do 
        local device="${devices[$i]}"
        local simulator_name="$device"
        if [[ -n "$SUFFIX" ]]; then
            simulator_name="$device - $SUFFIX"
        fi

        debug_print "Creating '$simulator_name' with '$runtime'"
        device_id=$(xcrun simctl create "$simulator_name" "$device" "$runtime")
        defaults write com.apple.dt.Xcode DVTDeviceVisibilityPreferences -dict-add $device_id -int 1
        install_certificate $device_id
    done
}

delete_newest_devices() {
    debug_print $0

    for device in "${nextDevices[@]}"; do
        local matched_device_name="$device"
        if [[ -n "$SUFFIX" ]]; then
            matched_device_name="$device - $SUFFIX"
        fi

        debug_print "$nextRuntime"
        xcrun simctl list devices "$device" | grep -F "$matched_device_name" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$matched_device_name' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_current_devices() {
    debug_print $0

    for device in "${currentDevices[@]}"; do
        local matched_device_name="$device"
        if [[ -n "$SUFFIX" ]]; then
            matched_device_name="$device - $SUFFIX"
        fi

        debug_print "$currentRuntime"
        xcrun simctl list devices "$device" | grep -F "$matched_device_name" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$matched_device_name' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_previous_devices() {
    debug_print $0

    for device in "${previousDevices[@]}"; do
        debug_print "$previousRuntime"
        xcrun simctl list devices "$device" | grep -F "$device" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$device' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_previous_previous_devices() {
    debug_print $0

    for device in "${previousPreviousDevices[@]}"; do
        debug_print "$previousPreviousRuntime"
        xcrun simctl list devices "$device" | grep -F "$device" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$device' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_oldest_devices() {
    debug_print $0

    for device in "${oldestDevices[@]}"; do
        debug_print "$oldestRuntime"
        xcrun simctl list devices "$device" | grep -F "$device" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$device' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_all_devices() {
    debug_print $0

    if [[ -z "$SUFFIX" ]]; then
        xcrun simctl delete all
        return
    fi

    local devices_for_all=("${oldestDevices[@]}" "${previousPreviousDevices[@]}" "${previousDevices[@]}" "${currentDevices[@]}" "${nextDevices[@]}")
    for device in "${devices_for_all[@]}"; do
        local matched_device_name="$device - $SUFFIX"
        xcrun simctl list devices "$device" | grep -F "$matched_device_name" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$matched_device_name' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_devices() {
    debug_print $0

    case $1 in
        n) delete_newest_devices;;
        0) delete_current_devices;;
        -1) delete_previous_devices;;
        -2) delete_previous_previous_devices;;
        o) delete_oldest_devices;;
        all) delete_all_devices;;
        *) echo "$1 unrecognised"; exit 1;;
    esac
}

create_oldest_devices() {
    debug_print $0

    create_device "${oldestDevices[@]}" "$oldestRuntime"
}

create_previous_previous_devices() {
    debug_print $0

    create_device "${previousPreviousDevices[@]}" "$previousPreviousRuntime"
}

create_previous_devices() {
    debug_print $0

    create_device "${previousDevices[@]}" "$previousRuntime"
}

create_current_devices() {
    debug_print $0

    if [[ "$1" == "min" ]]; then
        create_device "${currentMinimumDevices[@]}" "$currentRuntime"
    else
        create_device "${currentDevices[@]}" "$currentRuntime"
    fi
}

create_next_devices() {
    debug_print $0

    if [[ "$1" == "min" ]]; then
        create_device "${nextMinimumDevices[@]}" "$nextRuntime"
    else
        create_device "${nextDevices[@]}" "$nextRuntime"
    fi
}


create_devices() {
    debug_print $0

    local scope="min"
    if [[ "$FORCE_ALL" == 1 ]]; then
        scope="all"
    fi

    case $1 in
        o) create_oldest_devices;;
        2) create_previous_previous_devices;;
        1) create_previous_devices;;
        0) create_current_devices $scope;;
        n) create_next_devices $scope;;
        a) create_oldest_devices; create_previous_previous_devices; create_previous_devices; create_current_devices $scope; create_next_devices $scope;;
        *) echo "$1 unrecognised"; exit 1;;
    esac
}

list_devices() {
    debug_print $0

    xcrun simctl list devices
}

announce_completion() {
    debug_print $0

    afplay /System/Library/Sounds/Glass.aiff
}

print_help() {
    debug_print $0

    local allSupportedOSVersions=($oldestOS $previousOS $currentOS $nextOS)

    echo "\nUsage: sims.sh [[-o] [-2] [-1] [-0] [-n] | [-a]] [--all]"
    echo "\nSet \$PROXYING_CERTIFICATE to the location of the proxy root certificate if you want to automatically install one to each simulator"
    echo
    echo "Options:"
    echo   "  -h        Show this help message and exit"
    echo   "  -l        List devices"
    echo   "  -D        Enable debug messages"
    printf "  -d n      Deletes $nextOS devices: %s\n" "${(j/, /)nextDevices}"
    printf "  -d 0      Deletes $currentOS devices: %s\n" "${(j/, /)currentDevices}"
    printf "  -d -1     Deletes $previousOS devices: %s\n" "${(j/, /)previousDevices}"
    printf "  -d -2     Deletes $previousPreviousOS devices: %s\n" "${(j/, /)previousPreviousDevices}"
    printf "  -d o     Deletes $oldestOS devices: %s\n" "${(j/, /)oldestDevices}"
    echo   "  -d all    Deletes all devices (or only suffix-suffixed devices with -suffix)"
    printf "  -o        Installs $oldestOS on %s\n" "${(j/, /)oldestDevices}"
    printf "  -1        Installs $previousOS on %s\n" "${(j/, /)previousDevices}"
    printf "  -0        Installs $currentOS minimum on %s\n" "${(j/, /)currentMinimumDevices}"
    printf "  -n        Installs $nextOS minimum on %s\n" "${(j/, /)nextMinimumDevices}"
    printf "  -a        Installs %s on minimum set %s\n" "${(j/, /)allSupportedOSVersions}" "${(j/, /)allMinimumDevices}"
    echo   "  --all     For -0, -n, and -a, install full device sets (same behavior as old 'all'/'max' arguments)"
    echo   "  -suffix s Appends ' - s' to created simulator names (not supported with -a)"
}

print_help_if_no_arguments() {
    debug_print $0

    if [ $# -eq 0 ]; then
        echo "\nError: no arguments provided"
        print_help
        exit 1
    fi
}

#########################################################################
# script starts here
#########################################################################

print_help_if_no_arguments $1

processed_args=()
for (( i=1; i<=$#; i++ )); do
    current_arg="${@[i]}"

    if [[ "$current_arg" == "-suffix" ]]; then
        next_index=$((i + 1))
        if (( next_index > $# )); then
            echo "\nError: Option -suffix requires an argument." >&2
            print_help
            exit 1
        fi

        next_arg="${@[next_index]}"
        if [[ "$next_arg" == -* ]]; then
            echo "\nError: Option -suffix requires a non-option argument." >&2
            print_help
            exit 1
        fi

        SUFFIX="$next_arg"
        i=$next_index
        continue
    fi

    processed_args+=("$current_arg")
done

normalized_args=()
for (( i=1; i<=${#processed_args[@]}; i++ )); do
    current_arg="${processed_args[$i]}"

    if [[ "$current_arg" == "--all" ]]; then
        FORCE_ALL=1
        continue
    fi

    if [[ "$current_arg" == "-0" || "$current_arg" == "-n" || "$current_arg" == "-a" ]]; then
        normalized_args+=("$current_arg")

        next_index=$((i + 1))
        if (( next_index <= ${#processed_args[@]} )); then
            next_arg="${processed_args[$next_index]}"
            if [[ "$next_arg" == "min" || "$next_arg" == "all" || "$next_arg" == "max" ]]; then
                if [[ "$next_arg" == "all" || "$next_arg" == "max" ]]; then
                    FORCE_ALL=1
                fi
                i=$next_index
            fi
        fi
        continue
    fi

    normalized_args+=("$current_arg")
done

if [[ -n "$SUFFIX" ]]; then
    for arg in "${normalized_args[@]}"; do
        if [[ "$arg" == "-a" ]]; then
            echo "\nError: -suffix cannot be used with -a." >&2
            print_help
            exit 1
        fi
    done
fi

while getopts ":lDd:o21h0na" argument "${normalized_args[@]}"; do
    case "$argument" in
            h) print_help; exit;;
            D) DEBUG_ENABLED=1;;
            l) list_devices; exit;;
            d) delete_devices $OPTARG;;
            a) create_devices $argument; exit;;
            o) create_devices $argument;;
            2) create_devices $argument;;
            1) create_devices $argument;;
            0) create_devices $argument;;
            n) create_devices $argument;;
            :) echo "\nError: Option -$OPTARG requires an argument." >&2; print_help; exit 1;;
            ?) echo "\nError: unrecognised argument: -$OPTARG"; print_help; exit 1;;
            *) echo "WTF";;
    esac
done

list_devices

announce_completion&