#!/bin/bash
# Runtime entrypoint: start desktop stack then launch Hantek app
echo "Access the Hantek software at: http://localhost:6080/vnc.html"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
