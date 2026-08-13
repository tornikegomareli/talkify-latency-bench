#!/bin/zsh

set -euo pipefail

tool_directory="${0:A:h}"
output_directory="$tool_directory/dist"
output_file="$output_directory/stimulus-neutral.aiff"
phrase="Fast speech to text should feel instant."

mkdir -p "$output_directory"
say -v Samantha -r 175 -o "$output_file" "$phrase"
print "$output_file"
