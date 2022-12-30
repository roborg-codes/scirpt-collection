#/usr/bin/env sh

userresources="$HOME"/.Xresources
usermodmap="$HOME"/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

if [ -f "$sysresources" ]; then
    xrdb -merge "$sysresources"
fi

if [ -f "$sysmodmap" ]; then
    xmodmap "$sysmodmap"
fi

if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

# Make fcitx work in 'most' gui apps
export QT_IM_MODULE=fcitx5
export GTK_IM_MODULE=fcitx5
export XMODIFIERS=@im=fcitx5

xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
xrandr --dpi 96
xset r rate 300 50 # very nice

xbindkeys -f "$XDG_CONFIG_HOME"/X11/xbindkeysrc &
fcitx5 -d &

