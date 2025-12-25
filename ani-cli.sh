#!/bin/sh

version_number="4.10.4"

# UI

external_menu() {
  rofi "$1" -sort -dmenu -i -width 1500 -p "$2" "$3"
}

launcher() {
  [ "$use_external_menu" = "0" ] && [ -z "$1" ] && set -- "+m" "$2"
  [ "$use_external_menu" = "0" ] && fzf "$1" --reverse --cycle --prompt "$2"
  [ "$use_external_menu" = "1" ] && external_menu "$1" "$2" "$external_menu_args"
}

nth() {
  stdin=$(cat -)
  [ -z "$stdin" ] && return 1
  line_count="$(printf "%s\n" "$stdin" | wc -l | tr -d "[:space:]")"
  [ "$line_count" -eq 1 ] && printf "%s" "$stdin" | cut -f2,3 && return 0
  prompt="$1"
  multi_flag=""
  [ $# -ne 1 ] && shift && multi_flag="$1"
  line=$(printf "%s" "$stdin" | cut -f1,3 | tr '\t' ' ' | launcher "$multi_flag" "$prompt" | cut -d " " -f 1)
  line_start=$(printf "%s" "$line" | head -n1)
  line_end=$(printf "%s" "$line" | tail -n1)
  [ -n "$line" ] || exit 1
  if [ "$line_start" = "$line_end" ]; then
    printf "%s" "$stdin" | grep -E '^'"${line}"'($|[[:space:]])' | cut -f2,3 || exit 1
  else
    printf "%s" "$stdin" | sed -n '/^'"${line_start}"'$/,/^'"${line_end}$"'/p' || exit 1
  fi
}

die() {
  printf "\33[2K\r\033[1;31m%s\033[0m\n" "$*" >&2
  exit 1
}

help_info() {
  printf "
    Usage:
    %s [options] [query]
    %s [query] [options]
    %s [options] [query] [options]

    Options:
      -c, --continue
        Continue watching from history
      -u, --url
        Print the video URL instead of playing
      -D, --delete
        Delete history
      -l, --logview
        Show logs
      -S, --select-nth
        Select nth entry
      -q, --quality
        Specify the video quality
      -V, --version
        Show the version of the script
      -h, --help
        Show this help message and exit
      -e, --episode, -r, --range
        Specify the number of episodes to watch
      --dub
        Play dubbed version
      --rofi
        Use rofi instead of fzf for the interactive menu
      -N, --nextep-countdown
        Display a countdown to the next episode
      -U, --update
        Update the script
    Some example usages:
      %s -q 720p banana fish
      %s -u -e 2 cyberpunk edgerunners
      %s -u cyberpunk edgerunners -q 1080p -e 4
    \n" "${0##*/}" "${0##*/}" "${0##*/}" "${0##*/}" "${0##*/}" "${0##*/}"
  exit 0
}

version_info() {
  printf "%s\n" "$version_number"
  exit 0
}

update_script() {
  update="$(curl -s -A "$agent" "https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli")" || die "Connection error"
  update="$(printf '%s\n' "$update" | diff -u "$0" -)"
  if [ -z "$update" ]; then
    printf "Script is up to date :)\n"
  else
    if printf '%s\n' "$update" | patch "$0" -; then
      printf "Script has been updated\n"
    else
      die "Can't update for some reason!"
    fi
  fi
  exit 0
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
    m3u8_refr=$(printf '%s' "$response" | sed -nE 's|.*Referer":"([^"]*)".*|\1|p') && printf '%s\n' "m3u8_refr >$m3u8_refr" >"$cache_dir/m3u8_refr"
    extract_link=$(printf "%s" "$episode_link" | head -1 | cut -d'>' -f2)
    relative_link=$(printf "%s" "$extract_link" | sed 's|[^/]*$||')
    m3u8_streams="$(curl -e "$m3u8_refr" -s "$extract_link" -A "$agent")"
    printf "%s" "$m3u8_streams" | grep -q "EXTM3U" && printf "%s" "$m3u8_streams" | sed 's|^#EXT-X-STREAM.*x||g; s|,.*|p|g; /^#/d; $!N; s|\n| >|;/EXT-X-I-FRAME/d' |
      sed "s|>|cc>${relative_link}|g" | sort -nr
    printf '%s' "$response" | sed -nE 's|.*"subtitles":\[\{"lang":"en","label":"English","default":"default","src":"([^"]*)".*|subtitle >\1|p' >"$cache_dir/suburl"
    ;;
  *) [ -n "$episode_link" ] && printf "%s\n" "$episode_link" ;;
  esac

  printf "%s" "$*" | grep -q "tools.fast4speed.rsvp" && printf "%s\n" "Yt >$*"
  printf "\033[1;32m%s\033[0m Links Fetched\n" "$provider_name" 1>&2
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
  case "$1" in
  best) result=$(printf "%s" "$links" | head -n1) ;;
  worst) result=$(printf "%s" "$links" | grep -E '^[0-9]{3,4}' | tail -n1) ;;
  *) result=$(printf "%s" "$links" | grep -m 1 "$1") ;;
  esac
  [ -z "$result" ] && printf "Specified quality not found, defaulting to best\n" 1>&2 && result=$(printf "%s" "$links" | head -n1)

  printf '%s' "$result" | grep -q "cc>" && subtitle="$(printf '%s' "$links" | sed -nE 's|subtitle >(.*)|\1|p')"
  printf '%s' "$result" | grep -q "cc>" && m3u8_refr="$(printf '%s' "$links" | sed -nE 's|m3u8_refr >(.*)|\1|p')"
  episode=$(printf "%s" "$result" | cut -d'>' -f2)
}

get_episode_url() {
  episode_embed_gql='query ($showId: String!, $translationType: VaildTranslationTypeEnumType!, $episodeString: String!) { episode( showId: $showId translationType: $translationType episodeString: $episodeString ) { episodeString sourceUrls }}'

  resp=$(curl -e "$allanime_refr" -s -G "${allanime_api}/api" --data-urlencode "variables={\"showId\":\"$id\",\"translationType\":\"$mode\",\"episodeString\":\"$ep_no\"}" --data-urlencode "query=$episode_embed_gql" -A "$agent" | tr '{}' '\n' | sed 's|\\u002F|\/|g;s|\\||g' | sed -nE 's|.*sourceUrl":"--([^"]*)".*sourceName":"([^"]*)".*|\2 :\1|p')
  cache_dir="$(mktemp -d)"
  providers="1 2 3 4"
  for provider in $providers; do
    generate_link "$provider" >"$cache_dir"/"$provider" &
  done
  wait
  links=$(cat "$cache_dir"/* | sort -g -r -s)
  rm -r "$cache_dir"
  select_quality "$quality"
  if printf "%s" "$ep_list" | grep -q "^$ep_no$"; then
    [ -z "$episode" ] && die "Episode is released, but no valid sources!"
  else
    [ -z "$episode" ] && die "Episode not released!"
  fi
}

search_anime() {
  search_gql='query( $search: SearchInput $limit: Int $page: Int $translationType: VaildTranslationTypeEnumType $countryOrigin: VaildCountryOriginEnumType ) { shows( search: $search limit: $limit page: $page translationType: $translationType countryOrigin: $countryOrigin ) { edges { _id name availableEpisodes __typename } }}'

  curl -e "$allanime_refr" -s -G "${allanime_api}/api" --data-urlencode "variables={\"search\":{\"allowAdult\":false,\"allowUnknown\":false,\"query\":\"$1\"},\"limit\":40,\"page\":1,\"translationType\":\"$mode\",\"countryOrigin\":\"ALL\"}" --data-urlencode "query=$search_gql" -A "$agent" | sed 's|Show|\
| g' | sed -nE "s|.*_id\":\"([^\"]*)\",\"name\":\"(.+)\",.*${mode}\":([1-9][^,]*).*|\1	\2 (\3 episodes)|p" | sed 's/\\"//g'
}

time_until_next_ep() {
  animeschedule="https://animeschedule.net"
  query="$(printf "%s\n" "$*" | tr ' ' '+')"
  curl -s -G "$animeschedule/api/v3/anime" --data "q=${query}" | sed 's|"id"|\n|g' | sed -nE 's|.*,"route":"([^"]*)","premier.*|\1|p' | while read -r anime; do
    data=$(curl -s "$animeschedule/anime/$anime" | sed '1,/"anime-header-list-buttons-wrapper"/d' | sed -nE 's|.*countdown-time-raw" datetime="([^"]*)">.*|Next Raw Release: \1|p;s|.*countdown-time" datetime="([^"]*)">.*|Next Sub Release: \1|p;s|.*english-title">([^<]*)<.*|English Title: \1|p;s|.*main-title".*>([^<]*)<.*|Japanese Title: \1|p')
    status="Ongoing"
    color="33"
    printf "%s\n" "$data"
    ! (printf "%s\n" "$data" | grep -q "Next Raw Release:") && status="Finished" && color="32"
    printf "Status:  \033[1;%sm%s\033[0m\n---\n" "$color" "$status"
  done
  exit 0
}

episodes_list() {
  episodes_list_gql='query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}'

  curl -e "$allanime_refr" -s -G "${allanime_api}/api" --data-urlencode "variables={\"showId\":\"$*\"}" --data-urlencode "query=$episodes_list_gql" -A "$agent" | sed -nE "s|.*$mode\":\[([0-9.\",]*)\].*|\1|p" | sed 's|,|\
|g; s|"||g' | sort -n -k 1
}

process_hist_entry() {
  ep_list=$(episodes_list "$id")
  latest_ep=$(printf "%s\n" "$ep_list" | tail -n1)
  title=$(printf "%s\n" "$title" | sed "s|[0-9]\+ episodes|${latest_ep} episodes|")
  ep_no=$(printf "%s" "$ep_list" | sed -n "/^${ep_no}$/{n;p;}") 2>/dev/null
  [ -n "$ep_no" ] && printf "%s\t%s - episode %s\n" "$id" "$title" "$ep_no"
}

update_history() {
  if grep -q -- "$id" "$histfile"; then
    sed -E "s|^[^	]+	${id}	[^	]+$|${ep_no}	${id}	${title}|" "$histfile" >"${histfile}.new"
  else
    cp "$histfile" "${histfile}.new"
    printf "%s\t%s\t%s\n" "$ep_no" "$id" "$title" >>"${histfile}.new"
  fi
  mv "${histfile}.new" "$histfile"
}

# MODIFIED: Print URL instead of playing
print_episode_url() {
  [ -z "$episode" ] && get_episode_url
  printf "\033[1;34mTitle:\033[0m %s\n" "$title"
  printf "\033[1;34mEpisode:\033[0m %s\n" "$ep_no"
  printf "\033[1;34mQuality:\033[0m %s\n" "$quality"
  printf "\033[1;34mURL:\033[0m %s\n" "$episode"
  [ -n "$subtitle" ] && printf "\033[1;34mSubtitle:\033[0m %s\n" "$subtitle"
  [ -n "$m3u8_refr" ] && printf "\033[1;34mReferer:\033[0m %s\n" "$m3u8_refr"
  unset episode
  update_history
}

print_url() {
  start=$(printf "%s" "$ep_no" | grep -Eo '^(-1|[0-9]+(\.[0-9]+)?)')
  end=$(printf "%s" "$ep_no" | grep -Eo '(-1|[0-9]+(\.[0-9]+)?)$')
  [ "$start" = "-1" ] && ep_no=$(printf "%s" "$ep_list" | tail -n1) && unset start
  [ -z "$end" ] || [ "$end" = "$start" ] && unset start end
  [ "$end" = "-1" ] && end=$(printf "%s" "$ep_list" | tail -n1)
  line_count=$(printf "%s\n" "$ep_no" | wc -l | tr -d "[:space:]")
  if [ "$line_count" != 1 ] || [ -n "$start" ]; then
    [ -z "$start" ] && start=$(printf "%s\n" "$ep_no" | head -n1)
    [ -z "$end" ] && end=$(printf "%s\n" "$ep_no" | tail -n1)
    range=$(printf "%s\n" "$ep_list" | sed -nE "/^${start}\$/,/^${end}\$/p")
    [ -z "$range" ] && die "Invalid range!"
    for i in $range; do
      ep_no=$i
      printf "\n"
      print_episode_url
    done
  else
    print_episode_url
  fi
}

# MAIN

agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
allanime_refr="https://allmanga.to"
allanime_base="allanime.day"
allanime_api="https://api.${allanime_base}"
mode="${ANI_CLI_MODE:-sub}"
quality="${ANI_CLI_QUALITY:-best}"
use_external_menu="${ANI_CLI_EXTERNAL_MENU:-0}"
external_menu_normal_window="${ANI_CLI_EXTERNAL_MENU_NORMAL_WINDOW:-0}"
[ -t 0 ] || use_external_menu=1
hist_dir="${ANI_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ani-cli}"
[ ! -d "$hist_dir" ] && mkdir -p "$hist_dir"
histfile="$hist_dir/ani-hsts"
[ ! -f "$histfile" ] && : >"$histfile"
search="${ANI_CLI_DEFAULT_SOURCE:-scrape}"
print_url_mode=0

while [ $# -gt 0 ]; do
  case "$1" in
  -q | --quality)
    [ $# -lt 2 ] && die "missing argument!"
    quality="$2"
    shift
    ;;
  -S | --select-nth)
    [ $# -lt 2 ] && die "missing argument!"
    index="$2"
    shift
    ;;
  -c | --continue) search=history ;;
  -u | --url) print_url_mode=1 ;;
  -D | --delete)
    : >"$histfile"
    exit 0
    ;;
  -l | --logview)
    case "$(uname -s)" in
    Darwin*) log show --predicate 'process == "logger"' ;;
    Linux*) journalctl -t ani-cli ;;
    *) die "Logger not implemented for your platform" ;;
    esac
    exit 0
    ;;
  -V | --version) version_info ;;
  -h | --help) help_info ;;
  -e | --episode | -r | --range)
    [ $# -lt 2 ] && die "missing argument!"
    ep_no="$2"
    shift
    ;;
  --dub) mode="dub" ;;
  --rofi) use_external_menu=1 ;;
  -N | --nextep-countdown) search=nextep ;;
  -U | --update) update_script ;;
  *) query="$(printf "%s" "$query $1" | sed "s|^ ||;s| |+|g")" ;;
  esac
  shift
done
[ "$use_external_menu" = "0" ] && multi_selection_flag="${ANI_CLI_MULTI_SELECTION:-"-m"}"
[ "$use_external_menu" = "1" ] && multi_selection_flag="${ANI_CLI_MULTI_SELECTION:-"-multi-select"}"
[ "$external_menu_normal_window" = "1" ] && external_menu_args="-normal-window"
printf "\33[2K\r\033[1;34mChecking dependencies...\033[0m\n"
dep_ch "curl" "sed" "grep" || true
dep_ch "fzf" || true

# searching
case "$search" in
history)
  anime_list=$(while read -r ep_no id title; do process_hist_entry & done <"$histfile")
  wait
  [ -z "$anime_list" ] && die "No unwatched series in history!"
  [ -z "${index##*[!0-9]*}" ] && id=$(printf "%s" "$anime_list" | nl -w 2 | sed 's/^[[:space:]]//' | nth "Select anime: " | cut -f1)
  [ -z "${index##*[!0-9]*}" ] || id=$(printf "%s" "$anime_list" | sed -n "${index}p" | cut -f1)
  [ -z "$id" ] && exit 1
  title=$(printf "%s" "$anime_list" | grep "$id" | cut -f2 | sed 's/ - episode.*//')
  ep_list=$(episodes_list "$id")
  ep_no=$(printf "%s" "$anime_list" | grep "$id" | cut -f2 | sed -nE 's/.*- episode (.+)$/\1/p')
  ;;
*)
  if [ "$use_external_menu" = "0" ]; then
    while [ -z "$query" ]; do
      printf "\33[2K\r\033[1;36mSearch anime: \033[0m" && read -r query
    done
  else
    [ -z "$query" ] && query=$(printf "" | external_menu "" "Search anime: " "$external_menu_args")
    [ -z "$query" ] && exit 1
  fi
  [ "$search" = "nextep" ] && time_until_next_ep "$query"

  query=$(printf "%s" "$query" | sed "s| |+|g")
  anime_list=$(search_anime "$query")
  [ -z "$anime_list" ] && die "No results found!"
  [ "$index" -eq "$index" ] 2>/dev/null && result=$(printf "%s" "$anime_list" | sed -n "${index}p")
  [ -z "$index" ] && result=$(printf "%s" "$anime_list" | nl -w 2 | sed 's/^[[:space:]]//' | nth "Select anime: ")
  [ -z "$result" ] && exit 1
  title=$(printf "%s" "$result" | cut -f2)
  id=$(printf "%s" "$result" | cut -f1)
  ep_list=$(episodes_list "$id")
  [ -z "$ep_no" ] && ep_no=$(printf "%s" "$ep_list" | nth "Select episode: " "$multi_selection_flag")
  [ -z "$ep_no" ] && exit 1
  ;;
esac

# Print URL instead of playing
print_url
exit 0
