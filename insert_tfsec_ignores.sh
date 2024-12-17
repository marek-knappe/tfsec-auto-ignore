#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${1:-.}"

echo "[INFO] Running tfsec on directory: $TF_DIR"
OUTPUT=$(tfsec "$TF_DIR" --no-colour 2>&1 || true)

echo "[INFO] tfsec completed. Output:"
echo "----------------------------------------"
echo "$OUTPUT"
echo "----------------------------------------"

# Initialize insertions list
insertions=()

CURRENT_FILES=()
CURRENT_LINES=()
CHECK_ID=""

choose_file_and_line() {
    TARGET_FILE=""
    TARGET_LINE=""
    for i in "${!CURRENT_FILES[@]}"; do
        F="${CURRENT_FILES[$i]}"
        L="${CURRENT_LINES[$i]}"

        # Prepend TF_DIR if path is not absolute
        if [[ "$F" != /* ]]; then
            F="$TF_DIR/$F"
        fi

        if [ -f "$F" ]; then
            TARGET_FILE="$F"
            TARGET_LINE="$L"
            echo "[INFO] Using $TARGET_FILE:$TARGET_LINE (file exists)"
            break
        else
            echo "[WARN] File $F not found, trying next candidate..."
        fi
    done
}

find_block_line() {
    local file="$1"
    local target_line="$2"

    FILE_CONTENT=()
    while IFS= read -r file_line; do
        FILE_CONTENT+=("$file_line")
    done < "$file"

    if ! [[ "$target_line" =~ ^[0-9]+$ ]]; then
        echo "[WARN] LINE value '$target_line' not numeric, defaulting to 1"
        target_line=1
    fi

    local BLOCK_LINE=$((target_line))
    local found_block_line=false

    while [ "$BLOCK_LINE" -ge 1 ]; do
        local line_index=$((BLOCK_LINE-1))
        if [[ "${FILE_CONTENT[$line_index]}" =~ ^[[:space:]]*(local|resource|data|module)[[:space:]] ]]; then
            found_block_line=true
            break
        fi
        ((BLOCK_LINE--))
    done

    if [ "$found_block_line" = false ]; then
        BLOCK_LINE=$target_line
    fi

    echo "$BLOCK_LINE"
}

insert_ignore() {
    echo "[DEBUG] insert_ignore() called with ${#CURRENT_FILES[@]} file candidates and CHECK_ID=$CHECK_ID"
    if [ -z "$CHECK_ID" ] || [ ${#CURRENT_FILES[@]} -eq 0 ]; then
        echo "[DEBUG] No CHECK_ID or no file candidates, skipping."
        CURRENT_FILES=()
        CURRENT_LINES=()
        CHECK_ID=""
        return
    fi

    choose_file_and_line
    if [ -z "$TARGET_FILE" ]; then
        echo "[WARN] No valid file found for CHECK_ID=$CHECK_ID. Skipping insertion."
        CURRENT_FILES=()
        CURRENT_LINES=()
        CHECK_ID=""
        return
    fi

    IGNORE_COMMENT="#tfsec:ignore:$CHECK_ID"
    BLOCK_LINE="$(find_block_line "$TARGET_FILE" "$TARGET_LINE")"

    # Store this insertion as "file:line:comment"
    insertions+=("$TARGET_FILE:$BLOCK_LINE:$IGNORE_COMMENT")

    CURRENT_FILES=()
    CURRENT_LINES=()
    CHECK_ID=""
}

while IFS= read -r line; do
    if [[ "$line" =~ ([^[:space:]]+\.tf):([0-9]+) ]]; then
        FILE="${BASH_REMATCH[1]}"
        LINE="${BASH_REMATCH[2]}"
        echo "[DEBUG] Found FILE=$FILE LINE=$LINE"
        CURRENT_FILES+=("$FILE")
        CURRENT_LINES+=("$LINE")
    fi

    if [[ "$line" =~ ^[[:space:]]*ID[[:space:]]+([A-Za-z0-9_-]+) ]]; then
        CHECK_ID="${BASH_REMATCH[1]}"
        echo "[DEBUG] Found CHECK_ID=$CHECK_ID"
        insert_ignore
    fi
done <<< "$OUTPUT"

if [ -n "$CHECK_ID" ] || [ ${#CURRENT_FILES[@]} -gt 0 ]; then
    insert_ignore
fi

echo "[INFO] All findings processed. Now performing insertions."

# Process insertions file-by-file
if [ ${#insertions[@]} -gt 0 ]; then
    sorted_inserts=($(printf "%s\n" "${insertions[@]}" | sort -t: -k1,1 -k2,2nr))

    for insertion in "${sorted_inserts[@]}"; do
        IFS=":" read -r file line comment <<< "$insertion"
        echo "[INFO] Inserting comment into $file at line $line"

        TMP_FILE=$(mktemp)
        awk -v INS="$comment" -v L="$line" 'NR==L {print INS} {print}' "$file" > "$TMP_FILE"
        mv "$TMP_FILE" "$file"
    done
else
    echo "[INFO] No findings to insert."
fi

echo "[INFO] Completed processing tfsec results."

