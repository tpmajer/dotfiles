#!/usr/bin/env bash

# The palette for what else takes one, each from a file its configuration
# names, kept out of git: ghostty, niri, fuzzel, btop, helix, bat and micro.
#   palette-apply.sh [init] [name=color ...] [ghostty=theme btop=theme helix=theme]
# The colors are Theme's, as #rrggbb. With none it is Catppuccin Mocha, which
# the configurations and their themes have. `init` does nothing unless a
# file is missing: btop, helix, bat and micro have no theme without theirs.

init=
[ "$1" = init ] && init=1 && shift

for pair in "$@"; do
    [[ ${pair%%=*} =~ ^[a-z0-9]+$ ]] && declare "c_${pair%%=*}=${pair#*=}"
done

config=${XDG_CONFIG_HOME:-$HOME/.config}
ghostty=$config/ghostty/palette
niri=$config/niri/palette.kdl
fuzzel=$config/fuzzel/palette.ini
btop=$config/btop/themes/palette.theme
helix=$config/helix/themes/palette.toml
bat=$config/bat/themes/palette.tmTheme
micro=$config/micro/colorschemes/palette.micro

if [ -n "$init" ]; then
    missing=
    for file in "$ghostty" "$niri" "$fuzzel" "$btop" "$helix" "$bat" "$micro"; do
        [ -e "$file" ] || missing=1
    done
    [ -n "$missing" ] || exit 0
fi

# A file in Catppuccin Mocha's colors, in the palette's: for each of Mocha's
# the nearest that Theme has. 3e5767 is bat's own, a highlight.
recolor() {
    [ -n "$c_base" ] || { cat "$1"; return; }
    local program="" pair
    for pair in f5e0dc=$c_pink f2cdcd=$c_pink f5c2e7=$c_pink cba6f7=$c_mauve \
        f38ba8=$c_red eba0ac=$c_maroon fab387=$c_peach f9e2af=$c_yellow \
        a6e3a1=$c_green 94e2d5=$c_teal 89dceb=$c_sky 74c7ec=$c_sapphire \
        89b4fa=$c_blue b4befe=$c_lavender cdd6f4=$c_text bac2de=$c_subtext1 \
        a6adc8=$c_subtext0 9399b2=$c_subtext0 7f849c=$c_subtext0 \
        6c7086=$c_surface1 585b70=$c_surface1 45475a=$c_surface1 \
        3e5767=$c_surface1 313244=$c_surface0 1e1e2e=$c_base 181825=$c_base \
        11111b=$c_base; do
        program+="s/#${pair%%=*}/${pair#*=}/Ig;"
    done
    sed "$program" "$1"
}

if [ -z "$c_base" ]; then
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

# btop has its own theme for each palette, with those that came with it or
# among the user's. Not copied as a file: one from the store is read-only.
theme=${c_btop:-catppuccin_mocha}.theme
for dir in "$config/btop/themes" "$(dirname "$(readlink -f "$(command -v btop)")")/../share/btop/themes"; do
    [ -r "$dir/$theme" ] && cat "$dir/$theme" > "$btop" && break
done

# So has helix.
printf 'inherits = "%s"\n' "${c_helix:-catppuccin_mocha}" > "$helix"

# bat and micro have Catppuccin's alone: theirs for it, in the palette's colors.
recolor "$config/bat/themes/Catppuccin Mocha.tmTheme" > "$bat"
bat cache --build > /dev/null 2>&1
recolor "$config/micro/colorschemes/catppuccin-mocha-transparent.micro" > "$micro"

# Open terminals, btop and helix take it at once; fuzzel, bat and micro when
# started. Not one just started: before it handles the signal, it ends it.
pkill -USR2 --older 2 -x '\.?ghostty(-wrappe)?'
pkill -USR2 --older 2 -x btop
pkill -USR1 --older 2 -x '\.?hx(-wrapped)?'
niri msg action load-config-file
