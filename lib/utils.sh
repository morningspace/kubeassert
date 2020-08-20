BLUE="\033[0;34m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
NORMAL="\033[0m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
WHITE="\033[0;37m"

function logger::info {
  printf "${CYAN}INFO ${NORMAL} $@\n"
}

function logger::warn {
  printf "${YELLOW}WARN ${NORMAL} $@\n"
}

function logger::error {
  printf "${RED}ERROR${NORMAL} $1\n"
}

function confirm {
  local message=$1
  local default_value=${2:-Y}
  local input_value

  while true; do
    printf "\033[0;36m? \033[0;37m${message}\033[0m"
    [[ $default_value == Y ]] && printf " [Y/n] " || printf " [y/N] "

    read -r input_value
    input_value=${input_value:-$default_value}
    case $input_value in
      [yY][eE][sS]|[yY])
        return 0 ;;
      [nN][oO]|[nN])
        return 1 ;;
      *)
        printf "Invalid input...\n" ;;
    esac
  done
}

TEMP_PATH=$HOME/.ka

mkdir -p $TEMP_PATH

function on_exit {
  rm -rf $TEMP_PATH
}
