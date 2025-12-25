#!/bin/sh

die() {
  printf "\33[2K\r\033[1;31m%s\033[0m\n" "$*" >&2
  exit 1
}

dep_ch() {
  for dep; do
    command -v "${dep%% *}" >/dev/null || die "Program \"${dep%% *}\" not found. Please install it."
  done
}

# SCRAPING

get_links() {
  response="$(curl -e "$allanime_refr" -s "https://${allanime_base}$*" -A "$agent")"
  episode_link="$(printf '%s' "$response" | sed 's|},{|\
|g' | sed -nE 's|.*link":"([^"]*)".*"resolutionStr":"([^"]*)".*|\2 >\1|p;s|.*hls","url":"([^"]*)".*"hardsub_lang":"en-US".*|\1|p')"

  case "$episode_link" in
  *repackager.wixmp.com*)
    extract_link=$(printf "%s" "$episode_link" | cut -d'>' -f2 | sed 's|repackager.wixmp.com/||g;s|\.urlset.*||g')
    for j in $(printf "%s" "$episode_link" | sed -nE 's|.*/,([^/]*),/mp4.*|\1|p' | sed 's|,|\
|g'); do
      printf "%s >%s\n" "$j" "$extract_link" | sed "s|,[^/]*|${j}|g"
    done | sort -nr
    ;;
  *master.m3u8*)
    m3u8_refr=$(printf '%s' "$response" | sed -nE 's|.*Referer":"([^"]*)".*|\1|p')
    extract_link=$(printf "%s" "$episode_link" | head -1 | cut -d'>' -f2)
    relative_link=$(printf "%s" "$extract_link" | sed 's|[^/]*$||')
    m3u8_streams="$(curl -e "$m3u8_refr" -s "$extract_link" -A "$agent")"
    printf "%s" "$m3u8_streams" | grep -q "EXTM3U" && printf "%s" "$m3u8_streams" | sed 's|^#EXT-X-STREAM.*x||g; s|,.*|p|g; /^#/d; $!N; s|\n| >|;/EXT-X-I-FRAME/d' |
      sed "s|>|cc>${relative_link}|g" | sort -nr
    ;;
  *) [ -n "$episode_link" ] && printf "%s\n" "$episode_link" ;;
  esac
}

provider_init() {
  provider_name=$1
  provider_id=$(printf "%s" "$resp" | sed -n "$2" | head -1 | cut -d':' -f2 | sed 's/../&\
/g' | sed 's/^79$/A/g;s/^7a$/B/g;s/^7b$/C/g;s/^7c$/D/g;s/^7d$/E/g;s/^7e$/F/g;s/^7f$/G/g;s/^70$/H/g;s/^71$/I/g;s/^72$/J/g;s/^73$/K/g;s/^74$/L/g;s/^75$/M/g;s/^76$/N/g;s/^77$/O/g;s/^68$/P/g;s/^69$/Q/g;s/^6a$/R/g;s/^6b$/S/g;s/^6c$/T/g;s/^6d$/U/g;s/^6e$/V/g;s/^6f$/W/g;s/^60$/X/g;s/^61$/Y/g;s/^62$/Z/g;s/^59$/a/g;s/^5a$/b/g;s/^5b$/c/g;s/^5c$/d/g;s/^5d$/e/g;s/^5e$/f/g;s/^5f$/g/g;s/^50$/h/g;s/^51$/i/g;s/^52$/j/g;s/^53$/k/g;s/^54$/l/g;s/^55$/m/g;s/^56$/n/g;s/^57$/o/g;s/^48$/p/g;s/^49$/q/g;s/^4a$/r/g;s/^4b$/s/g;s/^4c$/t/g;s/^4d$/u/g;s/^4e$/v/g;s/^4f$/w/g;s/^40$/x/g;s/^41$/y/g;s/^42$/z/g;s/^08$/0/g;s/^09$/1/g;s/^0a$/2/g;s/^0b$/3/g;s/^0c$/4/g;s/^0d$/5/g;s/^0e$/6/g;s/^0f$/7/g;s/^00$/8/g;s/^01$/9/g;s/^15$/-/g;s/^16$/./g;s/^67$/_/g;s/^46$/~/g;s/^02$/:/g;s/^17$/\//g;s/^07$/?/g;s/^1b$/#/g;s/^63$/\[/g;s/^65$/\]/g;s/^78$/@/g;s/^19$/!/g;s/^1c$/$/g;s/^1e$/&/g;s/^10$/\(/g;s/^11$/\)/g;s/^12$/*/g;s/^13$/+/g;s/^14$/,/g;s/^03$/;/g;s/^05$/=/g;s/^1d$/%/g' | tr -d '\n' | sed "s/\/clock/\/clock\.json/")
}

generate_link() {
  case $1 in
  1) provider_init "wixmp" "/Default :/p" ;;
  2) provider_init "youtube" "/Yt-mp4 :/p" ;;
  3) provider_init "sharepoint" "/S-mp4 :/p" ;;
  *) provider_init "hianime" "/Luf-Mp4 :/p" ;;
  esac
  [ -n "$provider_id" ] && get_links "$provider_id"
}

select_quality() {
  result=$(printf "%s" "$links" | head -n1)
  [ -z "$result" ] && die "No links found!"
  episode=$(printf "%s" "$result" | cut -d'>' -f2)
}

get_episode_url() {
  episode_embed_gql='query ($showId: String!, $translationType: VaildTranslationTypeEnumType!, $episodeString: String!) { episode( showId: $showId translationType: $translationType episodeString: $episodeString ) { episodeString sourceUrls }}'

  resp=$(curl -e "$allanime_refr" -s -G "${allanime_api}/api" --data-urlencode "variables={\"showId\":\"$id\",\"translationType\":\"sub\",\"episodeString\":\"$ep_no\"}" --data-urlencode "query=$episode_embed_gql" -A "$agent" | tr '{}' '\n' | sed 's|\\u002F|\/|g;s|\\||g' | sed -nE 's|.*sourceUrl":"--([^"]*)".*sourceName":"([^"]*)".*|\2 :\1|p')
  cache_dir="$(mktemp -d)"
  providers="1 2 3 4"
  for provider in $providers; do
    generate_link "$provider" >"$cache_dir"/"$provider" &
  done
  wait
  links=$(cat "$cache_dir"/* | sort -g -r -s)
  rm -r "$cache_dir"
  select_quality
}

search_anime() {
  search_gql='query( $search: SearchInput $limit: Int $page: Int $translationType: VaildTranslationTypeEnumType $countryOrigin: VaildCountryOriginEnumType ) { shows( search: $search limit: $limit page: $page translationType: $translationType countryOrigin: $countryOrigin ) { edges { _id name availableEpisodes __typename } }}'

  curl -e "$allanime_refr" -s -G "${allanime_api}/api" --data-urlencode "variables={\"search\":{\"allowAdult\":false,\"allowUnknown\":false,\"query\":\"$1\"},\"limit\":40,\"page\":1,\"translationType\":\"sub\",\"countryOrigin\":\"ALL\"}" --data-urlencode "query=$search_gql" -A "$agent" | sed 's|Show|\
| g' | sed -nE "s|.*_id\":\"([^\"]*)\",\"name\":\"(.+)\",.*sub\":([1-9][^,]*).*|\1	\2 (\3 episodes)|p" | sed 's/\\"//g'
}

episodes_list() {
  episodes_list_gql='query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}'

  curl -e "$allanime_refr" -s -G "${allanime_api}/api" --data-urlencode "variables={\"showId\":\"$*\"}" --data-urlencode "query=$episodes_list_gql" -A "$agent" | sed -nE "s|.*sub\":\[([0-9.\",]*)\].*|\1|p" | sed 's|,|\
|g; s|"||g' | sort -n -k 1
}

# MAIN

agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
allanime_refr="https://allmanga.to"
allanime_base="allanime.day"
allanime_api="https://api.${allanime_base}"

printf "\033[1;34mChecking dependencies...\033[0m\n"
dep_ch "curl" "sed" "grep" "fzf"

# Get search query
while [ -z "$query" ]; do
  printf "\033[1;36mSearch anime: \033[0m" && read -r query
done

query=$(printf "%s" "$query" | sed "s| |+|g")
anime_list=$(search_anime "$query")
[ -z "$anime_list" ] && die "No results found!"

# Select anime
result=$(printf "%s" "$anime_list" | nl -w 2 | sed 's/^[[:space:]]//' | fzf --reverse --cycle --prompt "Select anime: ")
[ -z "$result" ] && exit 1

title=$(printf "%s" "$result" | cut -f3)
id=$(printf "%s" "$result" | cut -f2)
ep_list=$(episodes_list "$id")

# Create output file
safe_title=$(printf "%s" "$title" | sed 's/([^)]*)//g' | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/^ *//;s/ *$//' | tr ' ' '_')
output_file="${safe_title}.txt"
: >"$output_file"

printf "\033[1;32mFetching URLs for all episodes...\033[0m\n"
printf "\033[1;32mWriting to: %s\033[0m\n\n" "$output_file"

# Get all episode URLs
for ep_no in $ep_list; do
  printf "Fetching episode %s...\n" "$ep_no"
  get_episode_url
  printf "%s\n" "$episode" >>"$output_file"
  unset episode
done

printf "\n\033[1;32mDone! URLs saved to: %s\033[0m\n" "$output_file"
exit 0
