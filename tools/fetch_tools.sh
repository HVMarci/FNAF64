#!/bin/bash
# Downloads KickAssembler into tools/kickass and copies the Sparkle binary from the Sparkle3.3 directory.
cd "$(dirname "$0")"
[ -f kickass/KickAss.jar ] || { curl -sL -o ka.zip https://theweb.dk/KickAssembler/KickAssembler.zip && unzip -oq ka.zip -d kickass && rm ka.zip; }
[ -x sparkle ] || { cp ../Sparkle3.3/bin/linux_amd64_static/sparkle sparkle && chmod +x sparkle; }
