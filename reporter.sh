#!/bin/bash

LOG_FILE="/var/log/ufw.log"
ENCODED_API_KEY_FILE="./.abuseipdb_token"
REPORTED_IPS_FILE="/tmp/reported_ips.txt"
REPORT_INTERVAL=18000 # 5h (seconds)

declare -A reported_ips

log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

if [[ -f "$ENCODED_API_KEY_FILE" ]]; then
    DECODED_API_KEY=$(openssl enc -d -base64 -in "$ENCODED_API_KEY_FILE")
    if [[ -z "$DECODED_API_KEY" ]]; then
        log "ERROR" "Failed to decode API key from $ENCODED_API_KEY_FILE"
        exit 1
    fi
else
    log "ERROR" "API key file not found at $ENCODED_API_KEY_FILE"
    exit 1
fi

ABUSEIPDB_API_KEY="$DECODED_API_KEY"

load_reported_ips() {
    if [[ -f "$REPORTED_IPS_FILE" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            IFS=' ' read -r ip report_time <<< "$line"
            if [[ -n "$ip" && -n "$report_time" ]]; then
                reported_ips["$ip"]=$report_time
            else
                log "WARN" "Invalid line format: '$line'"
            fi
        done < "$REPORTED_IPS_FILE"
        log "INFO" "Loaded ${#reported_ips[@]} IPs from $REPORTED_IPS_FILE"
    else
        log "INFO" "$REPORTED_IPS_FILE does not exist. No data to load!"
    fi
}

save_reported_ips() {
    : > "$REPORTED_IPS_FILE"
    for ip in "${!reported_ips[@]}"; do
        echo "$ip ${reported_ips[$ip]}" >> "$REPORTED_IPS_FILE"
    done
}

is_local_ip() {
    local ip="$1"
    [[ "$ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|fc|fd|fe80|::1) ]]
}

report_to_abuseipdb() {
    local ip="$1" categories="$2" proto="$3" spt="$4" dpt="$5" ttl="$6" len="$7" tos="$8" warsaw_time="$9"

    local comment="IP: $ip
Protocol: $proto
Source port: $spt
Destination port: $dpt"

    [[ -n "$ttl" ]] && comment+="
TTL: $ttl"

    [[ -n "$len" ]] && comment+="
Packet length: $len"

    [[ -n "$tos" ]] && comment+="
TOS: $tos"

    comment+="
Timestamp: $warsaw_time [Europe/Warsaw]

The IP address was blocked by the Uncomplicated Firewall (UFW) due to suspicious activity. Packet details suggest a possible unauthorized access or port scanning attempt."

    local response
    response=$(curl -s -X POST "https://api.abuseipdb.com/api/v2/report" \
        --data-urlencode "ip=$ip" \
        --data-urlencode "categories=$categories" \
        --data-urlencode "comment=$comment" \
        -H "Key: $ABUSEIPDB_API_KEY" \
        -H "Accept: application/json")

    local abuse_confidence_score
    abuse_confidence_score=$(echo "$response" | jq -r '.data.abuseConfidenceScore')

    if [[ "$abuse_confidence_score" =~ ^[0-9]+$ ]]; then
        log "INFO" "Successfully reported IP $ip to AbuseIPDB with score: $abuse_confidence_score"
    else
        log "ERROR" "Failed to report IP $ip to AbuseIPDB: $response"
    fi
}

is_ip_reported_recently() {
    local ip="$1"
    local current_time
    current_time=$(date +%s)

    if [[ -v reported_ips["$ip"] ]]; then
        local report_time=${reported_ips["$ip"]}
        (( current_time - report_time < REPORT_INTERVAL )) && return 0
    fi
    return 1
}

mark_ip_as_reported() {
    local ip="$1"
    reported_ips["$ip"]=$(date +%s)
}

determine_categories() {
    local proto="$1"
    local dpt="$2"

    # See https://www.abuseipdb.com/categories for more
    case "$proto" in
        "TCP")
            case "$dpt" in
                22) echo "14,22,18" ;;  # Port Scan | SSH | Brute-Force
                80 | 443 | 8080) echo "14,21" ;;  # Port Scan | Web App Attack
                25) echo "11" ;;  # Email Spam
                21) echo "5,18" ;;  # FTP Brute-Force | Brute-Force
                53) echo "1,2" ;;  # DNS Compromise | DNS Poisoning
                23 | 3389) echo "14,15,18" ;;  # Port Scan | Hacking | Brute-Force
                3306) echo "16" ;;  # SQL Injection
                6666 | 6667 | 6668 | 6669) echo "14,8" ;;  # Port Scan | Fraud VoIP
                9999) echo "6" ;;  # Ping of Death
                *) echo "14" ;;  # Port Scan
            esac
            ;;
        "UDP")
            case "$dpt" in
                53) echo "14,1,2" ;;  # Port Scan | DNS Compromise | DNS Poisoning
                123) echo "14,17" ;;  # Port Scan | Spoofing
                *) echo "14,4" ;;  # Port Scan | DDoS Attack
            esac
            ;;
        *) echo "14,15" ;;  # Port Scan | Hacking
    esac
}

process_log_line() {
    local line="$1"
    if [[ "$line" == *"[UFW BLOCK]"* ]]; then
        local timestamp src_ip proto spt dpt ttl len tos categories warsaw_time

        timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
        [[ -z "$timestamp" ]] && timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        src_ip=$(echo "$line" | grep -oP 'SRC=\K[^\s]+')

        if is_local_ip "$src_ip"; then
            log "INFO" "Ignoring local IP: $src_ip"
            return
        fi

        proto=$(echo "$line" | grep -oP 'PROTO=\K[^\s]+')
        spt=$(echo "$line" | grep -oP 'SPT=\K[^\s]+')
        dpt=$(echo "$line" | grep -oP 'DPT=\K[^\s]+')
        ttl=$(echo "$line" | grep -oP 'TTL=\K[^\s]+')
        len=$(echo "$line" | grep -oP 'LEN=\K[^\s]+')
        tos=$(echo "$line" | grep -oP 'TOS=\K[^\s]+')

        if is_ip_reported_recently "$src_ip"; then
            log "INFO" "IP $src_ip ($proto) was reported recently. Skipping..."
            return
        fi

        categories=$(determine_categories "$proto" "$dpt")
        warsaw_time=$(TZ="Europe/Warsaw" date -d "$timestamp" '+%Y-%m-%d %H:%M:%S')

        log "INFO" "Reporting IP $src_ip ($proto $dpt) with categories $categories..."
        report_to_abuseipdb "$src_ip" "$categories" "$proto" "$spt" "$dpt" "$ttl" "$len" "$tos" "$warsaw_time"
        mark_ip_as_reported "$src_ip"
        save_reported_ips
    fi
}

load_reported_ips

if ! command -v jq &> /dev/null; then
    log "ERROR" "jq is not installed. Please install jq to run this script."
    exit 1
fi

log "INFO" "Starting to monitor $LOG_FILE"

tail -Fn0 "$LOG_FILE" | while read -r line; do
    process_log_line "$line"
done
