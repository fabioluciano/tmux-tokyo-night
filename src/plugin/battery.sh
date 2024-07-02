#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../utils.sh"

# Battery querying code from https://github.com/tmux-plugins/tmux-battery
#
# Copyright (C) 2014 Bruno Sutic
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software
# and associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

s_osx() {
    [ $(uname) == "Darwin" ]
}

is_chrome() {
    chrome="/sys/class/chromeos/cros_ec"
    if [ -d "$chrome" ]; then
        return 0
    else
        return 1
    fi
}

is_wsl() {
    if [ ! -f /proc/version ]; then
        return 1
    fi

    version=$(</proc/version)
    if [[ "$version" == *"Microsoft"* || "$version" == *"microsoft"* ]]; then
        return 0
    else
        return 1
    fi
}

command_exists() {
    local command="$1"
    type "$command" >/dev/null 2>&1
}

battery_status() {
    if is_wsl; then
        local battery
        battery=$(find /sys/class/power_supply/*/status | tail -n1)
        awk '{print tolower($0);}' "$battery"
    elif command_exists "pmset"; then
        pmset -g batt | awk -F '; *' 'NR==2 { print $2 }'
    elif command_exists "acpi"; then
        acpi -b | awk '{gsub(/,/, ""); print tolower($3); exit}'
    elif command_exists "upower"; then
        local battery
        battery=$(upower -e | grep -E 'battery|DisplayDevice'| tail -n1)
        upower -i $battery | awk '/state/ {print $2}'
    elif command_exists "termux-battery-status"; then
        termux-battery-status | jq -r '.status' | awk '{printf("%s%", tolower($1))}'
    elif command_exists "apm"; then
        local battery
        battery=$(apm -a)
        if [ $battery -eq 0 ]; then
            echo "discharging"
        elif [ $battery -eq 1 ]; then
            echo "charging"
        fi
    fi
}

print_battery_percentage() {
    # percentage displayed in the 2nd field of the 2nd row
    if is_wsl; then
        local battery
        battery=$(find /sys/class/power_supply/*/capacity | tail -n1)
        cat "$battery"
    elif command_exists "pmset"; then
        pmset -g batt | grep -o "[0-9]\{1,3\}%"
    elif command_exists "acpi"; then
        acpi -b | grep -m 1 -Eo "[0-9]+%"
    elif command_exists "upower"; then
        # use DisplayDevice if available otherwise battery
        local battery=$(upower -e | grep -E 'battery|DisplayDevice'| tail -n1)
        if [ -z "$battery" ]; then
            return
        fi
        local percentage=$(upower -i $battery | awk '/percentage:/ {print $2}')
        if [ "$percentage" ]; then
            echo ${percentage%.*%}
            return
        fi
        local energy
        local energy_full
        energy=$(upower -i $battery | awk -v nrg="$energy" '/energy:/ {print nrg+$2}')
        energy_full=$(upower -i $battery | awk -v nrgfull="$energy_full" '/energy-full:/ {print nrgfull+$2}')
        if [ -n "$energy" ] && [ -n "$energy_full" ]; then
            echo $energy $energy_full | awk '{printf("%d%%", ($1/$2)*100)}'
        fi
    elif command_exists "termux-battery-status"; then
        termux-battery-status | jq -r '.percentage' | awk '{printf("%d%%", $1)}'
    elif command_exists "apm"; then
        apm -l
    fi
}
##################################################

battery_percentage=$(print_battery_percentage)
charging_status=$(battery_status)

if [ "$charging_status" ==  "charging" ] || [ "$charging_status" == "charged" ]; then
    plugin_battery_icon=$(get_tmux_option "@theme_plugin_battery_charging_icon" " ")
else
    plugin_battery_icon=$(get_tmux_option "@theme_plugin_battery_discharging_icon" "󰁹 ")
fi

battery_number="${battery_percentage//%/}"

if [ "$battery_number" -lt $(get_tmux_option "@theme_plugin_battery_red_threshold" "10") ]; then
    plugin_battery_accent_color=$(get_tmux_option "@theme_plugin_battery_red_accent_color" "red")
    plugin_battery_accent_color_icon=$(get_tmux_option "@theme_plugin_battery_red_accent_color_icon" "magenta2")
elif [ "$battery_number" -lt $(get_tmux_option "@theme_plugin_battery_yellow_threshold" "30") ]; then
    plugin_battery_accent_color=$(get_tmux_option "@theme_plugin_battery_yellow_accent_color" "yellow")
    plugin_battery_accent_color_icon=$(get_tmux_option "@theme_plugin_battery_yellow_accent_color_icon" "orange")
else
    plugin_battery_accent_color=$(get_tmux_option "@theme_plugin_battery_green_accent_color" "blue7")
    plugin_battery_accent_color_icon=$(get_tmux_option "@theme_plugin_battery_green_accent_color_icon" "blue0")
fi

export plugin_battery_icon plugin_battery_accent_color plugin_battery_accent_color_icon

echo $battery_percentage
