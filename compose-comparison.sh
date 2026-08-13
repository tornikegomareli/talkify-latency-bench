#!/bin/zsh

set -euo pipefail

if (( $# != 7 && $# != 9 )); then
  print -u2 "Usage: compose-comparison.sh <talkify.mov> <competitor.mov> <competitor-name> <talkify-offset> <competitor-offset> <duration> <output-prefix> [talkify-ms competitor-ms]"
  exit 64
fi

talkify_video="$1"
competitor_video="$2"
competitor_name="$3"
talkify_offset="$4"
competitor_offset="$5"
duration="$6"
output_prefix="$7"
talkify_result="${8:-}"
competitor_result="${9:-}"
ffmpeg_binary="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"
font_file="/System/Library/Fonts/SFNS.ttf"

mkdir -p "${output_prefix:h}"

common_filter="setpts=PTS-STARTPTS,fps=60"
left_label="drawtext=fontfile='$font_file':text='Talkify':fontcolor=white:fontsize=42:x=36:y=30:box=1:boxcolor=black@0.62:boxborderw=16"
right_label="drawtext=fontfile='$font_file':text='$competitor_name':fontcolor=white:fontsize=42:x=36:y=30:box=1:boxcolor=black@0.62:boxborderw=16"

if [[ -n "$talkify_result" && -n "$competitor_result" ]]; then
  if [[ ! "$talkify_result" =~ '^[0-9]+$' || ! "$competitor_result" =~ '^[0-9]+$' ]]; then
    print -u2 "Latency labels must be whole milliseconds."
    exit 65
  fi
  left_label+=",drawtext=fontfile='$font_file':text='$talkify_result ms':fontcolor=white:fontsize=76:x=36:y=110"
  right_label+=",drawtext=fontfile='$font_file':text='$competitor_result ms':fontcolor=white:fontsize=76:x=36:y=110"
fi

"$ffmpeg_binary" -hide_banner -loglevel error -y \
  -ss "$talkify_offset" -i "$talkify_video" \
  -ss "$competitor_offset" -i "$competitor_video" \
  -filter_complex \
  "[0:v]${common_filter},scale=960:1080:force_original_aspect_ratio=decrease,pad=960:1080:(ow-iw)/2:(oh-ih)/2,${left_label}[left];[1:v]${common_filter},scale=960:1080:force_original_aspect_ratio=decrease,pad=960:1080:(ow-iw)/2:(oh-ih)/2,${right_label}[right];[left][right]hstack=inputs=2[out]" \
  -map "[out]" -t "$duration" -an -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p \
  "${output_prefix}-landscape.mp4"

"$ffmpeg_binary" -hide_banner -loglevel error -y \
  -ss "$talkify_offset" -i "$talkify_video" \
  -ss "$competitor_offset" -i "$competitor_video" \
  -filter_complex \
  "[0:v]${common_filter},scale=1080:960:force_original_aspect_ratio=decrease,pad=1080:960:(ow-iw)/2:(oh-ih)/2,${left_label}[top];[1:v]${common_filter},scale=1080:960:force_original_aspect_ratio=decrease,pad=1080:960:(ow-iw)/2:(oh-ih)/2,${right_label}[bottom];[top][bottom]vstack=inputs=2[out]" \
  -map "[out]" -t "$duration" -an -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p \
  "${output_prefix}-vertical.mp4"
