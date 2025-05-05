#!/bin/sh

UBUS_SERVICE="luci.routekeeper"

##########################################
# Interactive CLI Main Menu Loop
##########################################
interactive_menu() {
    while true; do
        clear
        echo "
 _____         _       _
| __  |___ _ _| |_ ___| |_ ___ ___ ___ ___ ___
|    -| . | | |  _| -_| '_| -_| -_| . | -_|  _|
|__|__|___|___|_| |___|___|___|___|  _|___|_|
                  Interactive TUI |_|
"
        echo ""
        echo "Please select a command:"
        echo "1 - List Interfaces"
        echo "2 - Find Current Default Gateway"
        echo "3 - Set Default Gateway"
        echo "4 - Curl Test"
        echo "5 - Ping Test"
        echo "6 - Load Settings"
        echo "7 - Change Test Settings"
        echo "0 - Exit"
        echo ""
        printf "Select a command number: " > /dev/tty
        read -r command_choice < /dev/tty

        case "$command_choice" in
            1) list_interfaces_clean ;;
            2) safe_ubus_call find_active_default_if ;;
            3) set_gateway_interactive ;;
            4) curl_test_interactive ;;
            5) ping_test_interactive ;;
            6) safe_ubus_call load_settings ;;
            7) change_test_settings ;;
            0 | q | Q) echo "Exiting RouteKeeper CLI..."; exit 0 ;;
            *) echo "Invalid command. Try again." ;;
        esac

        echo ""
        printf "Press ENTER to return to menu..." > /dev/tty
        read -r < /dev/tty
    done
}

##########################################
# UBUS Wrapper with Error Checking
##########################################
safe_ubus_call() {
    RESULT=$(ubus call "$UBUS_SERVICE" "$1" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: RPC call '$1' failed or permission denied."
        return 1
    fi
    echo "$RESULT" | format_output
}

##########################################
# Human-Readable Output Formatter
##########################################
format_output() {
    sed -e 's/[{}]//g' -e 's/\"//g' -e 's/,/\n/g' \
        | sed '/^[[:space:]]*success:/d' \
        | grep -v '^[[:space:]]*$'
}

##########################################
# List Available Interfaces
##########################################
list_interfaces_clean() {
    RAW=$(ubus call "$UBUS_SERVICE" get_interfaces 2>/dev/null)
    [ $? -ne 0 ] && echo "Error: Failed to fetch interfaces." && return
    RAW_SINGLE=$(echo "$RAW" | tr -d '\n')
    INTERFACES=$(echo "$RAW_SINGLE" | sed -n 's/.*"interfaces":[[:space:]]*\[\(.*\)\].*/\1/p')
    echo "$INTERFACES" | sed 's/"//g; s/\]//g' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

##########################################
# Prompt User to Select an Interface
# Usage: select_interface true
##########################################
select_interface() {
    allow_all="$1"

    RAW_INTERFACES=$(ubus call "$UBUS_SERVICE" get_interfaces 2>/dev/null)
    [ $? -ne 0 ] && echo "Error: Failed to fetch interfaces." && return 1
    RAW_SINGLE=$(echo "$RAW_INTERFACES" | tr -d '\n')
    INTERFACES=$(echo "$RAW_SINGLE" | sed -n 's/.*"interfaces":[[:space:]]*\[\(.*\)\].*/\1/p')
    INTERFACES=$(echo "$INTERFACES" | sed 's/"//g' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    echo "Available Interfaces:" > /dev/tty
    INDEX=1
    for iface in $INTERFACES; do
        echo "$INDEX - $iface" > /dev/tty
        eval "IFACE_$INDEX=\"$iface\""
        INDEX=$((INDEX + 1))
    done

    TOTAL_IFACES=$((INDEX - 1))
    [ "$TOTAL_IFACES" -eq 0 ] && echo "No interfaces found." > /dev/tty && return 1

    if [ "$allow_all" = "true" ]; then
        echo "A - Test all interfaces" > /dev/tty
    fi

    echo "" > /dev/tty
    printf "Select an interface (or type 'q' to cancel): " > /dev/tty
    read -r IFACE_CHOICE < /dev/tty

    case "$IFACE_CHOICE" in
        [Qq]) echo "Cancelled." > /dev/tty; return 1 ;;
        [Aa]) SELECTED_IFACE="ALL"; return 0 ;;
    esac

    if ! echo "$IFACE_CHOICE" | grep -qE '^[0-9]+$' || [ "$IFACE_CHOICE" -lt 1 ] || [ "$IFACE_CHOICE" -gt "$TOTAL_IFACES" ]; then
        echo "Invalid choice." > /dev/tty
        return 1
    fi

    eval "SELECTED_IFACE=\$IFACE_$IFACE_CHOICE"
    echo "$SELECTED_IFACE"
}

##########################################
# Set Default Gateway via Selected Interface
##########################################
set_gateway_interactive() {
    echo "Setting Gateway:"
    IFACE=$(select_interface) || return
    RESULT=$(ubus call "$UBUS_SERVICE" set_default_gateway "{ \"interface\": \"$IFACE\" }" 2>/dev/null)
    [ $? -ne 0 ] && echo "Error: Failed to set gateway." && return
    echo "$RESULT" | format_output
}

##########################################
# Run Curl Test via Selected Interface
##########################################
curl_test_interactive() {
    echo "Running Curl Test:"
    select_interface true || return

    if [ "$SELECTED_IFACE" = "ALL" ]; then
        echo "Running curl test on all interfaces..."
        ubus call "$UBUS_SERVICE" run_curl_test_all | format_output
    else
        result=$(ubus call "$UBUS_SERVICE" run_curl_test "{\"interface\":\"$SELECTED_IFACE\"}" 2>/dev/null)
        [ $? -ne 0 ] && echo "Error: Curl test failed." && return
        echo "$result" | format_output
    fi
}

##########################################
# Run Ping Test via Selected Interface
##########################################
ping_test_interactive() {
    echo "Running Ping Test:"
    select_interface true || return

    if [ "$SELECTED_IFACE" = "ALL" ]; then
        echo "Running ping test on all interfaces..."
        ubus call "$UBUS_SERVICE" run_ping_test_all | format_output
    else
        result=$(ubus call "$UBUS_SERVICE" run_ping_test "{\"interface\":\"$SELECTED_IFACE\"}" 2>/dev/null)
        [ $? -ne 0 ] && echo "Error: Ping test failed." && return
        echo "$result" | format_output
    fi
}

##########################################
# Describe each setting for user guidance
##########################################
describe_setting() {
    case "$1" in
        ping_address) echo "Target IP address to ping (e.g. 8.8.8.8)" ;;
        ping_timeout) echo "Ping timeout in seconds (e.g. 1)" ;;
        ping_count) echo "Number of ping packets to send (e.g. 1)" ;;
        curl_address) echo "URL used for curl test (e.g. http://www.gstatic.com/generate_204)" ;;
        curl_timeout) echo "Curl connection timeout in seconds (e.g. 2)" ;;
        curl_max_time) echo "Max total time curl is allowed to run in seconds (e.g. 2)" ;;
        test_type) echo "Which tests to run: 'ping', 'curl', or 'both'" ;;
        *) echo "No description available for this setting." ;;
    esac
}

##########################################
# Edit and Save RouteKeeper Test Settings
##########################################
change_test_settings() {
    echo "Fetching current settings..."
    RAW_RESPONSE=$(ubus call "$UBUS_SERVICE" load_settings 2>/dev/null)
    [ $? -ne 0 ] && echo "Error: Failed to load settings." && return
    SETTINGS_JSON=$(echo "$RAW_RESPONSE" | sed -n '/"settings": {/,/}/p' | sed '1d;$d')
    [ -z "$SETTINGS_JSON" ] && echo "Error: No settings found." && return

    echo "Available Settings:"
    INDEX=1

    while IFS=: read -r KEY VALUE; do
        KEY=$(echo "$KEY" | sed 's/"//g' | xargs)
        VALUE=$(echo "$VALUE" | sed 's/"//g' | xargs)
        [ -z "$KEY" ] || [ "$KEY" = "selected_default" ] && continue
        HUMAN_KEY=$(echo "$KEY" | awk -F_ '{ for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); OFS=" "; print }')
        eval "SETTING_$INDEX=\"$KEY:$VALUE\""
        echo "$INDEX - $HUMAN_KEY"
        INDEX=$((INDEX + 1))
    done < <(echo "$SETTINGS_JSON" | sed 's/[{}]//g' | tr ',' '\n' | grep ':')

    TOTAL_SETTINGS=$((INDEX - 1))
    [ "$TOTAL_SETTINGS" -eq 0 ] && echo "No editable settings found." && return

    echo ""
    printf "Select a setting number to change (or type 'q' to cancel): "
    read -r CHOICE
    if [ "$CHOICE" = "q" ] || [ "$CHOICE" = "Q" ]; then
        echo "Cancelled."
        return
    fi
    if [ -z "$CHOICE" ] || ! echo "$CHOICE" | grep -qE '^[0-9]+$' || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "$TOTAL_SETTINGS" ]; then
        echo "Invalid choice. Exiting..."
        return
    fi

    eval "SELECTED_SETTING=\$SETTING_$CHOICE"
    SELECTED_KEY=$(echo "$SELECTED_SETTING" | cut -d':' -f1)
    CURRENT_VALUE=$(echo "$SELECTED_SETTING" | cut -d':' -f2)

    # Determine default value (same logic reused)
    case "$SELECTED_KEY" in
        ping_address) DEFAULT_VALUE="8.8.8.8" ;;
        curl_timeout) DEFAULT_VALUE="2" ;;
        test_type) DEFAULT_VALUE="both" ;;
        ping_timeout) DEFAULT_VALUE="1" ;;
        curl_address) DEFAULT_VALUE="http://www.gstatic.com/generate_204" ;;
        ping_count) DEFAULT_VALUE="1" ;;
        curl_max_time) DEFAULT_VALUE="2" ;;
        *) DEFAULT_VALUE="$CURRENT_VALUE" ;;
    esac

    HUMAN_SELECTED_KEY=$(echo "$SELECTED_KEY" | awk -F_ '{ for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); OFS=" "; print }')
    echo "You selected: $HUMAN_SELECTED_KEY"
    describe_setting "$SELECTED_KEY"
    echo "Default value: $DEFAULT_VALUE"
    printf "Enter new value, press ENTER to use default, or type 'q' to cancel: "
    read -r NEW_VALUE

    if [ "$NEW_VALUE" = "q" ] || [ "$NEW_VALUE" = "Q" ]; then
        echo "Cancelled. No changes made."
        return
    fi

    [ -z "$NEW_VALUE" ] && NEW_VALUE="$DEFAULT_VALUE"

    UPDATED_SETTINGS="{ \"$SELECTED_KEY\": \"$NEW_VALUE\" }"
    echo "Saving changes..."
    ubus call "$UBUS_SERVICE" save_settings "{ \"settings\": $UPDATED_SETTINGS }" > /dev/null 2>&1
    echo "Settings updated successfully!"
}

##########################################
# CLI Entry Point (Direct Command Mode)
##########################################
if [ $# -lt 1 ]; then
    interactive_menu
else
    CMD="$1"
    case "$CMD" in
        list-interfaces) list_interfaces_clean ;;
        find-gateway) safe_ubus_call find_active_default_if ;;
        set-gateway) set_gateway_interactive ;;
        curl-test) curl_test_interactive ;;
        ping-test) ping_test_interactive ;;
        load-settings) safe_ubus_call load_settings ;;
        change-test-settings) change_test_settings ;;
        *) echo "Error: Unknown command '$CMD'"; exit 1 ;;
    esac
fi
