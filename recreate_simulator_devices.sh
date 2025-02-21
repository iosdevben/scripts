#!/bin/zsh

iPhoneOldest="iPhone SE (3rd generation)"
iPhonePreviousPrevious="iPhone 14 Pro"
iPhonePreviousPreviousPlus="iPhone 14 Pro Max"
iPhonePrevious="iPhone 15 Pro"
iPhonePreviousPlus="iPhone 15 Pro Max"
iPhoneCurrent="iPhone 16 Pro"
iPhoneCurrentLargest="iPhone 16 Pro Max"

iPadOldest="iPad mini 4"
iPadPreviousPrevious="iPad mini (5th generation)"
iPadPrevious="iPad Air (5th generation)"
iPadMiniCurrent="iPad mini (A17 Pro)"
iPadCurrent="iPad Air 11-inch (M2)"
iPadCurrentLargest="iPad Air 13-inch (M2)"

oldestOS="15.5"
previousPreviousOS="16.4"
previousOS="17.5"
currentOSWorkaround="18.1"
currentOS="18.3.1"

runtimeString() { echo "com.apple.CoreSimulator.SimRuntime.iOS-${1//./-}"; }

# eg 15.5
oldestRuntime="$(runtimeString $oldestOS)"
# eg 16.4
previousPreviousRuntime="$(runtimeString $previousPreviousOS)"
# eg 17.6
previousRuntime="$(runtimeString $previousOS)"
# eg 18.1
currentRuntimeWorkaround="$(runtimeString $currentOSWorkaround)"
# eg 18.2
currentRuntime="$(runtimeString $currentOS)"

oldestDevices=( $iPhoneOldest $iPadOldest )
previousPreviousDevices=( $iPhonePreviousPrevious $iPadPreviousPrevious )
previousDevices=( $iPhonePrevious $iPadPrevious )
currentDevices=( $iPhoneCurrent $iPhoneCurrentLargest $iPadMiniCurrent $iPadCurrent $iPadCurrentLargest )
currentMinimumDevices=( $iPhoneCurrent $iPadCurrent )
allMinimumDevices=($oldestDevices $previousPreviousDevices $previousDevices $currentMinimumDevices)
allDevices=($oldestDevices $previousPreviousDevices $previousDevices $currentDevices)

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

create_current_workaround_devices() {
    debug_print $0

    if [[ "$1" == "min" ]]; then
        create_device "${currentMinimumDevices[@]}" "$currentRuntimeWorkaround"
    else
        create_device "${currentDevices[@]}" "$currentRuntimeWorkaround"
    fi
}

create_current_devices() {
    debug_print $0

    if [[ "$1" == "min" ]]; then
        create_device "${currentMinimumDevices[@]}" "$currentRuntime"
    else
        create_device "${currentDevices[@]}" "$currentRuntime"
    fi
}


create_devices() {
    debug_print $0

    scope=$2
    case $1 in
        o) create_oldest_devices;;
        2) create_previous_previous_devices;;
        1) create_previous_devices;;
        w) create_current_workaround_devices $scope;;
        0) create_current_devices $scope;;
        a) create_oldest_devices; create_previous_previous_devices; create_previous_devices; create_current_workaround_devices $scope; create_current_devices $scope;;
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

    local allSupportedOSVersions=($oldestOS $previousPreviousOS $previousOS $currentOSWorkaround $currentOS)

    echo "\nUsage: recreate_simulator_devices [[-o] [-2] [-1] [-0 min|all] [-w min|all]] | [-a min|all]"
    echo
    echo "Options:"
    echo   "  -h        Show this help message and exit"
    echo   "  -l        List devices"
    echo   "  -D        Enable debug messages"
    echo   "  -d        Delete all devices at the start"
    printf "  -o        Installs $oldestOS on %s\n" "${(j/, /)oldestDevices}"
    printf "  -2        Installs $previousPreviousOS on %s\n" "${(j/, /)previousPreviousDevices}"
    printf "  -1        Installs $previousOS on %s\n" "${(j/, /)previousDevices}"
    printf "  -w min    Installs $currentOSWorkaround on %s\n" "${(j/, /)currentMinimumDevices}"
    printf "  -w all    Installs $currentOSWorkaround on %s\n" "${(j/, /)currentDevices}"
    printf "  -0 min    Installs $currentOS on %s\n" "${(j/, /)currentMinimumDevices}"
    printf "  -0 all    Installs $currentOS on %s\n" "${(j/, /)currentDevices}"
    printf "  -a min    Installs %s on %s\n" "${(j/, /)allSupportedOSVersions}" "${(j/, /)allMinimumDevices}"
    printf "  -a max    Installs %s on %s\n" "${(j/, /)allSupportedOSVersions}" "${(j/, /)allMaximumDevices}"
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
for option in -D -h -l -d -a -o -2 -1 -w -0; do
    for arg in "$@"; do
        [[ "$arg" == "$option" || "$arg" == "$option"* ]] && reordered+="$arg"
    done
done

for arg in "$@"; do
    [[ "$arg" != -* ]] && reordered+="$arg"
done

while getopts ":lDdo21hw:0:a:" argument ${reordered[@]}; do
    case "$argument" in
            h) print_help; exit;;
            D) DEBUG_ENABLED=1;;
            l) list_devices; exit;;
            d) delete_all_devices;;
            a) create_devices $argument $OPTARG; exit;;
            o) create_devices $argument;;
            2) create_devices $argument;;
            1) create_devices $argument;;
            w) create_devices $argument $OPTARG;;
            0) create_devices $argument $OPTARG;;
            :) echo "\nError: Option -$OPTARG must be followed by min or max." >&2; print_help; exit 1;;
            ?) echo "\nError: unrecognised argument: -$OPTARG"; print_help; exit 1;;
            *) echo "WTF";;
    esac
done

list_devices

announce_completion&