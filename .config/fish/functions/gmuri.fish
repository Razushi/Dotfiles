function gmuri
set -l file_path (wl-paste)

python3 -c 'import sys, pathlib; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$file_path" | wl-copy
end
