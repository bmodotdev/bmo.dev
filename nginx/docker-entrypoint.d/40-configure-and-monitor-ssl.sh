#!/usr/bin/env bash

function check_ssl_certificate() {
    local sslconf="$1"
    [ -f "$sslconf" ] || return

    # Get domain
    local domain
    domain="${sslconf##*/}"
    domain="${sslconf%_*}"

    local crt directive
    command -p grep -oP '^\s+ssl_certificate(?:_key)?\s+(\S+)(?=;)' "$sslconf" | while read -r line
        do crt="${line##* }"
        if [ ! -f "$crt" ]; then
            printf 'Disabling SSL vhost, missing certificate in "%s": %s\n' "$sslconf" "$line"
            command -p mv -v "$sslconf" "$sslconf".disabled
            return
	    fi
    done
}

function watch_ssl_certificates() {
    local file domain
    command -p inotifywait -r -m /etc/letsencrypt/live/ -e create -e modify -e move --format '%w%f' | while read -r file
        do [[ -f "$file" ]] || continue
        domain="${file%/*}"
        domain="${domain##*/}"
	    [ -f "/etc/nginx/conf.d/${domain}_SSL.conf.disabled" ]  && mv -v "/etc/nginx/conf.d/${domain}_SSL.conf"{.disabled,}
	    [ -f "/etc/nginx/conf.d/${domain}_SSL.conf" ]           && nginx -t && nginx -s reload
    done
}

# Ensure all SSL vhost configs have a SSL CRT/KEY
for sslconf in /etc/nginx/conf.d/*_SSL.conf
    do check_ssl_certificate "$sslconf"
done

# Start our SSL CRT watcher
watch_ssl_certificates &
