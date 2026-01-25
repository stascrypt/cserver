#!/bin/bash

set -e

MAIN_DIR="/root"
INSTALL_DIR="/root"
SERVER_DIR="cs"

VERSION_ID=$(awk -F= '$1 == "VERSION_ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)
ID=$(awk -F= '$1 == "ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)

if [[ "$ID" == "ubuntu" ]]; then
    if [[ "$VERSION_ID" == "22.04" ]] || [[ "$VERSION_ID" == "24.04" ]]; then
        bits_lib_32="lib32gcc-s1 lib32stdc++6 bc"
    else
        bits_lib_32="lib32gcc1 lib32stdc++6 bc"
    fi
elif [[ "$ID" == "debian" ]] && [[ "$VERSION_ID" -ge 11 ]]; then
    bits_lib_32="lib32gcc-s1 lib32stdc++6 bc"
else
    bits_lib_32="lib32gcc1 lib32stdc++6 bc"
fi

echo "-------------------------------------------------------------------------------"
echo                 "Installing Counter Strike 1.6 Server"
echo "-------------------------------------------------------------------------------"

rehlds_url=$(wget -qO - https://img.shields.io/github/v/release/dreamstalker/rehlds.svg | grep -oP '(?<=release: v)[0-9.]*(?=</title>)' | head -n1)
regamedll_url=$(wget -qO - https://img.shields.io/github/release/s1lentq/ReGameDLL_CS.svg | grep -oP '(?<=release: v)[0-9.]*(?=</title>)' | head -n1)
metamodr_url=$(wget -qO - https://img.shields.io/github/release/theAsmodai/metamod-r.svg | grep -oP '(?<=release: v)[0-9.]*(?=</title>)' | head -n1)

reunion_version=$(wget -qO - "https://img.shields.io/github/v/release/s1lentq/reunion.svg?include_prereleases" | grep -oP '(?<=release: v)[0-9.]*(?=</title>)' | head -n1)

# ReAPI (rehlds/ReAPI)
reapi_version=$(wget -qO - https://img.shields.io/github/v/release/rehlds/ReAPI.svg | grep -oP '(?<=release: v)[0-9.]*(?=</title>)' | head -n1)

amxx_version=$(wget -T 5 -qO - https://raw.githubusercontent.com/lukasenka/rehlds-versions/main/amxx-version.txt)
amxx_build=$(wget -T 5 -qO - https://raw.githubusercontent.com/lukasenka/rehlds-versions/main/amxx-build.txt)

echo "-------------------------------------------------------------------------------"
echo "ReHLDS:      $rehlds_url"
echo "ReGameDLL:   $regamedll_url"
echo "Metamod-r:   $metamodr_url"
echo "Reunion:     $reunion_version"
echo "AMXX:        $amxx_version build $amxx_build"
echo "ReAPI:       $reapi_version"
echo "-------------------------------------------------------------------------------"

generate_random_string() {
  local length=$1
  tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length
}

check_packages() {
    echo "Checking required packages..."
    BIT64_CHECK=false && [ "$(getconf LONG_BIT)" == "64" ] && BIT64_CHECK=true

    LIB_CHECK=true
    for lib in $bits_lib_32; do
        if [ "$((dpkg --get-selections $lib 2>/dev/null | egrep -o '(de)?install'))" != "install" ]; then
            LIB_CHECK=false
            break
        fi
    done

    SCREEN_CHECK=false && [ "$((dpkg --get-selections screen 2>/dev/null | egrep -o '(de)?install'))" = "install" ] && SCREEN_CHECK=true
    UNZIP_CHECK=false && [ "$((dpkg --get-selections unzip 2>/dev/null | egrep -o '(de)?install'))" = "install" ] && UNZIP_CHECK=true
    CURL_CHECK=false && [ "$((dpkg --get-selections curl 2>/dev/null | egrep -o '(de)?install'))" = "install" ] && CURL_CHECK=true

    apt-get -y update

    if $BIT64_CHECK && ! $LIB_CHECK; then
        apt-get -y install $bits_lib_32
    fi
    if ! $SCREEN_CHECK; then apt-get -y install screen; fi
    if ! $UNZIP_CHECK;  then apt-get -y install unzip; fi
    if ! $CURL_CHECK;   then apt-get -y install curl; fi
}

check_dir() {
    echo "-------------------------------------------------------------------------------"
    INSTALL_DIR="/root"
    SERVER_DIR="cs"
    mkdir -p /root
    cd /root
    echo                 "Server will be installed into '/root'"
    echo "-------------------------------------------------------------------------------"
}

download_files_steamcmd() {
    echo "[ReHLDS] Using SteamCMD app_update 90..."
    mkdir -p $INSTALL_DIR/steamcmd
    cd $INSTALL_DIR/steamcmd

    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

    if [ ! -e "steamcmd.sh" ]; then
        echo "[SteamCMD] Error: cannot download SteamCMD. Aborting..."
        exit 1
    fi

    ./steamcmd.sh +force_install_dir $INSTALL_DIR +login anonymous \
        +app_update 90 -beta steam_legacy validate +quit

    EXITVAL=$?
    if [ $EXITVAL -gt 0 ]; then
        echo "-------------------------------------------------------------------------------"
        echo                 "SteamCMD internal error: $EXITVAL"
        echo                 "Aborting..."
        exit 1
    fi

    cd $INSTALL_DIR
    chmod +x hlds_run hlds_linux
}

check_packages
check_dir

METAMOD=$((1<<0))
DPROTO=$((1<<1))
AMXMODX=$((1<<2))
CHANGES=$((1<<3))
REGAMEDLL=$((1<<4))
REAPI=$((1<<5))

INSTALL_TYPE=0
INSTALL_TYPE=$(($INSTALL_TYPE|$METAMOD))
INSTALL_TYPE=$(($INSTALL_TYPE|$DPROTO))
INSTALL_TYPE=$(($INSTALL_TYPE|$AMXMODX))
INSTALL_TYPE=$(($INSTALL_TYPE|$CHANGES))
INSTALL_TYPE=$(($INSTALL_TYPE|$REGAMEDLL))
INSTALL_TYPE=$(($INSTALL_TYPE|$REAPI))

echo "-------------------------------------------------------------------------------"
echo                  "Downloading HLDS base files..."
echo "-------------------------------------------------------------------------------"

download_files_steamcmd

if [ ! -d "$INSTALL_DIR/cstrike" ] || [ ! -f "$INSTALL_DIR/hlds_run" ] || [ ! -e "$INSTALL_DIR/cstrike/liblist.gam" ]; then
    echo "Error: Failed to download server files."
    exit 1
fi

cd $INSTALL_DIR

echo "-------------------------------------------------------------------------------"
echo         "Installing ReHLDS + Metamod-r + Reunion + AMXX + ReGameDLL + ReAPI..."
echo "-------------------------------------------------------------------------------"

if [ $(($INSTALL_TYPE&$METAMOD)) != 0 ]; then
    echo "Installing ReHLDS v. ${rehlds_url} and Metamod v. ${metamodr_url}..."
    sleep 2

    mkdir -p cstrike/addons/metamod/dlls

    wget -q "https://github.com/dreamstalker/rehlds/releases/download/${rehlds_url}/rehlds-bin-${rehlds_url}.zip"
    unzip -q "rehlds-bin-${rehlds_url}.zip"
    rm -rf hlsdk

    mv $INSTALL_DIR/bin/linux32/valve/dlls/director.so $INSTALL_DIR/valve/dlls/directors.so
    cd $INSTALL_DIR/valve/dlls
    rm -f director.so
    mv directors.so director.so

    cd $INSTALL_DIR/bin/linux32
    mv proxy.so $INSTALL_DIR/proxys.so
    cd $INSTALL_DIR
    rm -f proxy.so
    mv proxys.so proxy.so

    cd $INSTALL_DIR/bin/linux32
    mv hltv $INSTALL_DIR/hltvs
    cd $INSTALL_DIR
    rm -f hltv
    mv hltvs hltv

    cd $INSTALL_DIR/bin/linux32
    mv demoplayer.so $INSTALL_DIR/demoplayers.so
    cd $INSTALL_DIR
    rm -f demoplayer.so
    mv demoplayers.so demoplayer.so

    cd $INSTALL_DIR/bin/linux32
    mv core.so $INSTALL_DIR/cores.so
    cd $INSTALL_DIR
    rm -f core.so
    mv cores.so core.so

    cd $INSTALL_DIR/bin/linux32
    mv hlds_linux $INSTALL_DIR/hlds_linuxs
    cd $INSTALL_DIR
    rm -f hlds_linux
    mv hlds_linuxs hlds_linux
    chmod +x hlds_linux

    cd $INSTALL_DIR/bin/linux32
    mv engine_i486.so $INSTALL_DIR/engine_i486s.so
    cd $INSTALL_DIR
    rm -f engine_i486.so
    mv engine_i486s.so engine_i486.so

    rm -rf bin
    rm -f rehlds-bin-${rehlds_url}.zip

    echo "ReHLDS ${rehlds_url} installed successfully!"
    sleep 2

    mkdir -p $INSTALL_DIR/meta
    cd $INSTALL_DIR/meta

    wget -q "https://github.com/theAsmodai/metamod-r/releases/download/${metamodr_url}/metamod-bin-${metamodr_url}.zip"
    unzip -q "metamod-bin-${metamodr_url}.zip"

    cd $INSTALL_DIR/meta/addons/metamod
    mv metamod_i386.so $INSTALL_DIR/cstrike/addons/metamod/dlls/metamod_i386s.so
    mv config.ini $INSTALL_DIR/cstrike/addons/metamod/dlls/config.ini

    cd $INSTALL_DIR/cstrike/addons/metamod/dlls
    rm -f metamod_i386.so
    mv metamod_i386s.so metamod_i386.so

    cd $INSTALL_DIR
    rm -rf meta

    echo "Metamod ${metamodr_url} installed successfully!"
    sleep 2

    if [ ! -e "cstrike/addons/metamod/dlls/metamod_i386.so" ]; then
        echo "Error: Metamod or engine files missing. Aborting..."
        exit 1
    fi

    sed -r -i s/gamedll_linux.+/"gamedll_linux \"addons\/metamod\/dlls\/metamod_i386.so\""/ cstrike/liblist.gam
fi

if [ $(($INSTALL_TYPE&$DPROTO)) != 0 ]; then
    echo "Installing Reunion v. ${reunion_version}..."
    sleep 2

    mkdir -p cstrike/addons/reunion

    mkdir -p $INSTALL_DIR/reu-temp
    cd $INSTALL_DIR/reu-temp

    wget -q "https://github.com/s1lentq/reunion/releases/download/${reunion_version}/reunion-${reunion_version}.zip"

    if [ ! -e "reunion-${reunion_version}.zip" ]; then
        echo "Error: failed to download Reunion. Aborting..."
        exit 1
    fi

    unzip -q "reunion-${reunion_version}.zip"

    if [ -d "reunion_${reunion_version}" ]; then
        cd "reunion_${reunion_version}"

        random_string=$(generate_random_string 34)
        sed -i "s/^SteamIdHashSalt =.*/SteamIdHashSalt = $random_string/" reunion.cfg
        sed -i 's/cid_NoSteam47 = [0-9]\+/cid_NoSteam47 = 3/' reunion.cfg
        sed -i 's/cid_NoSteam48 = [0-9]\+/cid_NoSteam48 = 3/' reunion.cfg

        mv reunion.cfg $INSTALL_DIR/cstrike

        cd bin/Linux
        mv reunion_mm_i386.so $INSTALL_DIR/cstrike/addons/reunion
    else
        random_string=$(generate_random_string 34)
        sed -i "s/^SteamIdHashSalt =.*/SteamIdHashSalt = $random_string/" reunion.cfg
        sed -i 's/cid_NoSteam47 = [0-9]\+/cid_NoSteam47 = 3/' reunion.cfg
        sed -i 's/cid_NoSteam48 = [0-9]\+/cid_NoSteam48 = 3/' reunion.cfg

        mv reunion.cfg $INSTALL_DIR/cstrike

        if [ -d "bin" ]; then
            cd bin/Linux
            mv reunion_mm_i386.so $INSTALL_DIR/cstrike/addons/reunion
        else
            cd addons/reunion
            mv reunion_mm_i386.so $INSTALL_DIR/cstrike/addons/reunion
        fi
    fi

    cd $INSTALL_DIR
    rm -rf reu-temp

    if [ ! -e "cstrike/addons/reunion/reunion_mm_i386.so" ] || [ ! -e "cstrike/reunion.cfg" ]; then
        echo "Error: Reunion installation failed. Aborting..."
        exit 1
    fi

    echo "Reunion ${reunion_version} installed successfully!"
    sleep 2

    echo "linux addons/reunion/reunion_mm_i386.so" >> cstrike/addons/metamod/plugins.ini
fi

if [ $(($INSTALL_TYPE&$AMXMODX)) != 0 ]; then
    echo "Installing AMXX v. $amxx_version (Build: $amxx_build) ..."
    sleep 2

    cd $INSTALL_DIR

    wget -q -P cstrike "https://www.amxmodx.org/amxxdrop/${amxx_version}/amxmodx-${amxx_build}-base-linux.tar.gz"
    if [ ! -e "cstrike/amxmodx-${amxx_build}-base-linux.tar.gz" ]; then
        echo "Error: AMXX base package not found. Aborting..."
        exit 1
    fi
    tar -xzf "cstrike/amxmodx-${amxx_build}-base-linux.tar.gz" -C cstrike
    rm "cstrike/amxmodx-${amxx_build}-base-linux.tar.gz"

    echo "linux addons/amxmodx/dlls/amxmodx_mm_i386.so" >> cstrike/addons/metamod/plugins.ini

    mkdir -p $INSTALL_DIR/temp
    cd $INSTALL_DIR/temp

    wget -q "https://www.amxmodx.org/amxxdrop/${amxx_version}/amxmodx-${amxx_build}-cstrike-linux.tar.gz"
    if [ ! -e "amxmodx-${amxx_build}-cstrike-linux.tar.gz" ]; then
        echo "Error: AMXX cstrike package missing. Aborting..."
        exit 1
    fi

    tar -xzf "amxmodx-${amxx_build}-cstrike-linux.tar.gz"

    cd $INSTALL_DIR/temp/addons/amxmodx/scripting
    mv statsx.sma               $INSTALL_DIR/cstrike/addons/amxmodx/scripting/statsx.sma
    mv stats_logging.sma        $INSTALL_DIR/cstrike/addons/amxmodx/scripting/stats_logging.sma
    mv restmenu.sma             $INSTALL_DIR/cstrike/addons/amxmodx/scripting/restmenu.sma
    mv miscstats.sma            $INSTALL_DIR/cstrike/addons/amxmodx/scripting/miscstats.sma
    mv csstats.sma              $INSTALL_DIR/cstrike/addons/amxmodx/scripting/csstats.sma

    cd $INSTALL_DIR/temp/addons/amxmodx/plugins
    mv statsx.amxx              $INSTALL_DIR/cstrike/addons/amxmodx/plugins/statsx.amxx
    mv restmenu.amxx            $INSTALL_DIR/cstrike/addons/amxmodx/plugins/restmenu.amxx
    mv miscstats.amxx           $INSTALL_DIR/cstrike/addons/amxmodx/plugins/miscstats.amxx
    mv stats_logging.amxx       $INSTALL_DIR/cstrike/addons/amxmodx/plugins/stats_logging.amxx

    cd $INSTALL_DIR/temp/addons/amxmodx/modules
    mv csx_amxx_i386.so         $INSTALL_DIR/cstrike/addons/amxmodx/modules/csx_amxx_i386.so
    mv cstrike_amxx_i386.so     $INSTALL_DIR/cstrike/addons/amxmodx/modules/cstrike_amxx_i386.so

    cd $INSTALL_DIR/temp/addons/amxmodx/data
    mv csstats.amxx             $INSTALL_DIR/cstrike/addons/amxmodx/data/csstats.amxx

    cd $INSTALL_DIR/temp/addons/amxmodx/configs
    mv stats.ini    $INSTALL_DIR/cstrike/addons/amxmodx/configs/statss.ini
    mv plugins.ini  $INSTALL_DIR/cstrike/addons/amxmodx/configs/pluginss.ini
    mv modules.ini  $INSTALL_DIR/cstrike/addons/amxmodx/configs/moduless.ini
    mv maps.ini     $INSTALL_DIR/cstrike/addons/amxmodx/configs/mapss.ini
    mv cvars.ini    $INSTALL_DIR/cstrike/addons/amxmodx/configs/cvarss.ini
    mv core.ini     $INSTALL_DIR/cstrike/addons/amxmodx/configs/cores.ini
    mv cmds.ini     $INSTALL_DIR/cstrike/addons/amxmodx/configs/cmdss.ini
    mv amxx.cfg     $INSTALL_DIR/cstrike/addons/amxmodx/configs/amxxs.cfg

    cd $INSTALL_DIR/cstrike/addons/amxmodx/configs
    rm -f plugins.ini modules.ini maps.ini cvars.ini core.ini cmds.ini amxx.cfg

    mv pluginss.ini plugins.ini
    mv statss.ini   stats.ini
    mv moduless.ini modules.ini
    mv mapss.ini    maps.ini
    mv cvarss.ini   cvars.ini
    mv cores.ini    core.ini
    mv cmdss.ini    cmds.ini
    mv amxxs.cfg    amxx.cfg

    cd $INSTALL_DIR
    rm -rf temp

    echo "AMXX installed."
fi

# ----------- server.cfg ------------
if [ $(($INSTALL_TYPE&$CHANGES)) != 0 ]; then
    echo "Creating server.cfg stub (insert your config here)..."

    cat > $INSTALL_DIR/cstrike/server.cfg << 'EOF'
hostname "Conгter-Strike "
rcon_password "12385426878"
sv_password ""
sv_lan 0
sv_contact ""
sv_downloadurl "http://<ip>:6789"
sv_allowdownload 1
sv_allowupload 1

// =============================
// NETWORK 
// =============================
sv_maxrate 1000000
sv_minrate 25000
sv_maxupdaterate 102
sv_minupdaterate 20
sv_maxcmdrate 102
sv_mincmdrate 20
sv_unlag 1
sv_maxunlag 0.5
sv_unlagsamples 1

sys_ticrate 1000
fps_max 300

sv_timeout 65

// =============================
// GAMEPLAY
// =============================
mp_timelimit 30
mp_freezetime 3
mp_roundtime 3
mp_c4timer 35
mp_buytime 0.5
mp_forcechasecam 0
mp_forcecamera 0
mp_fadetoblack 0
mp_chattime 10
mp_playerid 0
mp_footsteps 1
mp_flashlight 1
mp_autokick 0
mp_autoteambalance 0
mp_limitteams 0
mp_tkpunish 0
mp_hostagepenalty 0

// Мультипликаторы урона
mp_damage_head 4.0
mp_damage_chest 1.0
mp_damage_stomach 1.25
mp_damage_arm 1.0
mp_damage_leg 0.75

// Мани-система 
mp_startmoney 1000
mp_maxmoney 16000
mp_afterroundmoney 0

// =============================
// PHYSICS
// =============================
sv_gravity 800
sv_airaccelerate 10
sv_accelerate 5
sv_friction 4
sv_stepsize 18
sv_stopspeed 75
sv_wateraccelerate 10
sv_waterfriction 1
sv_maxspeed 320
sv_spectatormaxspeed 500

// =============================
// VOICE
// =============================
sv_voiceenable 1
sv_alltalk 0
sv_voicecodec vaudio_speex
sv_voicequality 5

// =============================
// LOGGING
// =============================
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1
sv_log_onefile 0
mp_logdetail 3
mp_logmessages 1

// =============================
// VALIDATION
// =============================
sv_cheats 0
sv_consistency 1
sv_pure 1
sv_pure_kick_clients 0

// =============================
// REGION
// =============================
sv_region 255

// =============================
// FILES
// =============================
mapcyclefile "mapcycle.txt"
motdfile "motd.txt"
motd_write_once 1
banid_file "banned.cfg"
listip_file "listip.cfg"
writeid
writeip

// =============================
// EXEC CHAINS
// =============================
exec rehlds.cfg
exec banned.cfg
exec listip.cfg
exec amxx.cfg

EOF


    echo "server.cfg created. Replace its contents with your own config."
fi

if [ $(($INSTALL_TYPE&$REGAMEDLL)) != 0 ]; then
    echo "Installing ReGameDLL v. ${regamedll_url}..."
    sleep 2

    cd $INSTALL_DIR

    wget -q "https://github.com/s1lentq/ReGameDLL_CS/releases/download/${regamedll_url}/regamedll-bin-${regamedll_url}.zip"
    if [ ! -e "regamedll-bin-${regamedll_url}.zip" ]; then
        echo "Error: Cannot download ReGameDLL. Aborting..."
        exit 1
    fi

    unzip -q "regamedll-bin-${regamedll_url}.zip"
    rm -rf cssdk

    cd $INSTALL_DIR/bin/linux32/cstrike/dlls
    mv cs.so $INSTALL_DIR/cstrike/dlls/css.so
    cd $INSTALL_DIR/cstrike/dlls
    rm -f cs.so
    mv css.so cs.so

    cd $INSTALL_DIR/bin/linux32/cstrike
    mv game_init.cfg $INSTALL_DIR/cstrike
    mv game.cfg      $INSTALL_DIR/cstrike
    mv delta.lst     $INSTALL_DIR/cstrike

    cd $INSTALL_DIR
    rm -rf bin
    rm -f regamedll-bin-${regamedll_url}.zip
fi

# -------------------- ReAPI ----------------------------------------
if [ $(($INSTALL_TYPE&$REAPI)) != 0 ]; then
    echo "Installing ReAPI v. ${reapi_version}..."
    sleep 2

    mkdir -p $INSTALL_DIR/reapi-temp
    cd $INSTALL_DIR/reapi-temp

    wget -q "https://github.com/rehlds/ReAPI/releases/download/${reapi_version}/reapi-bin-${reapi_version}.zip"
    if [ ! -e "reapi-bin-${reapi_version}.zip" ]; then
        echo "Error: Cannot download ReAPI. Aborting..."
        exit 1
    fi

    unzip -q "reapi-bin-${reapi_version}.zip"

    REAPI_SO_PATH=$(find . -type f -name "reapi_amxx_i386.so" | head -n1)
    REAPI_INC_PATH=$(find . -type f -name "reapi.inc" | head -n1)

    if [ -z "$REAPI_SO_PATH" ] || [ -z "$REAPI_INC_PATH" ]; then
        echo "Error: ReAPI files not found in archive. Aborting..."
        exit 1
    fi

    mkdir -p $INSTALL_DIR/cstrike/addons/amxmodx/modules
    mkdir -p $INSTALL_DIR/cstrike/addons/amxmodx/scripting/include

    cp "$REAPI_SO_PATH"  "$INSTALL_DIR/cstrike/addons/amxmodx/modules/"
    cp "$REAPI_INC_PATH" "$INSTALL_DIR/cstrike/addons/amxmodx/scripting/include/"

    cd $INSTALL_DIR
    rm -rf reapi-temp

    echo "ReAPI ${reapi_version} installed successfully!"
fi

# -------------------- modules.ini ------------------------------------
cat > /root/cstrike/addons/amxmodx/configs/modules.ini << 'EOF'
;mysql
;sqlite
fun
geoip
sockets
regex
nvault
reapi
EOF

echo "Creating helper scripts (start-line, start, stop, restart, console)..."

cat > /root/start-line << 'EOF'
#!/bin/bash

export LD_LIBRARY_PATH=".:$LD_LIBRARY_PATH"
export HOME="/root"
export STEAM_RUNTIME=0

/root/hlds_linux \
    -game cstrike \
    -strictportbind \
    +ip 0.0.0.0 \
    -port 27015 \
    +map de_dust2 \
    -maxplayers 32 \
    +pingboost 3 \
    +sys_ticrate 1000
EOF
chmod +x /root/start-line

cat > /root/start << 'EOF'
#!/bin/bash
supervisorctl start cs
EOF
chmod +x /root/start

cat > /root/stop << 'EOF'
#!/bin/bash
supervisorctl stop cs
EOF
chmod +x /root/stop

cat > /root/restart << 'EOF'
#!/bin/bash
supervisorctl stop cs
supervisorctl start cs
EOF
chmod +x /root/restart

cat > /root/console << 'EOF'
#!/bin/bash
supervisorctl fg cs
EOF
chmod +x /root/console

echo "Helper scripts created."

echo "Patching hlds_run restart logic..."

cd $INSTALL_DIR
sed -i 's/if test \$retval -eq 0 && test -z "\$RESTART" ; then/if test \$retval -eq 0 ; then/' hlds_run
sed -i 's/debugcore \$retval/debugcore \$retval\n\n\t\t\tif test -z "\$RESTART" ; then\n\t\t\t\tbreak;\n\t\t\tfi/' hlds_run
sed -i 's/if test -n "\$DEBUG" ; then/if test "\$DEBUG" -eq 1; then/' hlds_run

if [ ! -e "$INSTALL_DIR/steam_appid.txt" ]; then
    echo "10" > steam_appid.txt
fi

echo "Detecting external IP..."

EXTERNAL_IP=$(curl -s https://api.ipify.org)

if [ -z "$EXTERNAL_IP" ]; then
    echo "ERROR: External IP not detected"
    exit 1
fi

echo "External IP detected: $EXTERNAL_IP"

echo "Updating server.cfg and motd.txt..."

sed -i "s|http://<ip>:6789|http://${EXTERNAL_IP}:6789|g" /root/cstrike/server.cfg

cat > /root/cstrike/motd.txt <<EOF
<html>
<body style="margin:0; padding:0; background:#000;">
<img src="http://${EXTERNAL_IP}:6789/banner/banner.jpg"
     style="width:100%; height:auto; display:block;" />
</body>
</html>
EOF

echo "server.cfg and motd.txt updated successfully"

echo "-------------------------------------------------------------------------------"
echo "Server installed in directory: '$INSTALL_DIR'"
echo "[INFO] Installed versions:"
echo "  ReHLDS:     ${rehlds_url}"
echo "  Metamod-r:  ${metamodr_url}"
echo "  Reunion:    ${reunion_version}"
echo "  AMXX:       ${amxx_version} build ${amxx_build}"
echo "  ReGameDLL:  ${regamedll_url}"
echo "  ReAPI:      ${reapi_version}"
echo "-------------------------------------------------------------------------------"
echo "Scripts:"
echo "  ./start       – start server"
echo "  ./stop        – stop server"
echo "  ./restart     – restart server"
echo "  ./console     – console server"
echo "-------------------------------------------------------------------------------"

exit 0
