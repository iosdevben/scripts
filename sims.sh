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
        debug_print "Creating '$device' with '$runtime'"
        device_id=$(xcrun simctl create "$device" "$device" "$runtime")
        defaults write com.apple.dt.Xcode DVTDeviceVisibilityPreferences -dict-add $device_id -int 1
        install_certificate $device_id
    done
}

delete_all_devices() {
    debug_print $0

    xcrun simctl delete all
}

delete_newest_devices() {
    debug_print $0

    for device in "${nextDevices[@]}"; do
        debug_print "$nextRuntime"
        xcrun simctl list devices "$device" | grep -F "$device" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$device' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_devices() {
    debug_print $0

    case $1 in
        n) delete_newest_devices;;
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

    echo "\nUsage: recreate_simulator_devices [[-o] [-2] [-1] [-0 min|all] [-n min|all] [-w min|all]] | [-a min|all]"
    echo "\nSet \$PROXYING_CERTIFICATE to the location of the proxy root certificate if you want to automatically install one to each simulator"
    echo
    echo "Options:"
    echo   "  -h        Show this help message and exit"
    echo   "  -l        List devices"
    echo   "  -D        Enable debug messages"
    printf "  -d n      Deletes $nextOS devices: %s\n" "${(j/, /)nextDevices}"
    echo   "  -d all    Deletes all devices"
    printf "  -o        Installs $oldestOS on %s\n" "${(j/, /)oldestDevices}"
    printf "  -1        Installs $previousOS on %s\n" "${(j/, /)previousDevices}"
    printf "  -0 min    Installs $currentOS on %s\n" "${(j/, /)currentMinimumDevices}"
    printf "  -0 all    Installs $currentOS on %s\n" "${(j/, /)currentDevices}"
    printf "  -n min    Installs $nextOS on %s\n" "${(j/, /)nextMinimumDevices}"
    printf "  -n all    Installs $nextOS on %s\n" "${(j/, /)nextDevices}"
    printf "  -a min    Installs %s on %s\n" "${(j/, /)allSupportedOSVersions}" "${(j/, /)allMinimumDevices}"
    printf "  -a max    Installs %s on %s\n" "${(j/, /)allSupportedOSVersions}" "${(j/, /)allDevices}"
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

reordered=()
for option in -D -h -l -d -a -o -2 -1 -w -0 -n; do
    for arg in "$@"; do
        [[ "$arg" == "$option" || "$arg" == "$option"* ]] && reordered+="$arg"
    done
done

for arg in "$@"; do
    [[ "$arg" != -* ]] && reordered+="$arg"
done

while getopts ":lDd:o21hw:0:n:a:" argument ${reordered[@]}; do
    case "$argument" in
            h) print_help; exit;;
            D) DEBUG_ENABLED=1;;
            l) list_devices; exit;;
            d) delete_devices $OPTARG;;
            a) create_devices $argument $OPTARG; exit;;
            o) create_devices $argument;;
            2) create_devices $argument;;
            1) create_devices $argument;;
            w) create_devices $argument $OPTARG;;
            0) create_devices $argument $OPTARG;;
            n) create_devices $argument;;
            :) echo "\nError: Option -$OPTARG requires an argument." >&2; print_help; exit 1;;
            ?) echo "\nError: unrecognised argument: -$OPTARG"; print_help; exit 1;;
            *) echo "WTF";;
    esac
done

list_devices

announce_completion&