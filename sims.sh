#!/bin/zsh

iPhoneOldest="iPhone 13 Pro"
iPhonePreviousPrevious="iPhone 14 Pro"
iPhonePrevious="iPhone 15 Pro"
iPhoneCurrent="iPhone 16 Pro"
iPhoneNext="iPhone 17 Pro"

iPhoneOldestLargest="iPhone 14 Pro Max"
iPhonePreviousLargest="iPhone 15 Pro Max"
iPhoneCurrentLargest="iPhone 16 Pro Max"
iPhoneNextLargest="iPhone 17 Pro Max"

iPadOldest="iPad Air (5th generation)"
iPadPreviousPrevious="iPad Air (4th generation)"
iPadPrevious="iPad Air (5th generation)"
iPadMiniCurrent="iPad mini (A17 Pro)"
iPadCurrent="iPad Air 11-inch (M2)"
iPadCurrentLargest="iPad Air 13-inch (M2)"
iPadNext="iPad Air 11-inch (M4)"
iPadNextLargest="iPad Air 13-inch (M4)"

oldestOS="16.4"
previousOS="17.5"
currentOS="18.6"
nextOS="26.4"

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
debug_print() {
    if [[ $DEBUG_ENABLED == 1 ]]; then
        echo $1
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

    scope=$2
    case $1 in
        o) create_oldest_devices;;
        2) create_previous_previous_devices;;
        1) create_previous_devices;;
        0) create_current_devices $scope;;
        n) create_next_devices $scope;;
        a) create_oldest_devices; create_previous_previous_devices; create_previous_devices; create_current_devices; create_next_devices $scope;;
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

    echo "\nUsage: recreate_simulator_devices [[-o] [-2] [-1] [-0 min|all] [-n min|all] | [-a min|all]"
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
    echo   "  -d all    Deletes all devices (or only branch-suffixed devices with -branch)"
    printf "  -o        Installs $oldestOS on %s\n" "${(j/, /)oldestDevices}"
    printf "  -1        Installs $previousOS on %s\n" "${(j/, /)previousDevices}"
    printf "  -0 min    Installs $currentOS on %s\n" "${(j/, /)currentMinimumDevices}"
    printf "  -0 all    Installs $currentOS on %s\n" "${(j/, /)currentDevices}"
    printf "  -n min    Installs $nextOS on %s\n" "${(j/, /)nextMinimumDevices}"
    printf "  -n all    Installs $nextOS on %s\n" "${(j/, /)nextDevices}"
    printf "  -a min    Installs %s on %s\n" "${(j/, /)allSupportedOSVersions}" "${(j/, /)allMinimumDevices}"
    printf "  -a max    Installs %s on %s\n" "${(j/, /)allSupportedOSVersions}" "${(j/, /)allDevices}"
    echo   "  -branch s Appends ' - s' to created simulator names (not supported with -a)"
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

    if [[ "$current_arg" == "-branch" ]]; then
        next_index=$((i + 1))
        if (( next_index > $# )); then
            echo "\nError: Option -branch requires an argument." >&2
            print_help
            exit 1
        fi

        next_arg="${@[next_index]}"
        if [[ "$next_arg" == -* ]]; then
            echo "\nError: Option -branch requires a non-option argument." >&2
            print_help
            exit 1
        fi

        SUFFIX="$next_arg"
        i=$next_index
        continue
    fi

    processed_args+=("$current_arg")
done

if [[ -n "$SUFFIX" ]]; then
    for arg in "${processed_args[@]}"; do
        if [[ "$arg" == "-a" ]]; then
            echo "\nError: -branch cannot be used with -a." >&2
            print_help
            exit 1
        fi
    done
fi

while getopts ":lDd:o21h0:n:a:" argument "${processed_args[@]}"; do
    case "$argument" in
            h) print_help; exit;;
            D) DEBUG_ENABLED=1;;
            l) list_devices; exit;;
            d) delete_devices $OPTARG;;
            a) create_devices $argument $OPTARG; exit;;
            o) create_devices $argument;;
            2) create_devices $argument;;
            1) create_devices $argument;;
            0) create_devices $argument $OPTARG;;
            n) create_devices $argument $OPTARG;;
            :) echo "\nError: Option -$OPTARG requires an argument." >&2; print_help; exit 1;;
            ?) echo "\nError: unrecognised argument: -$OPTARG"; print_help; exit 1;;
            *) echo "WTF";;
    esac
done

list_devices

announce_completion&