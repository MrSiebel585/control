# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -f "$HOME/.config/user-dirs.dirs" ]; then
    . "$HOME/.config/user-dirs.dirs"
    export XDG_OSINT_DIR XDG_FORENSICS_DIR XDG_LOGS_DIR XDG_REPORTING_DIR XDG_USER_DIR XDG_SYSTEM_DIR XDG_SCRAPING_DIR
fi


findfile() {
    # Prompt user for filename
    read -p "Enter filename to search for: " filename

    # Search for file in the entire filesystem recursively, starting from root
    echo "Searching for '$filename'..."
    find / -type f -name "$filename" 2>/dev/null
}

# Display last 3 reminders from project log on shell startup
if [ -f ./WORKLOG.md ]; then
    echo -e "\nLast 3 Reminders:"
    tail -n 3 ./WORKLOG.md
    echo "------------------"
fi

gitremind() {
    MSG="$1"
    echo "- [$(date '+%Y-%m-%d %H:%M:%S')] $MSG" >> ./WORKLOG.md
    git add .
    git commit -m "$MSG"
}


WHITERABBIT="/opt/omniscient/ai/models/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-IQ2_M.gguf"
export WHITERABBIT


# ─── OMNISCIENT FRAMEWORK PATH EXPORTS ─────────────────────────────────────
OMNISCIENT="/opt/omniscient"
export OMNISCIENT

WHITERABBIT="$OMNISCIENT/ai/models/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-IQ2_M.gguf"
export WHITERABBIT

# Additional Omniscient Directories
OMNISCIENT_AI="$OMNISCIENT/ai"
export OMNISCIENT_AI

OMNISCIENT_BIN="$OMNISCIENT/bin"
export OMNISCIENT_BIN

OMNISCIENT_CONF="$OMNISCIENT/conf"
export OMNISCIENT_CONF

OMNISCIENT_LOGS="$OMNISCIENT/logs"
export OMNISCIENT_LOGS

OMNISCIENT_OSINT="$OMNISCIENT/osint"
export OMNISCIENT_OSINT

OMNISCIENT_SCRIPTS="$OMNISCIENT/scripts"
export OMNISCIENT_SCRIPTS

OMNISCIENT_HOME="$OMNISCIENT/home/$USER"
export OMNISCIENT_HOME

OMNISCIENT_SQL="$OMNISCIENT/sql"
export OMNISCIENT_SQL

OMNISCIENT_WEB="$OMNISCIENT/web"
export OMNISCIENT_WEB

OMNISCIENT_FORENSICS="$OMNISCIENT/forensics"
export OMNISCIENT_FORENSICS

OMNISCIENT_INIT="$OMNISCIENT/init"
export OMNISCIENT_INIT

OMNISCIENT_MANAGEMENT="$OMNISCIENT/management"
export OMNISCIENT_MANAGEMENT

# ───────────────────────────────────────────────────────────────────────────


alias arm='sudo chmod +x'
alias implement='sudo apt install -y'
alias dropoff='sudo apt remove -y'
alias update='sudo apt update -y && sudo apt upgrade -y'
alias ytdl='yt-dlp -f bestaudio --extract-audio --audio-format'
alias systemservices='sudo service --status-all | tee -a /opt/omniscient/logs/systemservices.log'

alias systeminterface='sudo mainmenu'
alias servicesinterface='sudo servicesmenu'
alias ngroknterface='sudo ngrokmenu'
alias enableforwarding='sudo bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"'
alias publicip='curl ident.me; echo'
alias sshtunnel='ssh -X jeremy@engram'
alias zerousb='read -p "zerodeviceusb: " setdev; sudo dd if=/dev/zero of=/dev/$setdev bs=1024 status=progress'
alias enterdatabase='sudo mysql'
alias implement='read -p "implement: " pkg; sudo apt install -y $pkg | tee -a /tmp/implemented.log; cp /tmp/implemented.log ~/implemented.log'
alias dropoff='sudo apt remove -y'
alias blowoff='sudo apt clean && sudo apt purge && sudo apt autoremove'
alias arm='sudo chmod +x'
alias unet='sudo QT_X11_NO_MITSHM=1 /usr/bin/unetbootin'
alias newshell='gnome-terminal'
alias url2pdf='wkhtmltopdf'
alias ducks='du -cks * | sort -rn | head'
alias ducks2='find $HOME -type f -printf "%s %p\n" | sort -nr | head -10'
alias wget='wget -c'
alias rget='wget -r'
alias ls7z='sudo 7z -l'
alias tarup='tar -zcf'
alias tardown='tar -zxf'
alias untarall='tar -zxvf *.tar.gz'
alias dosflood='sudo hping3 -c 1000000 -d 65000 -S -w 64 -p 21 --flood'
alias 7up2usb32='read -p "7up Dir: " dir; 7z a /media/$USER/USB32/$dir.7z $dir'
alias 7unzip='read -p "7unzip Dir: " dir; 7z e $dir.7z'
alias 7zMx='read -p "MaxCompress: " dir; tar -cf - $dir | 7za a -si -mx=9 tecmint_files.tar.7z'
alias findandremoveall='read -p "findrm: " file; find . -type f -name "*$file" | xargs rm -f'
alias zipdir='read -p "zipDir: " dir; zip -r $dir.zip $dir'
alias allservices='systemctl list-units --type=service --all'
alias activeservices='systemctl list-units --type=service --state=running'
alias servicesreport='sudo service --status-all | tee -a ~/Desktop/servicesreport.log'
alias rmlog='find . -type f -name "*test*.log" | xargs rm -f'
alias truncatedirs='find . -depth -mindepth 1 -type d -empty -exec rmdir {} \;'
alias rmlock='sudo rm -rf /var/lib/apt/lists/lock /var/lib/apt/lists/lock-frontend /var/cache/apt/archives/lock /var/lib/dpkg/lock'
alias killaptsystem='sudo killall apt apt-get'
alias mac='sudo bash -c "dhclient -r wlp2s0; ifconfig wlp2s0 down; macchanger -r wlp2s0; ifconfig wlp2s0 up; iwconfig wlp2s0 essid SpectrumWiFi"'
alias runremote='read -p "user@server: " usesrv; read -p "remotecmd: " path; ssh $usesrv bash < $path'
alias systemlog='journalctl -xe'
alias etcher='/opt/etcher/balenaEtcher-1.5.122-x64.AppImage'
alias search='sudo apt-cache search'
alias show='sudo apt-cache show'
alias arachni='/opt/arachni/bin/arachni'
alias apachereload='sudo service apache2 reload'
alias apacherst='sudo service apache2 restart'
alias apachestop='sudo service apache2 stop'
alias apacheacceslog='cat /var/log/apache2/access.log'
alias apacheerrorlog='cat /var/log/apache2/error.log'
alias apachecheck='sudo systemctl status apache2.service'
alias startscripting='script -a -f /tmp/script_log.txt && cp /tmp/script_log.txt ~/Desktop/'
alias recterm='script -aq ~/term.log-$(date)'
alias networkrst='sudo service network-manager restart'
alias findfile='find . -name'
alias findmove='read -p "findfiles: " files; find . -name "$files" -exec mv {} $str \;'
alias nosqlmap='cd /opt/NoSQLMap/docker; ./run'
alias golismero1='cd /opt/golismero; python golismero.py'
alias fixmissing='sudo apt-get update --fix-missing'
alias mkdircd='mkcd(){ NAME=$1; mkdir -p "$NAME"; cd "$NAME"; }; mkcd'
alias removelargest='find ./ -size +1M | xargs rm -i'
alias dorkcli='cd /opt/dorkcli && python dork-cli.py'
alias dorkseye='cd /opt/dorkseye && python dorks-eye.py'
alias udork='cd /opt/uDork && ./uDork.sh'
alias supersploit='cd /opt/Supersploit && python3 supersploit.py'
alias searchsploit='cd /opt/Searchsploit && ./Searchsploit'
alias setoolkit='cd /opt/setoolkit && sudo ./setoolkit'

# Omniscient system control aliases
alias omnictl='sudo /opt/omniscient/bin/omniscientctl'
alias omnigui='sudo python3 /opt/omniscient/gui/tkinter_gui.py'
alias omniscient='sudo /opt/omniscient/omniscient_menu.sh'
alias omnistart='sudo systemctl start omniscient'
alias omnistatus='systemctl status omniscient'
alias omnistop='sudo systemctl stop omniscient'

# Optional helper to show available commands
alias omnihelp='echo -e "\nOmniscient Aliases:\n  omnictl\n  omnigui\n  omniscient\n  omnistart\n  omnistatus\n  omnistop\n"'


# Load Omniscient environment variables
[ -f /opt/omniscient/.env ] && source /opt/omniscient/.env

alias bin2bin='rsync -avz /usr/local/bin/ jeremy@aspire:/usr/local/bin/'
alias omni2omni='rsync -avz /opt/omniscient/ jeremy@aspire:/opt/omniscient/'

