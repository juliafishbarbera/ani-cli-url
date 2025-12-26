## what this does

this is a **stripped-down version** of ani-cli that:

1. searches for anime
2. lets you select from results
3. fetches urls for **all episodes**
4. either saves them to a text file OR downloads them directly

**what was removed:**

- video playback
- history tracking
- continue watching
- quality selection
- episode selection
- dub mode
- all extra features and options

**what was added:**

- direct episode downloading with aria2c (new feature!)

## install

### dependencies

install these

- `curl` - for fetching data
- `sed` - for text processing
- `grep` - for pattern matching
- `fzf` - for the selection menu
- `aria2c` - **required only for download mode** (-d/--download)

## usage

### basic mode (save URLs to file)

run:

```sh
ani-cli.sh
```

then:

1. type the anime name when prompted
2. select the anime from the list (use arrow keys, press enter)
3. wait for all episode urls to be fetched
4. urls are saved to `anime_name.txt` in your current directory

### download mode (download episodes directly - Jellyfin compatible!)

run:

```sh
ani-cli.sh -d                        # Season 01 (default)
ani-cli.sh -d -s 2                   # Season 02
ani-cli.sh --download --season 3     # Season 03
```

then:

1. type the anime name when prompted
2. select the anime from the list (use arrow keys, press enter)
3. wait for all episodes to be downloaded
4. episodes are saved in **Jellyfin-compatible structure**:
   - Directory: `Show Name/Season 01/`
   - Filenames: `Show Name S01E01.mp4`, `Show Name S01E02.mp4`, etc.

### help

```sh
ani-cli.sh --help
```

### example

#### basic mode (save URLs)

```sh
$ ./ani-cli.sh
checking dependencies...
search anime: nekopara
# select from list using fzf
fetching urls for all episodes...
writing to: nekopara.txt

fetching episode 1...
fetching episode 2...
...
fetching episode 12...

done! urls saved to: nekopara.txt
```

the output file will contain one url per line:

```
https://example.com/episode1.m3u8
https://example.com/episode2.m3u8
https://example.com/episode3.m3u8
...
```

#### download mode (Jellyfin compatible)

```sh
$ ./ani-cli.sh -d
checking dependencies...
search anime: no game no life
# select from list using fzf
downloading episodes to directory: No Game No Life/Season 01

fetching episode 1...
Downloading episode 1 to No Game No Life/Season 01/No Game No Life S01E01.mp4...
✓ Successfully downloaded episode 1

fetching episode 2...
Downloading episode 2 to No Game No Life/Season 01/No Game No Life S01E02.mp4...
✓ Successfully downloaded episode 2
...

done! episodes downloaded to: No Game No Life/Season 01
```

**Jellyfin-compatible structure:**
- Directory: `No Game No Life/Season 01/`
- Episodes: `No Game No Life S01E01.mp4`, `No Game No Life S01E02.mp4`, etc.
- Season 2: `No Game No Life/Season 02/No Game No Life S02E01.mp4`

## uninstall

**linux/mac:**

```sh
sudo rm /usr/local/bin/ani-cli
```

**android (termux):**

```sh
rm $prefix/bin/ani-cli
```

**windows:**

```sh
rm "$(which ani-cli)"
```

## troubleshooting

- **"no results found"**: make sure you spelled the anime name correctly
- **"program not found"**: install the missing dependency (aria2c is only needed for download mode)
- **slow fetching**: this is normal, especially for anime with many episodes.
  the script fetches each episode sequentially.
- **download failures**: aria2c will retry failed downloads. check your internet connection and available disk space.
- **invalid urls**: the source site may have changed. check for updates or
  report an issue.
- **permission denied**: make sure you have write permissions in the current directory for creating download folders.

## original project

this is based on the full-featured
[ani-cli](https://github.com/pystardust/ani-cli) project. if you want to
actually watch anime in your terminal go there
