#!/usr/bin/env bash
export LC_ALL=en_US.UTF-8

declare -A PALLETE=(
  [dark]="#16161E"
  [lessdark]="#1A1B26"
  [lesslessdark]="#292e42"
  [blue]="#394B70"
  [orange]="#ff9e64"
  [blue1]="#3D59A1"
  [yellow]="#E0AF68"
  [blue2]="#89DDFF"
  [blue3]="#73DACA"
  [darkerpurple]="#9d7cd8"
  [purple]="#BB9AF7"
  [green]="#9ECE6A"
  [othergreen]="#41A6B5"
  [red]="#F7768D"
  [white]="#ffffff"
  [gray]="#545c7e"
  [gray1]="#4d536f"
)

left_sep=""
right_sep=""

tmux set-option -g status-left-length 400
tmux set-option -g status-right-length 100

  # message styling
tmux set-option -g message-style "bg=${PALLETE[red]},fg=${PALLETE[dark]}"

# status bar
tmux set-option -g status-style "bg=${PALLETE[lesslessdark]},fg=${PALLETE[white]}"

# border color
tmux set-option -g pane-active-border-style "fg=${PALLETE[gray1]}"
tmux set-option -g pane-border-style "fg=${PALLETE[lesslessdark]}"

# tmux set-option -g status-left ""
tmux set-option -g status-left "#[bg=${PALLETE[yellow]},fg=${PALLETE[white]},bold]#{?client_prefix,#[bg=${PALLETE[green]}],}  #S #[fg=${PALLETE[yellow]},bg=${PALLETE[lesslessdark]}]#{?client_prefix,#[fg=${PALLETE[green]}],}${left_sep}"
tmux set-option -g status-right "adss"


tmux set-window-option -g window-status-format "#[fg=${PALLETE[lesslessdark]},bg=${PALLETE[gray]}]${left_sep}#[fg=${PALLETE[white]}]#I#[fg=${PALLETE[gray]},bg=${PALLETE[gray1]}]${left_sep}#[fg=${PALLETE[white]},bg=${PALLETE[gray1]}]  #W #[fg=${PALLETE[gray1]},bg=${PALLETE[lesslessdark]}]${left_sep}"

tmux set-window-option -g window-status-current-format "#[fg=${PALLETE[lesslessdark]},bg=${PALLETE[purple]}]${left_sep}#[fg=${PALLETE[white]},bold]#I#[fg=${PALLETE[purple]},bg=${PALLETE[darkerpurple]}]${left_sep}#[fg=${PALLETE[white]},bg=${PALLETE[darkerpurple]},bold]  #W #[fg=${PALLETE[darkerpurple]},bg=${PALLETE[lesslessdark]}]${left_sep}"

tmux set-window-option -g window-status-activity-style "bold"
tmux set-window-option -g window-status-bell-style "bold"
tmux set-window-option -g window-status-separator ''
