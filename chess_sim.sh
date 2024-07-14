#!/bin/bash


pgn_file="$1"  # Get the first command-line argument

# Check if the file exists
if [[ ! -f "$pgn_file" ]]; then
    echo "File does not exist: $pgn_file"
    exit 1
fi

# Function to print the metadata from the PGN file
print_metadata() {
    grep '^\[.*\]' "$1"
}

# Function to parse PGN file and convert to UCI format
parse_pgn_to_uci() {
    pgn_content=$(grep -vE '^\[.*\]' "$1" | tr '\n' ' ' | sed 's/[0-9]\+\.\s\+//g' | tr -s ' ')
    uci_moves=($(python3 parse_moves.py "$pgn_content" 2>/dev/null))
    echo "${uci_moves[@]}"
}

# Function to handle user input
handle_input() {
    echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit:"
    read -s input
    echo
    case $input in
        d) 
            # Next move
            if (( move_index < total_moves )); then
                ((move_index++))
                print_board=true
            else
                echo "No more moves available."
                print_board=false
            fi
            ;;
        a) 
            # Previous move
            if (( move_index > 0 )); then
                ((move_index--))
                print_board=true
            fi
            ;;
        w) 
            # Go to start
            move_index=0
            print_board=true
            ;;
        s) 
            # Go to the end
            move_index=$((total_moves))
            print_board=true
            ;;
        q) 
            # Quit
            echo "Exiting."
            echo "End of game."
            exit 0
            ;;
        *) 
            # Invalid key
            echo "Invalid key pressed: $input"
            print_board=false
            ;;
    esac

    # Explicitly set print_board to true if 'a' is pressed and already at the beginning
    if [[ $input == "a" && $move_index -eq 0 ]]; then
        print_board=true
    fi
}


# Function to print the current move and the board state
print_current_move() {
    echo "Move $move_index/$total_moves"
    if (( move_index < total_moves )); then
        uci_move="${uci_moves[$move_index]}"
    fi

    # Initialize the board with the starting position
    board=(
        "r n b q k b n r"
        "p p p p p p p p"
        ". . . . . . . ."
        ". . . . . . . ."
        ". . . . . . . ."
        ". . . . . . . ."
        "P P P P P P P P"
        "R N B Q K B N R"
    )

    # Apply moves to the board
    for ((i = 0; i < move_index; i++)); do
        move="${uci_moves[$i]}"
        from="${move:0:2}"
        to="${move:2:2}"

        start_c=$(($(printf "%d" "'${from:0:1}") - 97))
        start_r=$((8 - ${from:1:1}))
        end_c=$(($(printf "%d" "'${to:0:1}") - 97))
        end_r=$((8 - ${to:1:1}))

        start_point=$((start_c * 2))
        end_point=$((end_c * 2))

        piece="${board[start_r]:$start_point:1}"

        # Handle castling
        if [[ "$piece" == "K" || "$piece" == "k" ]]; then
            if [[ "$start_c" -eq 4 && ("$end_c" -eq 6 || "$end_c" -eq 2) ]]; then
                # Determine if it's white or black
                king_char="K"
                rook_char="R"
                if [[ "$piece" == "k" ]]; then
                    king_char="k"
                    rook_char="r"
                fi

                if [[ "$end_c" -eq 6 ]]; then
                    # King-side castling
                    rook_start_point=$((7 * 2))
                    rook_end_point=$((5 * 2))
                    king_end_point=$((6 * 2))
                elif [[ "$end_c" -eq 2 ]]; then
                    # Queen-side castling
                    rook_start_point=$((0 * 2))
                    rook_end_point=$((3 * 2))
                    king_end_point=$((2 * 2))
                fi

                # Update the board row without altering other pieces
                row="${board[start_r]}"
                row="${row:0:$start_point}.${row:$((start_point + 1))}"  # Remove the king
                row="${row:0:$rook_start_point}.${row:$((rook_start_point + 1))}"  # Remove the rook
                row="${row:0:$king_end_point}$king_char${row:$((king_end_point + 1))}"  # Place the king
                row="${row:0:$rook_end_point}$rook_char${row:$((rook_end_point + 1))}"  # Place the rook
                board[start_r]="$row"

                continue
            fi
        fi

        # Remove the piece from the original position
        board[start_r]="${board[start_r]:0:$start_point}.${board[start_r]:$((start_point + 1))}"

        # Handle en passant
        if [[ "$piece" == "P" && "${from:1:1}" == "5" && "${to:1:1}" == "6" && "${from:0:1}" != "${to:0:1}" ]]; then
            if [[ "${board[end_r + 1]:$end_point:1}" == "p" ]]; then
                board[end_r + 1]="${board[end_r + 1]:0:$end_point}.${board[end_r + 1]:$((end_point + 1))}"
            fi
        elif [[ "$piece" == "p" && "${from:1:1}" == "4" && "${to:1:1}" == "3" && "${from:0:1}" != "${to:0:1}" ]]; then
            if [[ "${board[end_r - 1]:$end_point:1}" == "P" ]]; then
                board[end_r - 1]="${board[end_r - 1]:0:$end_point}.${board[end_r - 1]:$((end_point + 1))}"
            fi
        fi

        # Handle pawn promotion
        if [[ "$piece" == "P" && "${to:1:1}" == "8" ]]; then
            promotion="${move:4:1}"
            if [[ -z "$promotion" ]]; then
                piece="Q"
            else
                if [[ "$promotion" == [a-z] ]]; then
                    promotion=$(printf "\x$(printf %x $(($(printf "%d" "'$promotion") - 32)))")
                fi
                piece="$promotion"
            fi
        elif [[ "$piece" == "p" && "${to:1:1}" == "1" ]]; then
            promotion="${move:4:1}"
            if [[ -z "$promotion" ]]; then
                piece="q"
            else
                if [[ "$promotion" == [a-z] ]]; then
                    promotion=$(printf "\x$(printf %x $(($(printf "%d" "'$promotion") - 32)))")
                fi
                piece="$promotion"
            fi
        fi

        # Place the piece at the new position
        board[end_r]="${board[end_r]:0:$end_point}${piece}${board[end_r]:$((end_point + 1))}"
    done

    # Print the board in the desired format
    echo "  a b c d e f g h"
    for ((i = 0; i < 8; i++)); do
        echo "$((8 - i)) ${board[i]} $((8 - i))"
    done
    echo "  a b c d e f g h"
}

# Print the metadata once
echo "Metadata from PGN file:"
print_metadata "$pgn_file"

# Print a newline
echo

# Parse the UCI moves from the PGN file
uci_moves=($(parse_pgn_to_uci "$pgn_file"))
move_index=0
total_moves=${#uci_moves[@]}

# Initialize the board and the print_board flag
print_board=true

while true; do
    if $print_board; then
        print_current_move
    fi
    handle_input
done
