#!/bin/bash


MP3_KBPS=96
SHOW_AUTHOR="Feinkost Internet"
EPISODE_SUMMARY="Letzte Feinkost vor dem Internet"
ARTWORK_JPG_FILENAME="./assets/logo-3000x3000.jpg"

episode_number=$1

if ! command -v "lame" > /dev/null || ! command -v "sox" > /dev/null; then
  echo "Required tools:"
  echo "- lame"
  echo "- sox"
  echo ""
  echo "Install:"
  echo "brew install lame sox"
  exit 1
fi

if [[ "$episode_number" = "" ]]; then
  echo "Usage: bin/mixdown.sh <episode-number>"
  echo ""
  echo "Example"
  echo ""
  echo "bin/mixdown.sh 0001"
  exit 1
fi

slug="fki${episode_number}"
dir="data/$slug"



file_mixed="${dir}/${slug}-mixed.wav"
file_trimed="${dir}/${slug}-trimed.wav"
file_final="${dir}/${slug}.mp3"

tracks_dir="${dir}/tracks"
tmp_dir="${dir}/tmp"

if [[ "$(ls $tracks_dir 2> /dev/null | grep '\.mp3$')" = "" ]]; then
  echo "No tracks found!"
  exit 1
fi
soxCmd() {
  sox --show-progress --multi-threaded -V2 $*
}

trim() {
  fileIn="$1"
  fileOut="$2"
  
  open "$fileIn"

  printf "Start: "
  read start

  printf "length: "
  read length

  sox "${fileIn}" "${fileOut}" trim "$start" "$length"
  
  open "$fileOut"
  
  printf "Done? [y|n]: "
  read isDone

  if [[ "$isDone" != "y" ]]; then
    trim "$fileIn" "$fileOut"
  fi
}

tracks=($(ls "${tracks_dir}" | grep '\.mp3$'))

rm -rf "${tmp_dir}"
mkdir -p "${tmp_dir}"

for track_file_name in ${tracks[@]}; do
  track=${track_file_name%%.mp3}
  
  echo "${track}"
  
  track_file="${tracks_dir}/${track_file_name}"
  track_out_file="${tmp_dir}/${track}.wav"
  noise_file="${tmp_dir}/${track}-noise.wav"
  prof_file="${tmp_dir}/${track}.prof"

  soxCmd "${track_file}" "${noise_file}" trim 0 3
  soxCmd "${noise_file}" -n noiseprof "${prof_file}"
  soxCmd --norm "${track_file}" "${track_out_file}" noisered "${prof_file}" 0.21
  
  rm "$noise_file"
  rm "$prof_file"
done

soxCmd --combine mix "$(find "${tmp_dir}" -maxdepth 1 -print | grep '\.wav$')" "${file_mixed}"

trim "${file_mixed}" "${file_trimed}"

printf "Title: FKI$episode_number - "
read episode_title


if [[ -f "${file_final}" ]]; then
  echo "file exists"
  exit 1
fi

lame \
  --noreplaygain \
  --cbr -h -b $MP3_KBPS \
  --resample 44.1 \
  --tt "FKI$episode_number - $episode_title" \
  --tc "$EPISODE_SUMMARY" \
  --ta "$SHOW_AUTHOR" \
  --tl "$SHOW_AUTHOR" \
  --ty `date '+%Y'` \
  --ti "$ARTWORK_JPG_FILENAME" \
  --add-id3v2 "${file_trimed}" "${file_final}"

mkdir -p "${tmp_dir}/"