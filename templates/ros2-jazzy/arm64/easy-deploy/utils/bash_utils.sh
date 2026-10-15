C_RED="\e[91m"
C_MAGENTA="\e[95m"
C_GREEN="\e[92m"
C_CYAN="\e[96m"
C_BOLD="\e[1m"
C_RESET="\e[0m"

function f_echo_red {
    echo -e "${C_RED}${C_BOLD}"$1"${C_RESET}"
}

function f_echo_magenta {
    echo -e "${C_MAGENTA}${C_BOLD}"$1"${C_RESET}"
}

function f_echo_green {
    echo -e "${C_GREEN}${C_BOLD}"$1"${C_RESET}"
}

function f_echo_cyan {
    echo -e "${C_CYAN}${C_BOLD}"$1"${C_RESET}"
}

function f_check_is_run_as_root {
    if [ "$EUID" -ne 0 ]
        then f_echo_red "Please run using sudo \nExiting..."
        exit
    fi
}

