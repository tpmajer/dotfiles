#!/usr/bin/env bash

# The palette for what else takes one, each from a file its configuration
# names, kept out of git: ghostty, niri, fuzzel, btop, helix, bat, micro and
# GTK.
#   palette-apply.sh [init|sync] [name=color ...] [ghostty=theme btop=theme helix=theme]
# The colors are Theme's, as #rrggbb. With none it is Catppuccin Mocha, which
# the configurations and their themes have.
# `init` does nothing unless a file is missing: niri at its start, as fuzzel
# does not start without its file, and btop, helix, bat and micro have no
# theme without theirs. `sync` neither unless the palette applied last was
# another: quickshell at its start.

mode=
case $1 in
    init | sync) mode=$1 && shift ;;
esac

for pair in "$@"; do
    [[ ${pair%%=*} =~ ^[a-z0-9]+$ ]] && declare "c_${pair%%=*}=${pair#*=}"
done

config=${XDG_CONFIG_HOME:-$HOME/.config}
state=${XDG_STATE_HOME:-$HOME/.local/state}/palette-apply
ghostty=$config/ghostty/palette
niri=$config/niri/palette.kdl
# Where fuzzel.ini includes it from: it cannot name $XDG_CONFIG_HOME.
fuzzel=$HOME/.config/fuzzel/palette.ini
btop=$config/btop/themes/palette.theme
helix=$config/helix/themes/palette.toml
bat=$config/bat/themes/palette.tmTheme
micro=$config/micro/colorschemes/palette.micro
gtk3=$config/gtk-3.0/palette.css
gtk4=$config/gtk-4.0/palette.css
files=("$ghostty" "$niri" "$fuzzel" "$btop" "$helix" "$bat" "$micro" "$gtk3" "$gtk4")

# One at a time: a palette is not to be overwritten by the one before it.
mkdir -p "${state%/*}"
exec 9> "$state.lock"
flock 9

applied="applied: $*"
if [ -n "$mode" ]; then
    stale=
    for file in "${files[@]}"; do
        [ -e "$file" ] || stale=1
    done
    [ "$mode" = sync ] && [ "$(cat "$state" 2> /dev/null)" != "$applied" ] && stale=1
    [ -n "$stale" ] || exit 0
fi

for file in "${files[@]}"; do
    mkdir -p "${file%/*}"
done

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

    # Rules come after the configuration's own, and so over them.
    cat > "$niri" <<KDL
layout {
    focus-ring {
        active-gradient from="$c_sapphire" to="$c_green" angle=45 relative-to="window"
        inactive-color "${c_base}b3"
    }
    border {
        active-color "${c_base}b3"
        inactive-color "${c_subtext0}b3"
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
overview {
    backdrop-color "$c_base"
}
window-rule {
    match is-floating=true
    shadow {
        color "${c_teal}8c"
    }
}
layer-rule {
    match namespace="^launcher\$"
    shadow {
        color "${c_teal}8c"
    }
}
window-rule {
    match is-window-cast-target=true
    focus-ring {
        active-color "$c_red"
        inactive-color "$c_maroon"
    }
    border {
        inactive-color "$c_maroon"
    }
    shadow {
        color "${c_maroon}bb"
    }
    tab-indicator {
        active-color "$c_red"
        inactive-color "$c_maroon"
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
# With none found it is btop's default, rather than the palette before.
theme=${c_btop:-catppuccin_mocha}.theme
dirs=("$config/btop/themes")
program=$(command -v btop) && dirs+=("$(dirname "$(readlink -f "$program")")/../share/btop/themes")
found=
for dir in "${dirs[@]}"; do
    [ -r "$dir/$theme" ] && cat "$dir/$theme" > "$btop" && found=1 && break
done
[ -n "$found" ] || : > "$btop"

# So has helix.
printf 'inherits = "%s"\n' "${c_helix:-catppuccin_mocha}" > "$helix"

# bat and micro have Catppuccin's alone: theirs for it, in the palette's colors.
recolor "$config/bat/themes/Catppuccin Mocha.tmTheme" > "$bat"
recolor "$config/micro/colorschemes/catppuccin-mocha-transparent.micro" > "$micro"

# GTK's stylesheets import theirs over the colors they name, and so do the
# copies Flatpak applications have, niri's scripts/flatpak-gtk-theme.sh.
# Applications take it when started.
gtk() {
    [ -n "$c_base" ] || return 0
    cat <<CSS
@define-color accent $c_teal;
@define-color red $c_red;
@define-color green $c_green;
@define-color text $c_text;
@define-color surface_0 $c_surface0;
@define-color base $c_base;
@define-color crust $c_base;
CSS
}
gtk > "$gtk3"
gtk > "$gtk4"
shopt -s nullglob
for dir in "$HOME"/.var/app/*/config/gtk-[34].0; do
    gtk > "$dir/palette.css"
done

printf '%s\n' "$applied" > "$state"

# Open terminals, btop and helix take it at once; fuzzel, bat and micro when
# started. Not one just started: before it handles the signal, it ends it.
pkill -USR2 --older 2 -x '\.?ghostty(-wrappe)?'
pkill -USR2 --older 2 -x btop
pkill -USR1 --older 2 -x '\.?hx(-wrapped)?'
niri msg action load-config-file > /dev/null 2>&1

# Last, as it takes a moment: bat reads its themes from a cache.
command -v bat > /dev/null && bat cache --build > /dev/null 2>&1
