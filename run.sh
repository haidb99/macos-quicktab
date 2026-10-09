#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
open "$PWD/dist/QuickTab.app"
echo 'QuickTab is running in the menu bar. Open Settings to review Accessibility and Screen Recording permissions.'
