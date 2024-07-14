#!/bin/bash

# Function to split PGN file into individual games
split_pgn() {
    local input_file="$1"
    local dest_dir="$2"
    local count=1

    # Extract the base name of the input file
    local base_name=$(basename "$input_file" .pgn)

    # Create a temporary file
    local tmp_file=$(mktemp)

    # Variable to track if we are in the moves section
    local in_moves=0

    # Read the input file line by line, handling both \n and \r\n line endings
    while IFS=$'\r\n' read -r line || [[ -n "$line" ]]
    do
        # If the line starts with "[Event " and it's not the first game,
        # move the temporary file to the destination directory
        if [[ $line == \[Event* ]] && [[ $in_moves -eq 1 ]]; then
            mv "$tmp_file" "$dest_dir/${base_name}_$count.pgn"
            echo "Saved game to $dest_dir/${base_name}_$count.pgn"  # Print message
            count=$((count + 1))

            # Append a new line at the end of the file
            echo >> "$dest_dir/${base_name}_$((count-1)).pgn"

            # Create a new temporary file
            tmp_file=$(mktemp)
            in_moves=0
        fi

        # If the line is empty, we are in the moves section
        if [[ -z $line ]]; then
            in_moves=1
        fi

        # Write the line to the temporary file
        echo "$line" >> "$tmp_file"
    done < "$input_file"

    # Move the last game to the destination directory
    if [[ -s $tmp_file ]]; then
        mv "$tmp_file" "$dest_dir/${base_name}_$count.pgn"
        echo "Saved game to $dest_dir/${base_name}_$count.pgn"  # Print message

        # Append a new line at the end of the last file
        echo >> "$dest_dir/${base_name}_$count.pgn"
    fi

    echo "All games have been split and saved to '$dest_dir'."
}

# Check the number of arguments
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source_pgn_file> <destination_directory>"
    exit 1
fi

input_file="$1"
dest_dir="$2"

# Check if the input file exists
if [[ ! -f $input_file ]]; then
    echo "Error: File '$input_file' does not exist."
    exit 1
fi

# Check if the destination directory exists, if not create it
if [[ ! -d $dest_dir ]]; then
    mkdir -p "$dest_dir"
    echo "Created directory '$dest_dir'."
fi

# Call the split_pgn function
split_pgn "$input_file" "$dest_dir"
