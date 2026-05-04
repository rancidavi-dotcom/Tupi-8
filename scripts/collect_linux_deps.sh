#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "uso: $0 <binario> <destino>" >&2
    exit 1
fi

binary="$1"
dest_dir="$2"

if [[ ! -f "$binary" ]]; then
    echo "[deps] binario nao encontrado: $binary" >&2
    exit 1
fi

mkdir -p "$dest_dir"

declare -a queue
declare -A seen
declare -A copied

queue+=("$(readlink -f "$binary")")

should_skip_lib() {
    local name="$1"

    case "$name" in
        linux-vdso.so.*|linux-gate.so.*|linux-vsyscall.so.*)
            return 0
            ;;
        ld-linux*.so*|ld-musl-*.so*|libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|libresolv.so.*|libutil.so.*|libanl.so.*)
            return 0
            ;;
        "")
            return 0
            ;;
    esac

    return 1
}

extract_ldd_paths() {
    local target="$1"

    ldd "$target" 2>/dev/null | awk '
        /=>/ {
            if ($3 ~ /^\//) {
                print $3
            }
            next
        }
        /^\// {
            print $1
        }
    '
}

enqueue_target() {
    local target
    target="$(readlink -f "$1")"

    if [[ -z "${seen[$target]+x}" ]]; then
        seen["$target"]=1
        queue+=("$target")
    fi
}

for seed in "${queue[@]}"; do
    seen["$seed"]=1
done

for ((i = 0; i < ${#queue[@]}; i++)); do
    current="${queue[$i]}"

    while IFS= read -r dep; do
        [[ -n "$dep" ]] || continue
        [[ -f "$dep" ]] || continue

        dep="$(readlink -f "$dep")"
        dep_name="$(basename "$dep")"

        if should_skip_lib "$dep_name"; then
            continue
        fi

        if [[ -z "${copied[$dep_name]+x}" ]]; then
            cp -L "$dep" "$dest_dir/$dep_name"
            copied["$dep_name"]="$dep"
            printf '[deps] bundled: %s\n' "$dep_name"
        fi

        enqueue_target "$dep"
    done < <(extract_ldd_paths "$current")
done
