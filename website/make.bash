#!/usr/bin/env bash

shopt -s extglob

# Utils
readonly cf="\\033[0m"
readonly red="\\033[0;31m"
readonly green="\\033[0;32m"
readonly yellow="\\033[0;33m"
readonly purple="\\033[0;35m"

function err() {
    printf -- "[%s][${red}ERROR${cf}]: %s\n" "$(showdate)" "$1"
}

function warn() {
    printf -- "[%s][${yellow}WARNING${cf}]: %s\n" "$(showdate)" "$1"
}

function info() {
    printf -- "[%s][INFO]: %s\n" "$(showdate)" "$1"
}

function succ() {
    printf -- "[%s][${green}SUCCESS${cf}]: %s\n" "$(showdate)" "$1"
}

function showdate() {
    printf '%s' "$(command -p date '+%d/%b/%y %T %z')"
}

# Variables
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

# Targets
function print_help() {
    cat <<"EOF"
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

function make_clean() {
    info 'Cleaning up directories...'
    if command -p rm -rfv "$DIR_MD" "$DIR_DIST"; then
        succ 'Finished cleaning'
        return 0
    else
        err 'Failed to clean properly'
        return 1
    fi
}

function make_css() {
    info 'Creating CSS...'
    [ -d "${CSS_DST%/*}" ] || mkdir -vp "${CSS_DST%/*}"
    if command -p cp -v "$CSS_SRC" "$CSS_DST"; then
        succ 'Finished creating CSS files'
        return 0
    else
        err 'Failed to create CSS files properly'
        return 1
    fi
}

function make_markdown() {
    info "Creating markdown files..."
    if command ttree -f "$CONF_TTREE"; then
        succ 'Finshed creating markdown files'
        return 0
    else
        err 'Failed to create markdown files properly'
        return 1
    fi
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
            [ -d "${output%/*}" ] || mkdir -vp "${output%/*}"

            command pandoc \
                --css "$css_url" \
                --from markdown \
                --to html5 \
                --standalone \
                --output "${output/%.md/.html}" \
                "$file"

            printf '\n'
        done

    # Clean the webroot first
    info "Cleaning webroot “$DIR_VAR_WWW"
    command -p rm -rfv  "$DIR_VAR_WWW"

    # Copy assets to dist
    info "Copping assets"
    command -p cp -avr "$DIR_ASSETS" "$DIR_DIST"
    command -p cp -av "${DIR_SRC}/robots.txt" "$DIR_DIST"

    # Copy dist to webroot
    info "Copying dist to “$DIR_VAR_WWW”"
    command -p cp -avr "$DIR_DIST" "$DIR_VAR_WWW"

    # Drop permission
    info 'Reducing Permissions'
    command -p find "$DIR_VAR_WWW" -type d -exec chmod -v 0750 '{}' \+
    command -p find "$DIR_VAR_WWW" -type f -exec chmod -v 0440 '{}' \+
}

function make_resume() {
    info 'Making Resume'

    local date filename
    date="$(command date '+%F')"

    if ! [ -f 'dist/hire.html' ]; then
        err "Missing source file “dist/hire.html”. Did you run “$0 dist”?"
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
    if ! make_clean; then
        err 'Bailing...'
        return 1
    fi

    # Create our dist directory
    [ -d "$DIR_DIST" ] || mkdir -vp "$DIR_DIST"

    # Create our CSS
    if ! make_css; then
        err 'Bailing...'
        return 1
    fi

    # Create our markdown files 
    info 'Creating distribution files...'
    if ! make_markdown; then
        err 'Bailing...'
        return 1
    fi

    # Create our html files
    if ! make_html; then
        err 'Bailing...'
        return 1
    fi

    succ 'Finished creating distribution files'
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
            err "Unknown target “$1”"
            print_help
            ;;
        *)
            break
    esac
    shift
done
