#!/bin/bash

###############################################################################
# 
#  This is a simple VPS setup for icecast audio streaming server.
#     should/could work on debian 6 and ubuntu 10.04 to 12.04 
#
#  This will install icecast server where you listeners will connect to
#  This will also install ices2, where it repeteadly loops a list of ogg music 
#    files which are fed to your icecast2 server.
#  
#  If you did not change anything in the config below, you can go to this
#     url to listen: http://your_ip_add:8999/radio.ogg
#
#  To manage the files, upload to /home/radio/music and edit the file
#     /home/radio/playlist.txt
#
###############################################################################


###############################################################################
# Parameters - please set accordingly to desired values 
###############################################################################

# Port where Icecast will listen
ICECAST_PORT=8999

# Mount Name
MOUNT_NAME=radio.ogg

# Stream Name
STREAM_NAME=My Radio

# Stream Genre
STREAM_GENRE=Pop

# Stream Description
STREAM_DESC=Listen Now

# Icecast Source password
ICECAST_SOURCE_PASSWORD=Ice123456

# Icecast Relay password
ICECAST_RELAY_PASSWORD=Ice123456

# Icecast Admin password
ICECAST_ADMIN_PASSWORD=Ice123456

# Ices2 unix user to put config, logs, and music files into
ICES2_USER=radio

# Ices2 unix user password
ICES2_USER_PWD=radio

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
wget http://upload.wikimedia.org/wikipedia/en/0/04/Rayman_2_music_sample.ogg -O /home/$ICES2_USER/music/sample1.ogg 
wget http://upload.wikimedia.org/wikipedia/en/0/06/Elliott_Smith_-_Son_of_Sam_%28sample%29.ogg -O /home/$ICES2_USER/music/sample2.ogg
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
            <name>$STREAM_NAME</name>
            <genre>$STREAM_GENRE</genre>
            <description>$STREAM_DESC</description>
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
/home/$ICES2_USER/music/sample1.ogg
/home/$ICES2_USER/music/sample2.ogg
END
chown $ICES2_USER:$ICES2_USER /home/$ICES2_USER/playlist.txt



echo "create ices2 daemon for autostart"
    cat >  /etc/init.d/ices2 <<END
#!/bin/bash
# /etc/init.d/ices2

start() {
        echo "Starting ices2: "
        su - $ICES2_USER -c "ices2 /home/$ICES2_USER/playlist.xml"
        echo "done."
}
stop() {
        echo "Shutting down ices2: "
        kill -9 \`pidof ices2\`
        echo "done."
}
 
case "\$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  restart)
        stop
        sleep 30
        start
        ;;
  *)
        echo "Usage: \$0 {start|stop|restart}"
esac
exit 0
END

echo "Initialize ices2 daemon"
sudo chmod 755 /etc/init.d/ices2
sudo update-rc.d ices2 defaults

echo "Start daemons"
service icecast2 start
service ices2 start


echo "Done"
