#!/bin/bash

###############################################################################
# 
#  This is a simple VPS setup for icecast audio streaming server.
#     should/could work on debian 6 and ubuntu 10.04 to 12.04 
#
###############################################################################


###############################################################################
# Parameters - please set accordingly to desired values 
###############################################################################

ICECAST_PORT=8999
ICECAST_SOURCE_PASSWORD=Ice123456
ICECAST_RELAY_PASSWORD=Ice123456
ICECAST_ADMIN_PASSWORD=Ice123456

ICES2_USER=radio
ICES2_USER_PWD=radio

MOUNT_NAME=radio.ogg

###############################################################################
# Common functions
###############################################################################
function check_install {
    if [ -z "`which "$1" 2>/dev/null`" ]
    then
        executable=$1
        shift
        while [ -n "$1" ]
        do
            DEBIAN_FRONTEND=noninteractive apt-get -q -y install "$1"
            print_info "$1 installed for $executable"
            shift
        done
    else
        print_warn "$2 already installed"
    fi
}

function check_remove {
    if [ -n "`which "$1" 2>/dev/null`" ]
    then
        DEBIAN_FRONTEND=noninteractive apt-get -q -y remove --purge "$2"
        print_info "$2 removed"
    else
        print_warn "$2 is not installed"
    fi
}

function die {
    echo "ERROR: $1" > /dev/null 1>&2
    exit 1
}

function check_sanity {
    echo "Check Sanity"
    if [ $(/usr/bin/id -u) != "0" ]
    then
        die 'Must be run by root user'
    fi
    
    if [ ! -f /etc/debian_version ]
    then
        die "Distribution is not supported"
    fi
    
    chmod 700 /root
    
    echo "passed."
}

###############################################################################
# SETUP
###############################################################################

########################################
# SETUP CLEAN SYSTEM SECTION 
########################################


########################################################################
# MAIN PROGRAM
########################################################################

export PATH=/bin:/usr/bin:/sbin:/usr/sbin
#checking
clear
check_sanity

function boo {

echo "Installing icecast"
check_install icecast2 icecast2

echo "Configure icecast"
sed -i "/<port>/c<port>$ICECAST_PORT</port>" /etc/icecast2/icecast.xml
sed -i "/<source-password>/c<source-password>$ICECAST_SOURCE_PASSWORD</source-password>" /etc/icecast2/icecast.xml
sed -i "/<relay-password>/c<relay-password>$ICECAST_RELAY_PASSWORD</relay-password>" /etc/icecast2/icecast.xml
sed -i "/<admin-password>/c<admin-password>$ICECAST_ADMIN_PASSWORD</admin-password>" /etc/icecast2/icecast.xml
sed -i "/ENABLE=false/cENABLE=true" /etc/default/icecast2

echo "Installing ices2"
check_install ices2 ices2

echo "Creating ices2 user"
useradd $ICES2_USER -d /home/$ICES2_USER -m -p $ICES2_USER_PWD
/usr/sbin/usermod -p $ICES2_USER_PWD $ICES2_USER
mkdir /home/$ICES2_USER/logs
mkdir /home/$ICES2_USER/music
echo "download sample music"
wget http://upload.wikimedia.org/wikipedia/en/0/04/Rayman_2_music_sample.ogg -O /home/$ICES2_USER/music/sample.ogg 
chown $ICES2_USER:$ICES2_USER -R /home/$ICES2_USER/logs 
chown $ICES2_USER:$ICES2_USER -R /home/$ICES2_USER/music

echo "Setup of ices2 config files"
    cat > /home/$ICES2_USER/playlist.xml <<END
<?xml version="1.0"?>
<ices>
    <background>1</background>
    <logpath>/home/$ICES2_USER/logs</logpath>
    <logfile>ices.log</logfile>
    <loglevel>4</loglevel>
    <consolelog>0</consolelog>
    <stream>
        <metadata>
            <name>My Radio</name>
            <genre>My Genre</genre>
            <description>Listen</description>
        </metadata>
        <input>
            <module>playlist</module>
            <param name="type">basic</param>
            <param name="file">/home/$ICES2_USER/playlist.txt</param>
            <param name="random">0</param>
            <param name="restart-after-reread">1</param>
            <param name="once">0</param>
        </input>
        <instance>
            <hostname>localhost</hostname>
            <port>$ICECAST_PORT</port>
            <password>$ICECAST_SOURCE_PASSWORD</password>
            <mount>/$MOUNT_NAME</mount>
            <reconnectdelay>2</reconnectdelay>
            <reconnectattempts>5</reconnectattempts>
            <maxqueuelength>80</maxqueuelength>
            <encode>
                <nominal-bitrate>64000</nominal-bitrate>
                <samplerate>44100</samplerate>
                <channels>2</channels>
            </encode>
        </instance>
        </stream>
</ices>
END
chown $ICES2_USER:$ICES2_USER /home/$ICES2_USER/playlist.xml

    cat > /home/$ICES2_USER/playlist.txt <<END
/home/$ICES2_USER/music/sample.ogg
END
chown $ICES2_USER:$ICES2_USER /home/$ICES2_USER/playlist.txt

}


echo "Done"
