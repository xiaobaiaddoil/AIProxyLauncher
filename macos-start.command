#!/bin/bash
set -eu

cd "$(dirname "$0")"
trap 'printf "\n按回车关闭窗口。\n"; read -r _ || true' ERR

if [[ "$(uname -s)" != Darwin ]]; then
    printf '请在 macOS 上运行此启动文件。\n' >&2
    exit 1
fi

python=""
for candidate in /Library/Frameworks/Python.framework/Versions/3.*/bin/python3 \
        /opt/homebrew/bin/python3 /usr/local/bin/python3 "$(command -v python3 || true)"; do
    if [[ -x "$candidate" ]] && "$candidate" -c 'import sys, tkinter; assert sys.version_info >= (3, 11)' 2>/dev/null; then
        python="$candidate"
        break
    fi
done
if [[ -z "$python" ]]; then
    printf '请先从 https://www.python.org/downloads/macos/ 安装带 Tk 的 Python 3.11 或更新版本。\n' >&2
    printf '按回车关闭窗口。\n'
    read -r _ || true
    exit 1
fi

"$python" -B launcher.py "$@"
