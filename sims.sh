#!/bin/zsh

iPhoneOldest="iPhone 13 Pro"
iPhonePrevious="iPhone 16 Pro"
iPhoneCurrent="iPhone 17 Pro"
iPhoneNext="iPhone 18 Pro"

iPhoneOldestLargest="iPhone 14 Pro Max"
iPhonePreviousLargest="iPhone 16 Pro Max"
iPhoneCurrentLargest="iPhone 17 Pro Max"
iPhoneNextLargest="iPhone 18 Pro Max"

iPadOldest="iPad Air (5th generation)"
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
previousDevices=( $iPhonePrevious $iPadPrevious )
currentDevices=( $iPhoneCurrent $iPhoneCurrentLargest $iPadMiniCurrent $iPadCurrent $iPadCurrentLargest )
currentMinimumDevices=( $iPhoneCurrent $iPadCurrent )
# currentMinimumDevices=( $iPhoneCurrent )
# currentMinimumDevices=( $iPadCurrent )
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
        xcrun simctl list devices "$device" | grep -F "$matched_device_name (" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
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
        xcrun simctl list devices "$device" | grep -F "$matched_device_name (" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
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

    local devices_for_all=("${oldestDevices[@]}" "${previousDevices[@]}" "${currentDevices[@]}" "${nextDevices[@]}")
    for device in "${devices_for_all[@]}"; do
        local matched_device_name="$device - $SUFFIX"
        xcrun simctl list devices "$device" | grep -F "$matched_device_name (" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | while IFS= read -r udid; do
            debug_print "Deleting '$matched_device_name' with udid '$udid'"
            xcrun simctl delete "$udid"
        done
    done
}

delete_devices() {
    debug_print $0

    case $1 in
        n) delete_newest_devices;;
        c) delete_current_devices;;
        p) delete_previous_devices;;
        o) delete_oldest_devices;;
        all|--all) delete_all_devices;;
        *) echo "$1 unrecognised"; exit 1;;
    esac
}

create_oldest_devices() {
    debug_print $0

    create_device "${oldestDevices[@]}" "$oldestRuntime"
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
        p) create_previous_devices;;
        c) create_current_devices $scope;;
        n) create_next_devices $scope;;
        *) echo "$1 unrecognised"; exit 1;;
    esac
}

list_devices() {
    debug_print $0

    xcrun simctl list devices available
}

announce_completion() {
    debug_print $0

    afplay /System/Library/Sounds/Glass.aiff
}

print_help() {
    debug_print $0

    echo "\nUsage: sims.sh [-v] (-h | -l | ((-c|-d) [o|p|c|n] [--all|--min] [--suffix <suffix>]))"
    echo          
    echo "Commands"          
    echo "  -h                  Show this help message and exit"
    echo "  -l                  List devices"
    echo "  -c                  Create devices"
    echo "  -d                  Delete devices"
    echo          
    echo "Selectors"          
    echo "  n                   Use newest runtime (iOS $nextOS)"
    echo "  c                   Use current runtime (iOS $currentOS)"
    echo "  p                   Use previous runtime (iOS $previousOS)"
    echo "  o                   Use oldest runtime (iOS $oldestOS)"
    echo          
    echo "Scope"          
    echo "  --all               Create/delete all simulators for the chosen set"
    echo "  --min               Create/delete only simulators for the minimum set"
    echo
    echo "Other Options"          
    echo "  -v                  Enable verbose mode"
    echo "  --suffix <suffix>   Append <suffix> to created simulator names"
    echo
    echo "Set \$PROXYING_CERTIFICATE to the location of the proxy root certificate to auto-install it in each created simulator."
    echo
    echo "Usage Summary"
    echo
    local selector_header="Selector"
    local scope_header="Scope"
    local runtime_header="Runtime"
    local devices_header="Devices"

    local -a summary_rows
    summary_rows=(
        "o|min|iOS $oldestOS|${(j/, /)oldestDevices}"
        "o|all|iOS $oldestOS|${(j/, /)oldestDevices}"
        "p|min|iOS $previousOS|${(j/, /)previousDevices}"
        "p|all|iOS $previousOS|${(j/, /)previousDevices}"
        "c|min|iOS $currentOS|${(j/, /)currentMinimumDevices}"
        "c|all|iOS $currentOS|${(j/, /)currentDevices}"
        "n|min|iOS $nextOS|${(j/, /)nextMinimumDevices}"
        "n|all|iOS $nextOS|${(j/, /)nextDevices}"
    )

    local selector_width=${#selector_header}
    local scope_width=${#scope_header}
    local runtime_width=${#runtime_header}
    local devices_width=${#devices_header}

    local row selector scope runtime devices rest
    for row in "${summary_rows[@]}"; do
        selector="${row%%|*}"
        rest="${row#*|}"
        scope="${rest%%|*}"
        rest="${rest#*|}"
        runtime="${rest%%|*}"
        devices="${rest#*|}"

        (( ${#selector} > selector_width )) && selector_width=${#selector}
        (( ${#scope} > scope_width )) && scope_width=${#scope}
        (( ${#runtime} > runtime_width )) && runtime_width=${#runtime}
        (( ${#devices} > devices_width )) && devices_width=${#devices}
    done

    local selector_rule="$(printf '%*s' "$selector_width" '' | tr ' ' '-')"
    local scope_rule="$(printf '%*s' "$scope_width" '' | tr ' ' '-')"
    local runtime_rule="$(printf '%*s' "$runtime_width" '' | tr ' ' '-')"
    local devices_rule="$(printf '%*s' "$devices_width" '' | tr ' ' '-')"

    echo "+-${selector_rule}-+-${scope_rule}-+-${runtime_rule}-+-${devices_rule}-+"
    printf "| %-*s | %-*s | %-*s | %-*s |\n" "$selector_width" "$selector_header" "$scope_width" "$scope_header" "$runtime_width" "$runtime_header" "$devices_width" "$devices_header"
    echo "+-${selector_rule}-+-${scope_rule}-+-${runtime_rule}-+-${devices_rule}-+"

    for row in "${summary_rows[@]}"; do
        selector="${row%%|*}"
        rest="${row#*|}"
        scope="${rest%%|*}"
        rest="${rest#*|}"
        runtime="${rest%%|*}"
        devices="${rest#*|}"

        printf "| %-*s | %-*s | %-*s | %-*s |\n" "$selector_width" "$selector" "$scope_width" "$scope" "$runtime_width" "$runtime" "$devices_width" "$devices"
    done

    echo "+-${selector_rule}-+-${scope_rule}-+-${runtime_rule}-+-${devices_rule}-+"
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

list_requested=0
for arg in "$@"; do
    if [[ "$arg" == "-v" ]]; then
        DEBUG_ENABLED=1
    fi

    if [[ "$arg" == "-l" ]]; then
        list_requested=1
    fi
done

if (( list_requested == 1 )); then
    list_devices
    exit 0
fi

processed_args=()
for (( i=1; i<=$#; i++ )); do
    current_arg="${@[i]}"

    if [[ "$current_arg" == "--suffix" ]]; then
        next_index=$((i + 1))
        if (( next_index > $# )); then
            echo "\nError: Option --suffix requires an argument." >&2
            print_help
            exit 1
        fi

        next_arg="${@[next_index]}"
        if [[ "$next_arg" == -* ]]; then
            echo "\nError: Option --suffix requires a non-option argument." >&2
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

    if [[ "$current_arg" == "-d" ]]; then
        normalized_args+=("$current_arg")
        next_index=$((i + 1))
        if (( next_index <= ${#processed_args[@]} )); then
            next_arg="${processed_args[$next_index]}"
            if [[ "$next_arg" == "c" || "$next_arg" == "p" || "$next_arg" == "n" || "$next_arg" == "o" || "$next_arg" == "--all" ]]; then
                normalized_args+=("$next_arg")
                i=$next_index
            else
                echo "\nError: -d requires a selector [o|p|c|n] or --all." >&2
                print_help
                exit 1
            fi
        else
            echo "\nError: -d requires a selector [o|p|c|n] or --all." >&2
            print_help
            exit 1
        fi
        continue
    fi

    if [[ "$current_arg" == "-c" ]]; then
        normalized_args+=("$current_arg")
        next_index=$((i + 1))
        if (( next_index <= ${#processed_args[@]} )); then
            next_arg="${processed_args[$next_index]}"
            if [[ "$next_arg" == "c" || "$next_arg" == "p" || "$next_arg" == "n" || "$next_arg" == "o" ]]; then
                normalized_args+=("$next_arg")
                i=$next_index
            else
                normalized_args+=("c")
            fi
        else
            normalized_args+=("c")
        fi
        continue
    fi

    if [[ "$current_arg" == "--all" ]]; then
        FORCE_ALL=1
        continue
    fi

    if [[ "$current_arg" == "--min" ]]; then
        FORCE_ALL=0
        continue
    fi

    normalized_args+=("$current_arg")
done

command_count=0
for arg in "${normalized_args[@]}"; do
    if [[ "$arg" == "-c" || "$arg" == "-d" ]]; then
        command_count=$((command_count + 1))
    fi
done

if (( command_count > 1 )); then
    echo "\nError: choose exactly one command: -c or -d." >&2
    print_help
    exit 1
fi

while getopts ":hvlc:d:" argument "${normalized_args[@]}"; do
    case "$argument" in
            h) print_help; exit;;
            v) DEBUG_ENABLED=1;;
            l) list_devices; exit;;
            d) delete_devices $OPTARG;;
            c) create_devices $OPTARG;;
            :) echo "\nError: Option -$OPTARG requires an argument." >&2; print_help; exit 1;;
            ?) echo "\nError: unrecognised argument: -$OPTARG"; print_help; exit 1;;
            *) echo "WTF";;
    esac
done

list_devices

announce_completion&