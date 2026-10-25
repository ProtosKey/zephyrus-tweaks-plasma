#!/bin/bash

set -e
cd "$(dirname "$0")"

install -Dm755 -t ~/.local/bin bin/*
install -Dm644 -t ~/.local/share/applications kde/applications/*.desktop
install -Dm644 -t ~/.config/environment.d kde/environment.d/*.conf

kbuildsycoca6 >/dev/null 2>&1 || true
echo "Скрипты и ярлыки установлены!"

if [[ "$1" == --system ]]; then
    sudo install -Dm755 system/dgpu-eco-cleanup /usr/local/bin/dgpu-eco-cleanup
    sudo install -Dm644 system/dgpu-eco-cleanup.service /etc/systemd/system/dgpu-eco-cleanup.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now dgpu-eco-cleanup.service
    echo "Служба установлена и включена!"
fi

echo "Перезапустите текущую сессию"
