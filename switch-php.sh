# !/bin/bash


# Set verbose to be off by default
verbose=0

# Set debug to be off by default
debug=0


# Set some color formatting variables
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[1;34m"
RED_BG="\e[41m"
NC="\e[0m" # Reset everything


# Currently available php packages
brew_array=("5.6" "7.0" "7.1" "7.2" "7.3" "7.4")
php_array=("php@5.6" "php@7.0" "php@7.1" "php@7.2" "php@7.3" "php@7.4")

# echo message
# $1 = verbose message
# $2 = message
show() {
    local verbose_message="$1"
    local message="$2"
    [ "$verbose" -eq 1 ] && printf "$verbose_message" || printf "$message"
}

# STARTS THE SPINNER
# $1 = message to be displayed
start_spinner() {
    local verbose_message="$1"
    local message="$2"

    # Let's not do the fancy spinner if we're in verbose mode
	if [ "$verbose" = 1 ]; then
		printf "$verbose_message...\n"

	# Otherwise let's do the fancy spinner
	else
	    i=1
		sp='\|/-' # The spinner string
		printf "$message   "
		while true; do
			printf "\b\b${sp:i++%${#sp}:1} "
			sleep 0.15
		done &
		sp_pid=$!
	    disown
	fi

}


# STOPS THE SPINNER
# $1 = message to be displayed
stop_spinner() {
    local verbose_message="$1"
    local message="$2"

	# Let's keep things simple if we're in verbose mode
	if [ "$verbose" = 1 ]; then
		printf "$verbose_message\n"

	# Otherwise we'll do some fancy formatting
	else
	    kill "$sp_pid" > /dev/null 2>&1
	    printf "\033[2K\r$message ${BLUE}✔${NC}\n"
		unset sp_pid
	fi

}

# SHOWS ERRORS AND HELP
# $1 = error message to be displayed
show_help() {

	# If an error message is specifed, let's display it in a fancy box
	if [[ -n "$1" ]]; then
		printf "\n${RED_BG}   $(printf "%-${#1}s" " ")   ${NC}\n"
		printf "${RED_BG}   $1   ${NC}\n"
		printf "${RED_BG}   $(printf "%-${#1}s" " ")   ${NC}\n\n"
	fi

	# Otherwise we'll just display the normal help message
	printf "${YELLOW}Usage:${NC}\n"
	printf "  version [options] [arguments]\n\n"
	printf "${YELLOW}Options:${NC}\n"
	printf "  ${GREEN}-h, --help${NC}      Display this help message\n"
	printf "  ${GREEN}-v, --verbose${NC}   Display more info during the process\n"
	printf "  ${GREEN}-m, --memory${NC}    Customize the PHP memory setting (Valet only)\n\n"
	printf "${YELLOW}Available Versions:${NC}\n"
	for i in ${brew_array[*]}; do
		printf "  ${GREEN}$i${NC}              Switch to php$i\n"
	done
	printf "\n${YELLOW}Customizing the PHP Memory Settings:${NC}\n"
	printf "  - If you don't pass an argument to \"-m\" or \"--memory\", it will reset any previously set custom memory settings to the default Valet config.\n"
	printf "  - Alternatively, you can pass an argument to \"-m\" or \"--memory\" if you want to override the default Valet memory settings. For example, you can do: \n\n"
	printf "      ${GREEN}switch-php 7.1 -m 512M${NC}       # php@7.1 with 512MB of memory\n"
	printf "      ${GREEN}switch-php 7.3 -m 2G -v${NC}      # php@7.3 with 2GB of memory; verbose output\n"
	printf "      ${GREEN}switch-php 5.6 --memory=1G${NC}   # php@5.6 with 1GB of memory\n\n"
	printf "  - Note: customizing PHP memory settings currently only works for Laravel Valet users. If you don't use Valet, we hope to get this working for you as well in an upcoming release.\n"
	exit

}


# If no options or versions are specified, let's show the error message
if [[ -z "$1" ]]; then
	show_help "Uh-oh! Please specify a PHP version."
fi


# Let's loop through the available options/versions
while :; do
    case $1 in
        -h|-\?|--help) # The help option
            show_help
            exit
            ;;
		5.6|7.0|7.1|7.2|7.3|7.4) # If a version is specified; then
			php_version="php@$1"
			rflag="true"  # Required!
			;;
	    -d|--debug) # The debug option
	        debug=$((debug + 1)) # Set verbose to be on
	        ;;
	    -v|--verbose) # The verbose option
	        verbose=$((verbose + 1)) # Set verbose to be on
	        ;;
		-m|--memory) # The memory option
            if [ "$2" ]; then
                memory="$2" # Set memory to whatever argument follows
                shift
            else
                memory="0" # Otherwise we'll set memory to the default
            fi
            ;;
        --memory=?*) # Another memory option
            memory=${1#*=} # Set memory to whatever follows the "=" sign
            ;;
        --memory=) # Yet another memory option
            show_help "Uh-oh! Please specify an argument for \"--memory\"." # If nothing follows the "=" sign, show an error
            ;;
        -?*) # Matches any unknown options
            show_help "Uh-oh! Unknown option \"$1\"."
            ;;
        ?*) # Matches any version
			if [[ -z "$rflag" ]]; then  # If a required version isn't set; then
            	show_help "Uh-oh! \"$1\" doesn't seem to be an available PHP version." # Let's show an error
			fi
            ;;
        *) # Matches anything
            break
	esac
    shift
done

[ "$debug" -eq 1 ] && verbose=1 # force verbosity if debug enabled.

# use FileHandle 3 to output to. Determined by debug setting - use stderr for debugging , hidden otherwise (/dev/null)
[ $debug -eq 1 ] && exec 3>/dev/stderr || exec 3>/dev/null

[ $debug -eq 1 ] && valet_options=" -v " || valet_options=""
[ $debug -eq 1 ] && brew_link_options=" -vv " || brew_link_options=""

echo "Debugging" >&3

# If our required version isn't set, let's show the error message
if [[ -z "$rflag" ]]; then
    show_help "Uh-oh! Please specify a PHP version."
fi


# Let's check and see if Valet is installed
show " 👀  Verifying that Valet is installed...\n"
type -p valet &>/dev/null && valet_installed=1 || valet_installed=0
[ "$valet_installed" -eq 1 ] && valet --version 1>&3 2>&3 || true


# Let's check and see which PHP versions are installed
show " 🔍  Checking which PHP versions are installed...\n"
for i in ${php_array[*]}; do # For all PHP versions listed in php_array:
	if [[ -n "$(brew ls --versions "$i")" ]]; then # If it is installed via Brew; then
		php_installed_array+=("$i") # Add it to our php_installed_array
	fi
done

# The main switcher script :P
if [[ " ${php_installed_array[*]} " == *"$php_version"* ]]; then # If the requested PHP version is installed; then

	if [[ ($valet_installed -eq 1) ]]; then # If Valet is installed; then
		start_spinner " 🛑  Stopping Valet" "Stopping Valet"
        show " ==>  Stopping nginx...\n"

        valet stop $valet_options 1>&3 2>&3

		stop_spinner " ✅  Valet stopped" "Valet stopped"
	fi

    # Pre Switch Hook
    [ "$(type -t _switch_php_pre_tasks)" = "function" ] && _switch_php_pre_tasks "${php_version}" "${verbose}"|| echo "$(type -t _switch_php_pre_tasks)"
    
	start_spinner " 🔀  Switching to $php_version" "Switching PHP"
    for i in ${php_array[*]}; do # For all PHP versions listed in php_array:
        if [[ -n $(brew ls --versions "$i") ]]; then # If it is installed via Brew; then
            show " ==>  Stopping $i...\n"
            brew services stop "$i" 1>&3 2>&3  # Stop the Brew service for each PHP version and hide the output

            show " ==>  Unlinking $i...\n"
            brew unlink $brew_link_options "$i" 1>&3 2>&3  # Unlink each PHP version and hide the output
        fi
    done

    show " ==>  Linking $php_version...\n"
    brew link $brew_link_options --force "$php_version" 1>&3 2>&3  # Link the new PHP version

    show " ==>  Starting $php_version...\n"
    brew services start "$php_version" 1>&3 2>&3  # Start the Brew service for the new PHP version
	stop_spinner " ✅  PHP switched" "PHP switched"

	if [[ ($valet_installed -eq 1) ]]; then # If Valet is installed; then

		if [[ -z "$memory" ]]; then # If $memory isn't specified at all; then
			start_spinner " ⚙  Starting Valet" "Starting Valet"
            show " ==>  Starting nginx...\n"

            valet start $valet_options 1>&3 2>&3

			stop_spinner " ✅  Valet started" "Valet started"

		elif [ "$memory" = "0" ]; then # If $memory is set to the default; then
			start_spinner " ⚙  Starting Valet" "Starting Valet"
            show " ==>  Starting nginx...\n"
            show " ==>  Starting dnsmasq...\n"

            valet install $valet_options 1>&3 2>&3

			stop_spinner " ✅  Valet started" "Valet started"
			start_spinner " 🔄  Resetting PHP" "Resetting PHP"
            show " ==>  Resetting PHP memory to 128M...\n"

            brew services restart "$php_version" 1>&3 2>&3

			stop_spinner " ✅  PHP reset" "PHP reset"

		else # Otherwise let's use the specified $memory
			start_spinner " ⚙  Starting Valet" "Starting Valet"
            show " ==>  Starting nginx...\n"
            show " ==>  Starting dnsmasq...\n"

            valet install $valet_options 1>&3 2>&3

			stop_spinner " ✅  Valet started" "Valet started"
			start_spinner " 🎛  Configuring PHP" "Configuring PHP"
            show " ==>  Setting PHP memory to $memory...\n"

            printf "\nmemory_limit = $memory" >> /usr/local/etc/php/${php_version:4}/conf.d/php-memory-limits.ini # Add the new memory setting to our PHP config file

            show " ==>  Restarting PHP...\n"

            brew services restart "$php_version" 1>&3 2>&3

			stop_spinner " ✅  PHP configured" "PHP configured"
		fi

	fi

	new_version=$(php -r "echo PHP_VERSION;") # Get the current PHP version (should be the version just switched too :P )
	printf "\nYou are now using PHP $new_version\n" # Display a message specifying the new version

else # If the requested PHP version is not installed; then let's show a handy message on how to quickly get it
	printf "Sorry, but $php_version is not installed via brew. "
	printf "Install by running: \e[1mbrew install $php_version\n"
fi

# Post Switch Hook
[ "$(type -t _switch_php_post_tasks)" = "function" ] && _switch_php_post_tasks "${php_version}" "${verbose}" || true


exec 3>&- > /dev/null
if { >&3; } 2<> /dev/null; then # if filedescriptor open
    exec 3>&- >/dev/null # # close filedescriptor 3 - hide output of command
else
    echo 'not open' >/dev/null
fi