#!/usr/bin/env python3
"""Migrate only the stock matugen color template, preserving other sections."""
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
old = """[templates.waybar]
input_path = '~/.config/matugen/templates/waybar.css'
output_path = '~/.config/waybar/colors.css'
post_hook = 'setsid -f $HOME/.local/bin/waybar-reload'"""
new = """[templates.rice_colors]
input_path = '~/.config/matugen/templates/rice-colors.css'
output_path = '~/.config/rice/colors.css'"""
if text.count(old) != 1 or re.search(r'^\[templates\.rice_colors\]', text, re.M):
    sys.exit(1)
print(text.replace(old, new), end="")
