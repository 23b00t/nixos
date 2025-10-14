p() {
  case "$1" in
    -h)
      echo "Usage:"
      echo "  p file.txt         # upload (paste.rs)"
      echo "  echo hi | p        # upload from stdin (paste.rs)"
      echo "  p -g <id> [ext]    # get paste by id (paste.rs)"
      echo "  p -d <id>          # delete paste by id (paste.rs)"
      echo "  p -h               # show this help message"
      return 0
      ;;
    -g)
      local id="$2"
      local ext="${3:-}"
      if [ -z "$id" ]; then
        echo "Usage: p -g <id> [ext]" >&2
        return 1
      fi
      curl -s "https://paste.rs/${id}${ext:+.$ext}"
      ;;
    -d)
      local id="$2"
      if [ -z "$id" ]; then
        echo "Usage: p -d <id>" >&2
        return 1
      fi
      curl -X DELETE "https://paste.rs/$id"
      ;;
    *)
      local file="${1:-/dev/stdin}"
      curl --data-binary @"$file" https://paste.rs
      ;;
  esac
}

p0x0() {
  # Usage:
  #   p0x0 file.png                # upload
  #   p0x0 -g <url>                # copy remote file
  #   p0x0 -d <token> <filename>   # delete
  case "$1" in
    -g)
      local url="$2"
      if [ -z "$url" ]; then
        echo "Usage: p0x0 -g <url>" >&2
        return 1
      fi
      curl -H 'User-Agent: fnord' -F"url=$url" https://0x0.st
      ;;
    -d)
      local token="$2"
      local filename="$3"
      if [ -z "$token" ] || [ -z "$filename" ]; then
        echo "Usage: p0x0 -d <token> <filename>" >&2
        return 1
      fi
      curl -H 'User-Agent: fnord' -F"token=$token" -F"delete=" "https://0x0.st/$filename"
      ;;
    *)
      local file="$1"
      if [ -z "$file" ]; then
        echo "Usage: p0x0 <file>" >&2
        return 1
      fi
      curl -H 'User-Agent: fnord' -F"file=@$file" https://0x0.st
      ;;
  esac
}

puguu() {
  # Usage: puguu file1 [file2 ...]
  if [ "$#" -eq 0 ]; then
    echo "Usage: puguu file1 [file2 ...]" >&2
    return 1
  fi
  local args=()
  for f in "$@"; do
    if [ ! -r "$f" ]; then
      echo "File not found or not readable: $f" >&2
      return 2
    fi
    args+=(-F "files[]=@$f")
  done
  curl -s "${args[@]}" https://uguu.se/upload
}
