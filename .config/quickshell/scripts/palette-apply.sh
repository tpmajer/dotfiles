#!/usr/bin/env bash

# The palette for what else takes one, each from a file its configuration
# names, kept out of git: ghostty, niri, fuzzel, btop, helix, bat, micro, mpv
# and GTK, with its folders. The login screen's too, where there is one to
# take it.
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
mpv=$config/mpv/palette.conf
gtk3=$config/gtk-3.0/palette.css
gtk4=$config/gtk-4.0/palette.css
files=("$ghostty" "$niri" "$fuzzel" "$btop" "$helix" "$bat" "$micro" "$mpv" "$gtk3" "$gtk4")
# The login screen reads its own at its start (~/.nixos, greeter/shell.qml).
greeter=/var/cache/greeter
[ -w "$greeter" ] && greeter+=/palette && files+=("$greeter") || greeter=

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
    : > "$mpv"
    [ -z "$greeter" ] || : > "$greeter"
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
    backdrop-color "$c_crust"
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

    # mpv's stats takes its colors as BBGGRR.
    bgr() {
        printf '%s' "${1:5:2}${1:3:2}${1:1:2}"
    }
    cat > "$mpv" <<CONF
background-color='$c_base'
osd-back-color='$c_base'
osd-border-color='$c_base'
osd-color='$c_text'
osd-shadow-color='$c_base'
script-opts-append=stats-border_color=$(bgr "$c_base")
script-opts-append=stats-font_color=$(bgr "$c_text")
script-opts-append=stats-plot_bg_border_color=$(bgr "$c_teal")
script-opts-append=stats-plot_bg_color=$(bgr "$c_base")
script-opts-append=stats-plot_color=$(bgr "$c_teal")
script-opts-append=uosc-color=foreground=${c_teal#\#},foreground_text=${c_surface0#\#},background=${c_base#\#},background_text=${c_text#\#},curtain=${c_base#\#},success=${c_green#\#},error=${c_red#\#}
CONF

    [ -z "$greeter" ] || printf '%s\n' "base=$c_base" "crust=$c_crust" "text=$c_text" \
        "subtext1=$c_subtext1" "subtext0=$c_subtext0" "green=$c_green" "peach=$c_peach" "red=$c_red" > "$greeter"
fi

# The session's VT has the palette it was started with as its colours
# (~/.nixos, greeter-session), and shows them again as the machine goes down:
# the backdrop, then plain text, bold, OK, failed and warnings.
vt=/dev/$(cat /sys/class/tty/tty0/active 2> /dev/null)
if [ -c "$vt" ] && [ -O "$vt" ]; then
    for pair in 0=${c_crust:-#11111b} 7=${c_subtext1:-#bac2de} F=${c_text:-#cdd6f4} \
        2=${c_green:-#a6e3a1} A=${c_green:-#a6e3a1} 1=${c_red:-#f38ba8} \
        9=${c_red:-#f38ba8} 3=${c_peach:-#fab387} B=${c_peach:-#fab387}; do
        printf '\033]P%s%s' "${pair%%=*}" "${pair#*=\#}"
    done > "$vt"
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

# Papirus has its folders in Catppuccin Mocha's blue: a theme over it with
# those alone, in the palette's teal, and in Catppuccin Mocha's sky. One for
# each palette, named by its colors, as GTK takes icons again at a change of
# the theme's name alone.
folders() {
    command -v dconf > /dev/null || return 0
    local key=/org/gnome/desktop/interface/icon-theme share papirus=
    local -a shares
    IFS=: read -ra shares <<< "${XDG_DATA_DIRS:-/usr/share}"
    for share in "${shares[@]}"; do
        [ -d "$share/icons/Papirus" ] && papirus=$(readlink -f "$share/icons/Papirus") && break
    done
    [ -n "$papirus" ] || { dconf reset "$key"; return; }

    local front=${c_teal:-#89dceb} paper=${c_text:-#cdd6f4} glyph=${c_surface0:-#313244}
    local name=Papirus-palette-${front#\#}${paper#\#}${glyph#\#}
    local theme=${XDG_DATA_HOME:-$HOME/.local/share}/icons/$name
    # Made once, and again when Papirus is another: `source` is the one used.
    if [ "$(cat "$theme/source" 2> /dev/null)" != "$papirus" ]; then
        local build=$theme.new dir size
        local -a found listed=()
        rm -rf "$build"
        mkdir -p "$build"
        for dir in "$papirus"/*/places; do
            size=${dir%/places}
            size=${size##*/}
            [ ! -L "$papirus/$size" ] || continue
            mapfile -t found < <(grep -Rlis '#89b4fa' "$dir")
            [ ${#found[@]} -gt 0 ] || continue
            mkdir -p "$build/$size/places"
            cp -P "${found[@]}" "$build/$size/places/"
            listed+=("$size/places")
        done
        # A size at twice the scale is a link to the size itself.
        for dir in "$papirus"/*@2x; do
            size=${dir##*/}
            [ -L "$dir" ] && [ -d "$build/$(readlink "$dir")/places" ] || continue
            cp -P "$dir" "$build/$size"
            listed+=("$size/places")
        done
        # The back of a folder is its front, darker: Papirus' own for the sky.
        local back=#75c8d7
        [ -z "$c_base" ] || back=$(printf '#%02x%02x%02x' $((16#${front:1:2} * 88 / 100)) \
            $((16#${front:3:2} * 88 / 100)) $((16#${front:5:2} * 88 / 100)))
        find "$build" -type f -name '*.svg' -exec sed -i \
            "s/#89b4fa/$front/Ig;s/#75a0e6/$back/Ig;s/#cdd6f4/$paper/Ig;s/#313244/$glyph/Ig" {} +
        {
            printf '[Icon Theme]\nName=%s\nComment=Papirus, its folders in the palette\n' "$name"
            printf 'Inherits=Papirus,breeze,hicolor\nExample=folder\n'
            (IFS=, && printf 'Directories=%s\n' "${listed[*]}")
            for dir in "${listed[@]}"; do
                printf '\n'
                sed -n "/^\[${dir//\//\\/}\]/,/^\$/{/^\$/d;p}" "$papirus/index.theme"
            done
        } > "$build/index.theme"
        printf '%s\n' "$papirus" > "$build/source"
        rm -rf "$theme"
        mv "$build" "$theme"
    fi
    dconf write "$key" "'$name'"
}
folders

printf '%s\n' "$applied" > "$state"

# Open terminals, btop and helix take it at once; fuzzel, bat, micro and mpv
# when started. Not one just started: before it handles the signal, it ends it.
pkill -USR2 --older 2 -x '\.?ghostty(-wrappe)?'
pkill -USR2 --older 2 -x btop
pkill -USR1 --older 2 -x '\.?hx(-wrapped)?'
niri msg action load-config-file > /dev/null 2>&1

# Last, as it takes a moment: bat reads its themes from a cache.
command -v bat > /dev/null && bat cache --build > /dev/null 2>&1
