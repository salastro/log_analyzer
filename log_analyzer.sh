#!/usr/bin/env bash

usage() {
  echo "Usage: $0 [-i input_files] [-o output_format] [-s sort_by] [-f ip_filter] [-d date_filter] [-m method_filter] [-c code_filter] [-p pattern] [-t threshold]"
  echo "  -i input_files: Comma-separated list of input files to process"
  echo "  -o output_format: Output format (plain, csv, json)"
  echo "  -s sort_by: Sort output by a column (date, ip, method, size, status)"
  echo "  -f ip_filter: Filter records by IP address"
  echo "  -d date_filter: Filter records by date range, format: start_date,end_date (e.g., '01/Jan/2021,31/Dec/2021')"
  echo "  -m method_filter: Filter records by HTTP method (e.g., GET, POST)"
  echo "  -c code_filter: Filter records by response code (e.g., 200, 404)"
  echo "  -p pattern: Search for specific string or pattern in the log file"
  echo "  -t threshold: Display only results meeting or exceeding the threshold (response size)"
  echo "Example: $0 -i input.log -o plain -f 192.168.1.1 -d '01/Jan/2021,31/Dec/2021' -m GET -c 200 -p 'example.com' -t 1024"
}

# Parse command-line arguments
while getopts "i:o:s:f:d:m:c:p:" opt; do
  case $opt in
    i) input_files+=("$OPTARG");;
    o) output_format="$OPTARG";;
    s) sort_by="${OPTARG:-date}";;
    f) ip_filter="$OPTARG";;
    d) date_filter="$OPTARG";;
    m) method_filter="$OPTARG";;
    c) code_filter="$OPTARG";;
    p) pattern="$OPTARG";;
    t) threshold="$OPTARG";;
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
  local fields=()

  case $sort_by in
    requests)
      sort_command="sort -k1,1"
      ;;
    data)
      sort_command="sort -k10,10n"
      ;;
    ip)
      sort_command="sort -n -t. -k1,1 -k2,2 -k3,3 -k4,4"
      ;;
    date)
      sort_command="sort -k4,4"
      ;;
    method)
      sort_command="sort -k6,6"
      ;;
    status)
      sort_command="sort -k9,9n"
      ;;
    *)
      sort_command="sort"
      ;;
  esac

  local sorted_file=$(cat "$file" | $sort_command)
  cat "$sorted_file" > "/tmp/$file.sorted"
  local file="/tmp/$file.sorted"

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

    # Apply pattern
    if [[ ! -z "$pattern" ]]; then
      if ! echo "$line" | grep -q "$pattern"; then
        continue
      fi
    fi

    # Apply threshold
    if [[ ! -z "$threshold" ]]; then
      if (( "${fields[8]}" < threshold )); then
        continue
      fi
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
  done "$file"
}

# Count IPs address and HTTP methods
function generate_statistics {
  local file=$1
  echo "Requests per IP address:"
  awk '{print $1}' "$file" | sort | uniq -c | sort -nr
  echo "Requests per HTTP methods:"
  awk '{print $6}' "$file" | sort | uniq -c | sort -nr
}

function summarize_data_transferred {
  local file=$1

  echo "Data transferred summary:"
  total_data=$(awk '{ sum += $10 } END { print sum }' "$file")
  echo "    Total data transferred: $total_data"

  num_ips=$(awk '{ ip[$1]++ } END { print length(ip) }' "$file")
  average_data=$(echo "scale=2; $total_data / $num_ips" | bc)
  echo "    Average data transferred per IP: $average_data"

  echo "    Data transferred per IP address:"
  awk '{ data[$1] += $10 } END { for (i in data) print data[i], i }' "$file"
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
    summarize_data_transferred "$file"
done

# vim:set et sw=2 ts=2:
