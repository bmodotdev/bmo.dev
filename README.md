# [bmo.dev](https://bmo.dev)
This is the source code and orchestration to my personal website!

## Website source code
The actual source code to the website is in the [website](./website) directory.

## Orchestration
I use Nginx to serve static content, and Certbot to provision the TLS/SSL certificates.

## Volumes
Two volumes are created
* certbot-conf: This exposes the TLS/SSL certificates from Certbot to Nginx
* certbot-www: This exposes the certbot `/.well-known/acme-challenge/` document root from Nginx
to Certbot

## The chicken or the egg problem
The objective is to stand up both of these services at the same time using a single
`docker-compose up -d`. The problem is that my nginx configuration already has an SSL vhost
entry, which will cause Nginx to fail when started. Conversely, Certbot *needs* Nginx running
to perform the HTTP DCV(Domain Control Validation).

Well, there are two other options I can think of...

### DNS DCV
I could use DNS DCV; however, it would require that I
either self-host my DNS or I would need to expose a DNS API key of my provider. I do not
currently self-host my DNS, and I also do not want to worry about exposing a DNS API key to
my webserver.

### Certbot’s [standalone](https://eff-certbot.readthedocs.io/en/stable/using.html#standalone) webserver
The Certbot service provides it’s own builtin webserver that allows you to perform HTTP DCV
without needing one yourself. This is awesome in itself; however, how do I trigger the docker
nginx service to start once Certbot has provisioned the SSL CRT?

### Chicken or the egg: Why not both?
If I want to use Nginx for HTTP DCV, but I already have a SSL vhost, then I must break the
SSL vhost and non-SSL vhost into [two separate configs](./nginx/etc_nginx/conf.d). Now I
need a method to enable and disable my [bmo.dev_SSL.conf](./nginx/etc_nginx/conf.d/bmo.dev_SSL.conf)
and a method to know when to enable it.

The Nginx docker image allows you to virtually customize anything about the build through it’s docker
[ENTRYPOINT](https://github.com/nginxinc/docker-nginx/blob/master/stable/debian/docker-entrypoint.sh).
This script checks for scripts at `/docker-entrypoint.d/*.sh` and executes them in order. If
any script exits with a non-zero exit code, the container fails to start. So we'll simply
add a script that opens `/etc/nginx/conf.d/*_SSL.conf` files, and if any of the 
`ssl_certificate*` directives fail to exist, we will rename the file by appending “.disabled”.

With this change, Nginx can now start a full configuration, which means Certbot’s HTTP DCV
attempts will succeed. Once Certbot retrieves a TLS/SSL certificate for the site, it will
expose it to the Nginx container via the `certbot-conf` volume.

Now we just need to watch this directory, re-enable our `bmo.dev_SSL.conf`, and reload Nginx.
To watch, we’ll just use our [Nginx Dockerfile](./nginx/Dockerfile) to install the apt
package [inotify-tools](https://github.com/inotify-tools/inotify-tools). Now we just invoke
`inotifywait` followed by a `while read` loop and launch it into the background.

### TL;DR
We can launch both Certbot and Nginx services at the same time by splitting our SSL and
non-SSL vhosts into two files. Then we simply make use of Nginx's ENTRYPOINT script to
launch a basic bash script to enable or disable SSL vhosts when their corresponding SSL/TLS
certificates are available.
