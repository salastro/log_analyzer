#!/usr/bin/env bash

usage() {
  echo "Usage: $0 [-i input_files] [-o output_format] [-s sort_by] [-f ip_filter] [-d date_filter] [-m method_filter] [-c code_filter]"
  echo "  -i input_files: Comma-separated list of input files to process"
  echo "  -o output_format: Output format (plain, csv, json)"
  echo "  -s sort_by: Sort output by a column (date, ip, method, size, status)"
  echo "  -f ip_filter: Filter records by IP address"
  echo "  -d date_filter: Filter records by date range, format: start_date,end_date (e.g., '01/Jan/2021,31/Dec/2021')"
  echo "  -m method_filter: Filter records by HTTP method (e.g., GET, POST)"
  echo "  -c code_filter: Filter records by response code (e.g., 200, 404)"
  echo "Example: $0 -i input.log -o plain -f 192.168.1.1 -d '01/Jan/2021,31/Dec/2021' -m GET -c 200"
}

# Parse command-line arguments
while getopts "i:o:s:f:d:m:c:" opt; do
  case $opt in
    i) input_files+=("$OPTARG");;
    o) output_format="$OPTARG";;
    s) sort_by="$OPTARG";;
    f) ip_filter="$OPTARG";;
    d) date_filter="$OPTARG";;
    m) method_filter="$OPTARG";;
    c) code_filter="$OPTARG";;
    \?) usage; exit 1;;
  esac
done

# if no input print usage
if [[ -z "$input_files" ]]; then
  usage
  exit 1
fi

# Parse combined log format and return array of fields
function parse_file {
    local file="$1"
    local fields=()

    while IFS= read -r line
    do
        IFS=' ' read -ra fields <<< "$line"
        local ip="${fields[0]}"
        local date="${fields[3]} ${fields[4]}"
        local method="${fields[5]}"
        local url="${fields[6]}"
        local status="${fields[8]}"
        local size="${fields[9]}"
        local referer="${fields[10]}"
        local agent=""
        for i in "${fields[@]:11}"; do
            agent+="$i "
        done

        # Apply filters
        if [[ ! -z "$ip_filter" && "$ip" != "$ip_filter" ]]; then
            continue
        fi

        if [[ ! -z "$date_filter" ]]; then
            IFS=',' read -ra date_range <<< "$date_filter"
            start_date=$(date -d"${date_range[0]}" +%s)
            end_date=$(date -d"${date_range[1]}" +%s)
            log_date=$(date -d"${date//[/]}" +%s)

            if (( log_date < start_date || log_date > end_date )); then
                continue
            fi
        fi

        if [[ ! -z "$method_filter" && "$method" != "$method_filter" ]]; then
            continue
        fi

        if [[ ! -z "$code_filter" && "$status" != "$code_filter" ]]; then
            continue
        fi

        # Output the filtered results
        echo "IP: $ip"
        echo "    Date: $date"
        echo "    HTTP method: $method"
        echo "    URL: $url"
        echo "    Status: $status"
        echo "    Size: $size"
        echo "    Referer: $referer"
        echo "    Agent: $agent"
    done < "$file"
}

# Generate statistics
function generate_statistics {
    local file=$1

    echo "Requests per IP address:"
    awk -v ip_filter="$ip_filter" '{ if (!ip_filter || $1 == ip_filter) { print $1 } }' "$file" | sort | uniq -c | sort -nr

    echo "Requests per date range:"
    if [[ ! -z "$date_filter" ]]; then
        IFS=',' read -ra date_range <<< "$date_filter"
        start_date=$(date -d"${date_range[0]}" +%s)
        end_date=$(date -d"${date_range[1]}" +%s)
    fi
    awk -v start_date="$start_date" -v end_date="$end_date" -F'[][]' '{ gsub(/:/, "", $2); ts = mktime(gensub(/[^0-9]+/, " ", "g", $2)); if (!start_date || !end_date || (ts >= start_date && ts <= end_date)) { print $2 } }' "$file" | sort | uniq -c | sort -nr

    echo "Requests per HTTP method:"
    awk -v method_filter="$method_filter" '{ if (!method_filter || $6 == method_filter) { print $6 } }' "$file" | sort | uniq -c | sort -nr

    echo "Requests per response code:"
    awk -v code_filter="$code_filter" '{ if (!code_filter || $9 == code_filter) { print $9 } }' "$file" | sort | uniq -c | sort -nr
}

# Read files
for file in "${input_files[@]}"; do
    # exist if file does not exist
    if [[ ! -f "$file" ]]; then
      echo "Error: $file does not exist"
      exit 1
    fi

    # exist if file is empty
    if [[ ! -s "$file" ]]; then
      echo "Error: $file is empty"
      exit 1
    fi

    echo
    echo "Log file: $file"

    parse_file "$file"
    generate_statistics "$file"
done
