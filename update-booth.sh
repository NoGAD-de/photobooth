#!/bin/bash

# Stop on the first sign of trouble
set -e

function info {
    echo -e "\033[0;36m${1}\033[0m"
}

function error {
    echo -e "\033[0;31m${1}\033[0m"
}

if [ $UID != 0 ]; then
    error "ERROR: Only root is allowed to execute the installer. Forgot sudo?"
    exit 1
fi

if [[ ! -z $1 ]]; then
    booth_source=$1
    info "Updating Photobooth located at: ${booth_source}"
else
    error "ERROR: Usage: update-booth.sh 'Photobooth path'"
    exit 2
fi

OLDFILES=(
    'login.php'
    'logout.php'
    'admin/config.json'
    'resources/fonts/style.css'
)

WEBSERVER=(
    'libapache2-mod-php'
    'nginx'
    'lighttpd'
)

COMMON_PACKAGES=(
    'git'
    'gphoto2'
    'libimage-exiftool-perl'
    'php-gd'
    'yarn'
)

if [[ ! -d "${booth_source}" ]]; then
    mkdir -p "${booth_source}"
fi

info "[Info] Updating system"
apt update
apt dist-upgrade -y

info "[Info] Checking for webserver..."
for server in "${WEBSERVER[@]}"; do
    if [ $(dpkg-query -W -f='${Status}' ${server} 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
        info "[Webserver] ${server} installed"
        if [[ ${server} == "nginx" || ${server} == "lighttpd" ]]; then
            info "[NOTE] You're using ${server} as your Webserver. For a no-hassle-setup Apache2 Webserver is recommend!"
            if [ $(dpkg-query -W -f='${Status}' ${server} 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
                info "[Package] php-fpm installed already"
            else
                info "[Package Install] Installing missing common package: ${server}"
                apt install -y php-fpm
            fi
        fi
    fi
done

info "[Info] Checking common software..."
for package in "${COMMON_PACKAGES[@]}"; do
    if [ $(dpkg-query -W -f='${Status}' ${package} 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
        info "[Package] ${package} installed already"
    else
        info "[Package Install] Installing missing common package: ${package}"
        if [[ ${package} == "yarn" ]]; then
                curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
                echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
                apt update
        fi
        apt install -y ${package}
    fi
done

cp -rf ./* "${booth_source}/"
chown -R www-data:www-data ${booth_source}

for file in "${OLDFILES[@]}"; do
    if [ -f "${booth_source}/${file}" ]; then
        info "[Info] Deleting unused file: ${booth_source}/${file}"
        rm "${booth_source}/${file}"
    fi
done

info "[Info] Updated Photobooth"
