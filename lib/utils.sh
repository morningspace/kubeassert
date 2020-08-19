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

TEMP_PATH=$HOME/.ka

mkdir -p $TEMP_PATH

function on_exit {
  rm -rf $TEMP_PATH
}
