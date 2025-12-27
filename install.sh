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

rehlds_url=$(wget -qO - https://img.shields.io/github/v/release/dreamstalker/rehlds.svg | grep -oP '(?<=release: v)[0-9.]*(?=</title>)')
regamedll_url=$(wget -qO - https://img.shields.io/github/release/s1lentq/ReGameDLL_CS.svg | grep -oP '(?<=release: v)[0-9.]*(?=</title>)')
metamodr_url=$(wget -qO - https://img.shields.io/github/release/theAsmodai/metamod-r.svg | grep -oP '(?<=release: v)[0-9.]*(?=</title>)')

reunion_version=$(wget -qO - "https://img.shields.io/github/v/release/s1lentq/reunion.svg?include_prereleases" | grep -oP '(?<=release: v)[0-9.]*(?=</title>)')

amxx_version=$(wget -T 5 -qO - https://raw.githubusercontent.com/lukasenka/rehlds-versions/main/amxx-version.txt)
amxx_build=$(wget -T 5 -qO - https://raw.githubusercontent.com/lukasenka/rehlds-versions/main/amxx-build.txt)

echo "-------------------------------------------------------------------------------"
echo "ReHLDS:      $rehlds_url"
echo "ReGameDLL:   $regamedll_url"
echo "Metamod-r:   $metamodr_url"
echo "Reunion:     $reunion_version"
echo "AMXX:        $amxx_version build $amxx_build"
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

check_speed() {
    echo "[ReHLDS] Checking download speed..."
    speed=$(wget -O /dev/null http://speedtest.tele2.net/10MB.zip 2>&1 | grep -o '[0-9.]* [KM]B/s' | tail -1)
    echo "[ReHLDS] Speed: $speed"

    if [[ $speed == *"MB/s"* ]]; then
        download_speed=$(echo $speed | awk '{print $1 * 8}')
    else
        download_speed=$(echo $speed | awk '{print $1 / 1000 * 8}')
    fi
    echo $download_speed
}

download_files_arch() {
    echo "[ReHLDS] Using Dropbox hlds.tar.gz..."
    cd $INSTALL_DIR
    wget -O _hlds.tar.gz "https://www.dropbox.com/scl/fi/qddwy787rbc751lt5v00v/hlds.tar.gz?rlkey=jbvxybo63cu4fg2fipwuxhywx&st=20xpq6at&dl=1"
    if [ ! -e "_hlds.tar.gz" ]; then
        echo "Error: Could not download server files. Aborting..."
        exit 1
    fi
    tar zxvf _hlds.tar.gz
    rm _hlds.tar.gz
    chmod +x hlds_run hlds_linux
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

INSTALL_TYPE=0
INSTALL_TYPE=$(($INSTALL_TYPE|$METAMOD))
INSTALL_TYPE=$(($INSTALL_TYPE|$DPROTO))
INSTALL_TYPE=$(($INSTALL_TYPE|$AMXMODX))
INSTALL_TYPE=$(($INSTALL_TYPE|$CHANGES))
INSTALL_TYPE=$(($INSTALL_TYPE|$REGAMEDLL))

echo "-------------------------------------------------------------------------------"
echo                  "Downloading HLDS base files..."
echo "-------------------------------------------------------------------------------"

speed=$(check_speed)

if (( $(echo "$speed < 10" | bc -l) )); then
    download_files_arch
else
    download_files_steamcmd
fi

if [ ! -d "$INSTALL_DIR/cstrike" ] || [ ! -f "$INSTALL_DIR/hlds_run" ] || [ ! -e "$INSTALL_DIR/cstrike/liblist.gam" ]; then
    echo "Error: Failed to download server files."
    exit 1
fi

cd $INSTALL_DIR

echo "-------------------------------------------------------------------------------"
echo         "Installing ReHLDS + Metamod-r + Reunion + AMXX + ReGameDLL..."
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

    # configs override
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

if [ $(($INSTALL_TYPE&$CHANGES)) != 0 ]; then
    echo "Creating server.cfg stub (insert your config here)..."

    cat > $INSTALL_DIR/cstrike/server.cfg << 'EOF'
ц// ============================================
// ОСНОВНЫЕ НАСТРОЙКИ
// ============================================
hostname "server cs 1.6"
rcon_password ""
sv_password ""
sv_lan 0
sv_contact ""
sv_downloadurl "http://<ip>:6789"
sv_allowdownload 1
sv_allowupload 1
sv_send_logos 1
sv_send_resources 1

// ============================================
// СЕТЬ И ПРОИЗВОДИТЕЛЬНОСТЬ
// ============================================
// Rate настройки для разных каналов
// sv_maxrate 0                          // 0 = автоопределение (рекомендуется)
// или вручную:
// sv_maxrate 25000                      // 256 Kbit
// sv_maxrate 50000                      // 512 Kbit
// sv_maxrate 100000                     // 1 Mbit
sv_maxrate 250000                        // 2.5 Mbit+
sv_minrate 5000
sv_maxupdaterate 101
sv_minupdaterate 30
sys_ticrate 1000
fps_max 600
sv_unlag 1                               // Предсказание движения (1 = вкл)
sv_maxunlag 0.5                          // Макс. коррекция в секундах
sv_unlagpush 0

// ============================================
// ГЕЙМПЛЕЙ - ОБЩИЕ
// ============================================
mp_timelimit 30
mp_freezetime 3
mp_roundtime 3
mp_buytime 0.5                           // 0.5 = 30 секунд
mp_c4timer 35
mp_forcechasecam 0
mp_forcecamera 0                         // 0=свободная, 1=только команда, 2=первое лицо команды
mp_fadetoblack 0                         // 0=нет затемнения, 1=после смерти
mp_chattime 10                           // Время показа сообщений убийств
mp_playerid 0                            // 0=все имена, 1=только команда, 2=никаких
mp_footsteps 1
mp_flashlight 1
mp_autokick 0
mp_autoteambalance 0
mp_limitteams 0
mp_tkpunish 0
mp_hostagepenalty 0
mp_refill_bpammo_weapons 1               // 1=пополнение патронов при подборе оружия

// ============================================
// ДЕНЬГИ И ЭКОНОМИКА
// ============================================
mp_startmoney 5000
mp_maxmoney 16000
mp_buytime 0.5
mp_afterroundmoney 0                     // Деньги после раунда (0=стандарт)
mp_roundrespawn_time 0                   // Задержка респауна в секундах (0=выкл)

// Настройки потерь/наград
mp_damage_head 4.0                       // Мультипликатор урона в голову
mp_damage_chest 1.0                      // Мультипликатор урона в грудь
mp_damage_stomach 1.25                   // Мультипликатор урона в живот
mp_damage_arm 1.0                        // Мультипликатор урона в руку
mp_damage_leg 0.75                       // Мультипликатор урона в ногу

// Награды за убийства
mp_kill_reward 650                       // Награда за убийство
mp_headshot_reward 500                   // Доп. награда за хедшот
mp_knife_reward 1500                     // Награда за убийство ножом
mp_grenade_reward 650                    // Награда за убийство гранатой
mp_assist_reward 300                     // Награда за помощь
mp_victory_reward 3000                   // Награда за победу в раунде
mp_defusal_reward 300                    // Награда за разминирование
mp_rescued_hostage_reward 1000           // Награда за спасение заложника

// ============================================
// ФИЗИКА И ДВИЖЕНИЕ
// ============================================
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
sv_bounce 1                              // Отскок гранат (1=реалистичный)
sv_rollangle 0
sv_rollspeed 200
sv_visiblemaxplayers 32

// ============================================
// ОРУЖИЕ И ПРЕДМЕТЫ
// ============================================
mp_nadedrops 1                           // Выпадение гранат после смерти
mp_weaponstay 1                          // 0=оружие исчезает, 1=остается
mp_weapon_respawn 0                      // Респаун оружия (0=никогда, 1=всегда)
mp_itemstay 0
mp_decals 300                            // Макс. количество декалей (следы пуль)
mp_decal_lifetime 30                     // Время жизни декалей в секундах
mp_corpsestay 0                          // Трупы до конца раунда (стандарт)

// Специфичные настройки оружия
mp_awp_oneshot_kill 1                    // 1=AWP убивает с одного попадания
mp_deagle_oneshot_kill 1                 // 1=Deagle убивает с одного попадания в голову
mp_glockburst 0                          // 0=одиночные, 1=очередью для Glock18
mp_famasburst 0                          // 0=одиночные, 1=очередью для FAMAS

// ============================================
// ГОЛОСОВОЙ ЧАТ И КОММУНИКАЦИЯ
// ============================================
sv_voiceenable 1
sv_alltalk 0                             // 0=командный чат, 1=общий, 2=спец.режим
sv_voicecodec vaudio_speex               // Кодек голосового чата
sv_voicequality 5                        // Качество голоса (1-5)
mp_chattime 10
sv_hlvoice 0                             // 0=Valve Voice, 1=Half-Life Voice
sv_ignoregrenaderadio 1                  // Игнорировать радио-сообщения о гранатах

// ============================================
// ЛОГИРОВАНИЕ И АДМИНИСТРИРОВАНИЕ
// ============================================
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1
sv_log_onefile 0
sv_logblocks 0                           // Блокировка спама в логах
mp_logdetail 3                           // Детализация логов (0-3)
mp_logmessages 1                         // Логировать чат

// Анти-флуд
sv_timeout 65                            // Таймаут подключения
sv_maxping 0                             // Макс. пинг (0=отключено)
sv_minping 0                             // Мин. пинг
sv_maxcmdrate 101                        // Макс. cmdrate
sv_mincmdrate 30                         // Мин. cmdrate

// ============================================
// ВАЛИДАЦИЯ И БЕЗОПАСНОСТЬ
// ============================================
sv_cheats 0
sv_consistency 1
sv_pure 1                                // 1=строгая проверка файлов
sv_pure_kick_clients 0                   // 1=кикать несоответствующих клиентов
sv_sendinterval 0.05                     // Интервал отправки данных
sv_filetransfercompression 1             // Сжатие передаваемых файлов
sv_allow_upload 1                        // Разрешить загрузку спреев
sv_allow_download_ent 1                  // Разрешить загрузку .ent файлов

// ============================================
// СПЕЦИАЛЬНЫЕ РЕЖИМЫ И ФУНКЦИИ
// ============================================
// Zombie Plague (если используется)
// zp_delay 5
// zp_gamemode 1

// Deathrun
// dr_activer 1

// Surf/Bhop
// sv_cheats 1 (требуется для некоторых surf серверов)
// sv_gravity 0 (для surf)
// sv_airaccelerate 150 (для bhop/surf)

// GunGame
// gg_enabled 1
// gg_tr_winner_pts 2

// ============================================
// РЕГИОНАЛЬНЫЕ НАСТРОЙКИ
// ============================================
sv_region 255                            // 255=весь мир
// 0 - US East coast
// 1 - US West coast
// 2 - South America
// 3 - Europe
// 4 - Asia
// 5 - Australia
// 6 - Middle East
// 7 - Africa
// 255 - Global

// ============================================
// ФАЙЛЫ И КОНФИГУРАЦИИ
// ============================================
mapcyclefile "mapcycle.txt"
motdfile "motd.txt"
motd_write_once 1                        // Показывать MOTD только один раз за сессию
motd_color "255 255 255"                 // Цвет текста MOTD
motd_bgcolor "0 0 0"                     // Цвет фона MOTD
stats_logging 1                          // Логирование статистики
banid_file "banned.cfg"
listip_file "listip.cfg"
writeid                                  // Сохранить banid
writeip                                  // Сохранить listip

// ============================================
// ЗАПУСК И ИНИЦИАЛИЗАЦИЯ
// ============================================
exec banned.cfg
exec listip.cfg
exec yapb.cfg
exec amxx.cfg                             // Если используется AMX Mod X
// exec mani_server.cfg                   // Если используется Mani Admin Plugin
// exec sourcemod.cfg                     // Если используется SourceMod

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

EXTERNAL_IP=$(curl -s https://api.ipify.org || wget -qO- https://api.ipify.org)

if [ -z "$EXTERNAL_IP" ]; then
    echo "ERROR: Unable to detect external IP."
    exit 1
fi

echo "External IP detected: $EXTERNAL_IP"
echo "Updating sv_downloadurl in /root/cstrike/server.cfg..."

sed -i "s|http://<ip>:6789|http://${EXTERNAL_IP}:6789|g" /root/cstrike/server.cfg

echo "sv_downloadurl updated!"

echo "-------------------------------------------------------------------------------"
echo "Server installed in directory: '$INSTALL_DIR'"
echo "[INFO] Installed versions:"
echo "  ReHLDS:     ${rehlds_url}"
echo "  Metamod-r:  ${metamodr_url}"
echo "  Reunion:    ${reunion_version}"
echo "  AMXX:       ${amxx_version} build ${amxx_build}"
echo "  ReGameDLL:  ${regamedll_url}"
echo "-------------------------------------------------------------------------------"
echo "Scripts:"
echo "  ./start       – start server"
echo "  ./stop        – stop server"
echo "  ./restart     – restart server"
echo "  ./console     – console server"
echo "-------------------------------------------------------------------------------"

exit 0
