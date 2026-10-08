#!/usr/bin/env bash

# The palette for what else takes one: ghostty, niri and fuzzel, each from a
# file its configuration includes, kept out of git.
#   palette-apply.sh [name=color ...] [ghostty=theme]
# The colors are Theme's, as #rrggbb. With none the files are emptied, which
# leaves each configuration its own colors.

for pair in "$@"; do
    [[ ${pair%%=*} =~ ^[a-z0-9]+$ ]] && declare "c_${pair%%=*}=${pair#*=}"
done

config=${XDG_CONFIG_HOME:-$HOME/.config}
ghostty=$config/ghostty/palette
niri=$config/niri/palette.kdl
fuzzel=$config/fuzzel/palette.ini

if [ $# -eq 0 ]; then
    : > "$ghostty"
    : > "$niri"
    : > "$fuzzel"
else
    printf 'theme = %s\n' "$c_ghostty" > "$ghostty"

    cat > "$niri" <<KDL
layout {
    focus-ring {
        active-gradient from="$c_sapphire" to="$c_green" angle=45 relative-to="window"
        inactive-color "${c_base}b3"
    }
    shadow {
        color "${c_teal}8c"
    }
}
recent-windows {
    highlight {
        active-color "$c_sapphire"
        urgent-color "$c_red"
    }
}
KDL

    cat > "$fuzzel" <<INI
[colors]
prompt=${c_green#\#}ff
input=${c_text#\#}ff
background=${c_base#\#}ff
text=${c_subtext0#\#}ff
match=${c_teal#\#}ff
selection=${c_surface0#\#}ff
selection-text=${c_sapphire#\#}ff
selection-match=${c_mauve#\#}ff
border=${c_teal#\#}ff
counter=${c_mauve#\#}ff
INI
fi

# Open terminals take the theme at once; fuzzel reads its file when started.
pkill -USR2 ghostty
niri msg action load-config-file
