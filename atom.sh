#!/bin/bash

if [ "$(uname)" == 'Darwin' ]; then
  OS='Mac'
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  OS='Linux'
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

if [ "$(basename $0)" == 'atom-beta' ]; then
  BETA_VERSION=true
else
  BETA_VERSION=
fi

export ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT=true

while getopts ":wtfvh-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        wait)
          WAIT=1
          ;;
        help|version)
          REDIRECT_STDERR=1
          EXPECT_OUTPUT=1
          ;;
        foreground|test)
          EXPECT_OUTPUT=1
          ;;
      esac
      ;;
    w)
      WAIT=1
      ;;
    h|v)
      REDIRECT_STDERR=1
      EXPECT_OUTPUT=1
      ;;
    f|t)
      EXPECT_OUTPUT=1
      ;;
  esac
done

if [ $REDIRECT_STDERR ]; then
  exec 2> /dev/null
fi

if [ $EXPECT_OUTPUT ]; then
  export ELECTRON_ENABLE_LOGGING=1
fi

if [ $OS == 'Mac' ]; then
  if [ -n "$BETA_VERSION" ]; then
    ATOM_APP_NAME="Thera Beta.app"
    ATOM_EXECUTABLE_NAME="Thera Beta"
  else
    ATOM_APP_NAME="Thera.app"
    ATOM_EXECUTABLE_NAME="Thera"
  fi

  # modify ATOM_PATH to THERA_PATH to forbidden environment conflicts.
  if [ -z "${THERA_PATH}" ]; then
    # If THERA_PATH isnt set, check /Applications and then ~/Applications for Atom.app
    if [ -x "/Applications/$ATOM_APP_NAME" ]; then
      THERA_PATH="/Applications"
    elif [ -x "$HOME/Applications/$ATOM_APP_NAME" ]; then
      THERA_PATH="$HOME/Applications"
    else
      # We havent found an Atom.app, use spotlight to search for Atom
      THERA_PATH="$(mdfind "kMDItemCFBundleIdentifier == 'com.tmall.thera'" | grep -v ShipIt | head -1 | xargs -0 dirname)"

      # Exit if Atom can't be found
      if [ ! -x "$THERA_PATH/$ATOM_APP_NAME" ]; then
        echo "Cannot locate Atom.app, it is usually located in /Applications. Set the THERA_PATH environment variable to the directory containing Atom.app."
        exit 1
      fi
    fi
  fi

  if [ $EXPECT_OUTPUT ]; then
    "$THERA_PATH/$ATOM_APP_NAME/Contents/MacOS/$ATOM_EXECUTABLE_NAME" --executed-from="$(pwd)" --pid=$$ "$@"
    exit $?
  else
    open -a "$THERA_PATH/$ATOM_APP_NAME" -n --args --executed-from="$(pwd)" --pid=$$ --path-environment="$PATH" "$@"
  fi
elif [ $OS == 'Linux' ]; then
  SCRIPT=$(readlink -f "$0")
  USR_DIRECTORY=$(readlink -f $(dirname $SCRIPT)/..)

  if [ -n "$BETA_VERSION" ]; then
    THERA_PATH="$USR_DIRECTORY/share/atom-beta/atom"
  else
    THERA_PATH="$USR_DIRECTORY/share/atom/atom"
  fi

  ATOM_HOME="${ATOM_HOME:-$HOME/.thera}"
  # ATOM_HOME="${ATOM_HOME:-$HOME/.atom}"
  mkdir -p "$ATOM_HOME"

  : ${TMPDIR:=/tmp}

  [ -x "$THERA_PATH" ] || THERA_PATH="$TMPDIR/atom-build/Atom/atom"

  if [ $EXPECT_OUTPUT ]; then
    "$THERA_PATH" --executed-from="$(pwd)" --pid=$$ "$@"
    exit $?
  else
    (
    nohup "$THERA_PATH" --executed-from="$(pwd)" --pid=$$ "$@" > "$ATOM_HOME/nohup.out" 2>&1
    if [ $? -ne 0 ]; then
      cat "$ATOM_HOME/nohup.out"
      exit $?
    fi
    ) &
  fi
fi

# Exits this process when Atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# If the wait flag is set, don't exit this process until Atom tells it to.
if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi
