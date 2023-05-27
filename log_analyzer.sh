#!/usr/bin/env bash

usage() {
  echo "Usage: $0 [-i input_files] [-o output_format] [-f filter] [-s sort_by]"
  echo "  -i input_files: Comma-separated list of input files to process"
  echo "  -o output_format: Output format (plain, csv, json)"
  echo "  -f filter: Filter records using a pattern"
  echo "  -s sort_by: Sort output by a column (date, ip, method, size, status)"
  echo "  -t threshold: Filter records by a threshold"
  echo "Example: $0 -i input.log -o plain -f 200 -s ip"
}
# Parse command-line arguments
while getopts "i:o:f:s:" opt; do
  case $opt in
    i) input_files+=("$OPTARG");;
    o) output_format="$OPTARG";;
    f) filter="$OPTARG";;
    s) sort_by="$OPTARG";;
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


# Count IPs address, HTTP methods, response sizes, status codes, timestamps,
# and URI requests
function generate_statistics {
    file=$1
    echo "Requests per IP address:"
    awk '{print $1}' "$file" | sort | uniq -c | sort -nr
    echo "Requests per HTTP methods:"
    awk '{print $6}' "$file" | sort | uniq -c | sort -nr
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
