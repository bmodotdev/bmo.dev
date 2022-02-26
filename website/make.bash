#!/usr/bin/env bash

shopt -s extglob

#########
# Utils #
#########

# Ansi color code variables
readonly blue="\e[0;94m"
readonly cyan="\e[1;96m"
readonly green="\e[0;92m"
readonly purple="\e[1;95m"
readonly red="\e[0;91m"
readonly yellow="\e[1;93m"
readonly white="\e[0;97m"

readonly expand_bg="\e[K"
readonly blue_bg="\e[0;104m${expand_bg}"
readonly red_bg="\e[0;101m${expand_bg}"
readonly green_bg="\e[0;102m${expand_bg}"

readonly bold="\e[1m"
readonly uline="\e[4m"
readonly reset="\e[0m"


_date_format="+%d/%b/%Y %H:%M:%S"
# success "Finished install"
#   $1  required    The string to log
#
function success () {
    local _date

    _date="$(command -p date "$_date_format")"

    printf "${green}SUCCESS${reset} [%s] %s\n" "$_date" "${1:-Success}"
}

# debug "Using download mirror: $mirror"
#   $1  required    The string to log
#
function debug () {
    [ "${_debug:-FALSE}" == FALSE  ] && return

    local _date

    _date="$(command -p date "$_date_format")"
    read -r _line _sub _file < <(caller 0)

    printf 'DEBUG [%s] <%s@%s:%s> %s\n' "$_date" "$_sub" "$_file" "$_line" "${1:-Unknown Error}"
}

# info "Download completel"
#   $1  required    The string to log
#
function info () {
    local _date _line _sub _file

    _date="$(command -p date "$_date_format")"
    read -r _line _sub _file < <(caller 0)

    printf "${blue}INFO${reset} [%s] <%s@%s:%s> %s\n" "$_date" "$_sub" "$_file" "$_line" "${1:-Unknown Error}"
}

# warn "Outdated version, consider updating"
#   $1  required    The string to log
#
function warn () {
    local _date _line _sub _file

    _date="$(command -p date "$_date_format")"
    read -r _line _sub _file < <(caller 0)

    printf "${yellow}WARN${reset} [%s] <%s@%s:%s> %s\n" "$_date" "$_sub" "$_file" "$_line" "${1:-Unknown Error}"
}

# error "Cloud not download dependency: $dep"
#   $1  required    The string to log
#
function error () {
    local _date _line _sub _file

    _date="$(command -p date "$_date_format")"
    read -r _line _sub _file < <(caller 0)

    >&2 printf "${red}ERROR${reset} [%s] <%s@%s:%s> %s\n" "$_date" "$_sub" "$_file" "$_line" "${1:-Unknown Error}"
    [ "${_backtrace:-FALSE}" == FALSE ] || print_backtrace 1
}

# die "Cannot open file: $file" 2
#   $1  required    The string to log
#   $2  optional    The exit code (defaults: 1)
#
function die () {
    local _date

    _date="$(command -p date "$_date_format")"
    >&2 printf "${red}${bold}FATAL${reset} [%s] %s\n" "$_date" "${1:-Unknown Error}"

    print_backtrace 1

    exit "${2:-1}"
}

# print_backtrace 1
#   $1  optional    non-negative integer representing stack frame (defaults: 0)
#
function print_backtrace () {
    local _date _frame

    _frame="${1:-0}"
    _date="$(command -p date "$_date_format")"

    >&2 printf "${red}${bold}BACKTRACE${reset} [%s] " "$_date"

    local _line _sub _file
    while read -r _line _sub _file < <(caller "$_frame"); do
        >&2 printf '%s@%s:%s <= ' "$_sub" "$_file" "$_line"
        ((_frame++))
    done

    >&2 printf '%s\n' "$SHELL"
}

#############
# Variables #
#############

DIR_CONF='./config/'
CONF_TTREE="${DIR_CONF}/ttree.cfg"
DIR_ASSETS='./assets/'
DIR_SRC='./src/'
DIR_MD='./markdown/'
DIR_DIST='./dist/'
DIR_VAR_WWW='../nginx/var_www/bmo.dev/'
CSS_SRC='style/retro/css/retro.css'
CSS_DST="${DIR_DIST}/css/style.css"
SERVE_PORT='8080'

##############
# Main Logic #
##############

# Targets
function print_help() {
    cat <<'EOF'
Automated targets:
    help:       Show this help message
    clean:      Clean up directories
    dist:       Clean, make css, make markdown, make html
    serve:      Make dist, then serve the dist directory contents using Mojo

Manual targets:
    css:        Make CSS files
    markdown:   Make markdown files
    html:       Make html files
    resume:     Make resume
EOF
    exit 0
}

function prompt_remove() {
    local _dir="$1"

    [ -e "$_dir" ] || return 0

    read -r -p "Remove “$_dir” forcibly and recursively? [yn] " yn
    [ "$yn" = "y" ] \
        || die "Bailing..."

    command -p rm -frv "$_dir" \
        || die "Failed to clean “$_dir”"

    return 0
}

function make_clean() {
    info "Cleaning up directories... “$DIR_MD” “$DIR_DIST” “$DIR_VAR_WWW”"

    prompt_remove "$DIR_MD"
    prompt_remove "$DIR_DIST"
    prompt_remove "$DIR_VAR_WWW"

    success 'Finished cleaning'
    return 0
}

function make_css() {
    info 'Creating CSS...'

    [ -d "${CSS_DST%/*}" ] || mkdir -vp "${CSS_DST%/*}"
    if command -p cp -v "$CSS_SRC" "$CSS_DST"; then
        success 'Finished creating CSS files'
        return 0
    fi

    die 'Failed to create CSS files properly'
}

function make_markdown() {
    info "Creating markdown files..."

    if command ttree -f "$CONF_TTREE"; then
        success 'Finshed creating markdown files'
        return 0
    fi

    die 'Failed to create markdown files properly'
}

function make_html() {
    info 'Creating HTML files...'

    # Remove leading dist dir
    local css_url="${CSS_DST/${DIR_DIST}/}"
    info "Using CSS url “${css_url}”"

    # Find all our markdown files and create the html
    command -p find "$DIR_MD" -type f -name '*.md' -print0 | \
        while IFS= read -r -d $'\0' file; do

            info "Working on file “$file”"

            # Pandoc will not auto create output directories
            local output="${file/${DIR_MD}/${DIR_DIST}}"
            [ -d "${output%/*}" ] \
                || command -p mkdir -vp "${output%/*}" \
                || die "Failed to create output directory “${output}”"

            command pandoc \
                --css "$css_url" \
                --from markdown \
                --to html5 \
                --standalone \
                --output "${output/%.md/.html}" \
                "$file"

        done

    # Copy assets to dist
    info "Copying “$DIR_ASSETS” to “$DIR_DIST”"
    command -p cp -avr "$DIR_ASSETS" "$DIR_DIST" \
        || die "Failed to copy “$DIR_ASSETS” to “$DIR_DIST”"

    command -p cp -av "${DIR_SRC}/robots.txt" "$DIR_DIST" \
        || die "Failed to copy “${DIR_SRC}/robots.txt” to “$DIR_DIST”"


    # Copy dist to webroot
    info "Copying “$DIR_DIST” to “$DIR_VAR_WWW”"
    command -p cp -avr "$DIR_DIST" "$DIR_VAR_WWW" \
        || die "Failed to “$DIR_DIST” to “$DIR_VAR_WWW”"

    # Drop permission
    info "Setting Permissions in “$DIR_VAR_WWW”"
    command -p find "$DIR_VAR_WWW" -type d -exec chmod -v 0750 '{}' \+ \
        || die "Failed to chmod dirs 0750 in “$DIR_VAR_WWW”"

    command -p find "$DIR_VAR_WWW" -type f -exec chmod -v 0440 '{}' \+ \
        || die "Failed to chmod files 0440 in “$DIR_VAR_WWW”"
}

function make_resume() {
    info 'Making Resume'

    local date filename
    date="$(command date '+%F')"

    if ! [ -f 'dist/hire.html' ]; then
        error "Missing source file “dist/hire.html”. Did you run “$0 dist”?"
        return 1
    fi

    filename="resume_William-E-Little-Jr_${date}.pdf"
    command perl -lne 'print if /resume-snip-begin/.../resume-snip-end/' dist/hire.html | \
        command pandoc \
            --metadata pagetitle='William E Little Jr Resume' \
            --to html5 \
            --standalone \
            --output "$filename"

    if [ -s "$filename" ]; then
        return 0
    fi

    return 1
}

function make_dist() {
    # Cleanup first
    make_clean || die 'Bailing...'

    # Create our dist directory
    [ -d "$DIR_DIST" ] || mkdir -vp "$DIR_DIST"

    # Create our CSS
    make_css || die 'Bailing...'

    # Create our markdown files 
    info 'Creating distribution files...'
    make_markdown || die 'Bailing...'

    # Create our html files
    make_html || die 'Bailing...'

    success 'Finished creating distribution files'
}

function make_serve() {
    [ -d "$DIR_DIST" ] || make_dist
    command perl -Mojo -e "app->static->paths->[0]='${DIR_DIST}'; app->start" daemon -l "http://0.0.0.0:${SERVE_PORT}"
}

# Main
[[ "$#" -eq 0 ]] && print_help
while :; do
    case $1 in
        help)
            print_help
            ;;
        clean)
            make_clean
            ;;
        css)
            make_css
            ;;
        markdown)
            make_markdown
            ;;
        html)
            make_html
            ;;
        serve)
            make_serve
            ;;
        dist)
            make_dist
            ;;
        resume)
            make_resume
            ;;
        --)
            shift
            break
            ;;
        +([a-zA-Z0-9-]))
            error "Unknown target “$1”"
            print_help
            ;;
        *)
            break
    esac
    shift
done
