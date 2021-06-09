#!/bin/bash

upload_url=https://api.tempfiles.download/upload/
screenshot_path=~/Pictures/Screenshots
screenshot_name="screenshot_$(date +%s).png"
remove=false

error() {
  notify-send "$1"
  exit 1
}

[[ -d "$screenshot_path" ]] || mkdir "$screenshot_path"
full_path="$screenshot_path/$screenshot_name"
[[ "$1" == "window" ]] && import -window root "$full_path" || import "$full_path"

data=$(curl -s -X "POST" -F "file=@$full_path" "$upload_url")

if [ -f "$full_path" ]; then
  [[ "$remove" == true ]] && rm "$full_path"
else
  error "Error creating screenshot."
fi

[[ -n "$data" ]] && url=$(echo "$data" | jq -r .url) || error "No response from TempFiles"

echo "$url" | xclip -selection clipboard

notify-send "Screenshot URL copied!"
exit 0
