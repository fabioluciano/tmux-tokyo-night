#!/usr/bin/env bash
set -euxo pipefail

export LC_ALL=en_US.UTF-8

readonly CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$CURRENT_DIR/utils.sh"
. "$CURRENT_DIR/palletes.sh"

### Load Options
border_style_active_pane=$(get_tmux_option "@theme_active_pane_border_style" "fg=${PALLETE[gray1]}")
border_style_inactive_pane=$(get_tmux_option "@theme_active_pane_border_style" "fg=${PALLETE[lesslessdark]}")
left_separator=$(get_tmux_option "@theme_left_separator" "")
right_separator=$(get_tmux_option "@theme_right_separator" "")

# https://man.openbsd.org/OpenBSD-current/man1/tmux.1#acs
window_with_activity_style=$(get_tmux_option "@theme_window_with_activity_style" "italics")
window_status_bell_style=$(get_tmux_option "@theme_status_bell_style" "bold")

IFS=' ' read -r -a plugins <<< "$(get_tmux_option "@theme-plugins" "datetime git kubernetes weather")"


function generate_left_side_string() {
  local separator_end="#[bg=${PALLETE[lesslessdark]}]#{?client_prefix,#[fg=${PALLETE[green]}],#[fg=${PALLETE[yellow]}]}${left_separator}#[none]"

  echo "#[fg=${PALLETE[white]},bold]#{?client_prefix,#[bg=${PALLETE[green]}],#[bg=${PALLETE[yellow]}]}  #S ${separator_end}"
}

function generate_inactive_window_string() {
  local separator_start="#[bg=${PALLETE['gray']},fg=${PALLETE['lesslessdark']}]${left_separator}#[none]"
  local separator_internal="#[bg=${PALLETE['gray1']},fg=${PALLETE['gray']}]${left_separator}#[none]"
  local separator_end="#[bg=${PALLETE[lesslessdark]},fg=${PALLETE['gray1']}]${left_separator}#[none]"

  echo "${separator_start}#[fg=${PALLETE[white]}]#I${separator_internal}#[fg=${PALLETE[white]}] #W ${separator_end}"
}

function generate_active_window_string() {
  local separator_start="#[bg=${PALLETE['purple']},fg=${PALLETE['lesslessdark']}]${left_separator}#[none]"
  local separator_internal="#[bg=${PALLETE['darkerpurple']},fg=${PALLETE['purple']}]${left_separator}#[none]"
  local separator_end="#[bg=${PALLETE[lesslessdark]},fg=${PALLETE['darkerpurple']}]${left_separator}#[none]"

  echo  "${separator_start}#[fg=${PALLETE[white]},bold]#I${separator_internal}#[fg=${PALLETE[white]},bold]  #W ${separator_end}"
}

tmux set-option -g status-left-length 100
tmux set-option -g status-right-length 1000

tmux set-window-option -g window-status-activity-style "$window_with_activity_style"
tmux set-window-option -g window-status-bell-style "${window_status_bell_style}"

# message styling
tmux set-option -g message-style "bg=${PALLETE[red]},fg=${PALLETE[dark]}"

# status bar
tmux set-option -g status-style "bg=${PALLETE[lesslessdark]},fg=${PALLETE[white]}"

# border color
tmux set-option -g pane-active-border-style "$border_style_active_pane"
tmux set-option -g pane-border-style "$border_style_inactive_pane"

### Left side
tmux set-option -g status-left "$(generate_left_side_string)"

### Windows list
tmux set-window-option -g window-status-format "$(generate_inactive_window_string)" 
tmux set-window-option -g window-status-current-format "$(generate_active_window_string)"

### Right side
tmux set-option -g status-right ""

for plugin in "${plugins[@]}"; do
  
  if [ ! -f "${CURRENT_DIR}/plugin/${plugin}.sh" ]; then
    tmux display-message " #[bold]ERROR:#[none] The plugin #[bold]${plugin}#[none] does not exists!" 
  else
    . "${CURRENT_DIR}/plugin/${plugin}.sh"
    tmux set-option -ga status-right "$(load_plugin)"
  fi 
done


tmux set-window-option -g window-status-separator ''
