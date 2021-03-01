#!/bin/sh

# POTLUCK TEMPLATE v2.0
# EDIT THE FOLLOWING FOR NEW FLAVOUR:
# 1. RUNS_IN_NOMAD - yes or no
# 2. Create a matching <flavour> file with this <flavour>.sh file that
#    contains the copy-in commands for the config files from <flavour>.d/
#    Remember that the package directories don't exist yet, so likely copy to /root
# 3. Adjust package installation between BEGIN & END PACKAGE SETUP
# 4. Adjust jail configuration script generation between BEGIN & END COOK
#    Configure the config files that have been copied in where necessary

# Set this to true if this jail flavour is to be created as a nomad (i.e. blocking) jail.
# You can then query it in the cook script generation below and the script is installed
# appropriately at the end of this script 
RUNS_IN_NOMAD=true

# -------------- BEGIN PACKAGE SETUP -------------
[ -w /etc/pkg/FreeBSD.conf ] && sed -i '' 's/quarterly/latest/' /etc/pkg/FreeBSD.conf
ASSUME_ALWAYS_YES=yes pkg bootstrap

# test exit code for error, exit with error code if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could bootstrap pkg"
    exit "$flavour_error"
else
    continue
fi

# create the /ec/rc.conf file
touch /etc/rc.conf

flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not create /etc/rc.conf"
    exit "$flavour_error"
else
    continue
fi

# disable sendmail
sysrc sendmail_enable="NO"

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not disable sendmail"
    exit "$flavour_error"
else
    continue
fi

# Install base packages: sudo
pkg install -y sudo

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not install sudo"
    exit "$flavour_error"
else
    continue
fi

# Install base packages: bash
pkg install -y bash

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not install bash"
    exit "$flavour_error"
else
    continue
fi

# Install nginx, this should also create /usr/local/etc/rc.d directory

# setup /etc/rc.conf
sysrc nginx_enable="YES"

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not enable nginx in sysrc."
    exit "$flavour_error"
else
    continue
fi

# install nginx
pkg install -y nginx

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not install nginx."
    exit "$flavour_error"
else
    continue
fi

# Clean up pkg installs
pkg clean -y

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not cleanup packages."
    exit "$flavour_error"
else
    continue
fi

# -------------- END PACKAGE SETUP -------------

#
# Create configurations
#

# set the cook log path/filename
COOKLOG=/var/log/cook.log

# check if cooklog exists, touch it if not
if [ ! -e $COOKLOG ];
then
    echo "creating $COOKLOG"
    touch $COOKLOG
else
    echo "WARNING $COOKLOG already exists"  
fi

# >>>> TARBALL >>>>
# check for myfile.tar, extract it if exists
if [ -f /root/myfile.tar ];
then
    echo "/root/myfile.tar exists, changing owner to root:wheel" >> $COOKLOG
    echo "/root/myfile.tar exists, changing owner to root:wheel"
    chown root:wheel /root/myfile.tar
else
    echo "ERROR /root/myfile.tar does not exist. Cannot change ownership" >> $COOKLOG
    echo "ERROR /root/myfile.tar does not exist. Cannot change ownership"
fi

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "error changing owner of myfile.tar."
    exit "$flavour_error"
else
    continue
fi

if [ -r /root/myfile.tar ];
then
    echo "extracting tarball to /root." >> $COOKLOG
    echo "extracting tarball to /root."
    /usr/bin/tar -xf /root/myfile.tar -C /root/
else
    echo "ERROR /root/myfile.tar cannot be read" >> $COOKLOG
    echo "ERROR /root/myfile.tar cannot be read"
fi


# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "myfile.tar cannot be read"
    exit "$flavour_error"
else
    continue
fi

# change ownership of the extracted file. This is required, else failure.
# and make it executable
if [ -e /root/myfile.sh ];
then
    echo "setting owner for myfile.sh." >> $COOKLOG
    echo "setting owner for myfile.sh."
    chown root:wheel /root/myfile.sh
    echo "making myfile.sh executable" >> $COOKLOG
    echo "making myfile.sh executable"
    chmod +x /root/myfile.sh
else
    echo "ERROR There is a problem changing owner or setting executable bit on myfile.sh" >> $COOKLOG
    echo "ERROR There is a problem changing owner or setting executable bit on myfile.sh" && exit 1
fi

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "There is a problem changing owner or setting executable bit on myfile.sh."
    exit "$flavour_error"
else
    continue
fi

# Arguments to pass to script (demo case)
# setting to empty will trigger a failure in the build
ARG1=1000
ARG2=2000
ARG3=3000

# run script with args
if [ -x /root/myfile.sh ];
then
    echo "Running file with arguments $ARG1 $ARG2 $ARG3." >> $COOKLOG
    echo "Running file with arguments $ARG1 $ARG2 $ARG3."
    /root/myfile.sh "$ARG1" "$ARG2" "$ARG3"
else
   echo "ERROR could not run myfile.sh with args $ARG1 $ARG2 $ARG3" >> $COOKLOG
   echo "ERROR could not run myfile.sh with args $ARG1 $ARG2 $ARG3"
fi

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not run myfile.sh with args"
    exit "$flavour_error"
else
    continue
fi

# <<<< TARBALL <<<<

#
# Now generate the run command script "cook"
# It configures the system on the first run by creating the config file(s) 
# On subsequent runs, it only starts sleeps (if nomad-jail) or simply exits 
#

# clear any old cook runtime file
if [ -f /usr/local/bin/cook ];
then
    echo "an existing /usr/local/bin/cook exists. deleting" >> $COOKLOG
    echo "an existing /usr/local/bin/cook exists. deleting"
    rm /usr/local/bin/cook
else
    echo "WARNING no /usr/local/bin/cook file, creating." >> $COOKLOG
    echo "WARNING no /usr/local/bin/cook file, creating."
fi

# this runs when image boots
# ----------------- BEGIN COOK ------------------ 

echo "#!/bin/sh
RUNS_IN_NOMAD=$RUNS_IN_NOMAD
# declare this again for the pot image, might work carrying variable through like
# with above
COOKLOG=/var/log/cook.log
# No need to change this, just ensures configuration is done only once
if [ -e /usr/local/etc/pot-is-seasoned ]
then
    # If this pot flavour is blocking (i.e. it should not return), 
    # we block indefinitely
    if [ \$RUNS_IN_NOMAD ]
    then
        /bin/sh /etc/rc
        tail -f /dev/null 
    fi
    exit 0
fi

# ADJUST THIS: STOP SERVICES AS NEEDED BEFORE CONFIGURATION
# /usr/local/etc/rc.d/example stop

# No need to adjust this:
# If this pot flavour is not blocking, we need to read the environment first from /tmp/environment.sh
# where pot is storing it in this case
if [ -e /tmp/environment.sh ]
then
    . /tmp/environment.sh
fi

#
# ADJUST THIS BY CHECKING FOR ALL VARIABLES YOUR FLAVOUR NEEDS:
#
# Convert parameters to variables if passed (overwrite environment)
while getopts h:n: option
do
    case \"\${option}\"
    in
      h) HOSTNAME=\${OPTARG};;
      n) MYNETWORKS=\${OPTARG};;
    esac
done

# Check config variables are set
if [ -z \${MYNETWORKS+x} ]; 
then 
    echo 'MYNETWORKS is unset - setting it to 192.168.0.0/16,10.0.0.0/8' >> /var/log/cook.log
    echo 'MYNETWORKS is unset - setting it to 192.168.0.0/16,10.0.0.0/8'
    MYNETWORKS=\"192.168.0.0/16,10.0.0.0/8\" 
fi
if [ -z \${HOSTNAME+x} ];
then
    echo 'HOSTNAME is unset - setting it to \"demo\"' >> /var/log/cook.log
    echo 'HOSTNAME is unset - setting it to \"demo\"'
    HOSTNAME=\"demo\" 
fi

# ADJUST THIS BELOW: NOW ALL THE CONFIGURATION FILES NEED TO BE ADJUSTED & COPIED:
echo \"# This is the demo config file containing two demo variables\" >> /root/my.cnf
echo \$MYNETWORKS >> /root/my.cnf
echo \$HOSTNAME >> /root/my.cnf

#
# ADJUST THIS: START THE SERVICES AGAIN AFTER CONFIGURATION
#
# /usr/local/etc/rc.d/example start

#
# Do not touch this:
touch /usr/local/etc/pot-is-seasoned

# If this pot flavour is blocking (i.e. it should not return), there is no /tmp/environment.sh
# created by pot and we now after configuration block indefinitely
if [ \$RUNS_IN_NOMAD ]
then
    /bin/sh /etc/rc
    tail -f /dev/null
fi
" > /usr/local/bin/cook

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "could not create /usr/local/bin/cook"
    exit "$flavour_error"
else
    continue
fi

# ----------------- END COOK ------------------


# ---------- NO NEED TO EDIT BELOW ------------

if [ -e /usr/local/bin/cook ];
then
    echo "setting executable bit on /usr/local/bin/cook" >> $COOKLOG
    echo "setting executable bit on /usr/local/bin/cook"
    chmod u+x /usr/local/bin/cook
else
    echo "ERROR there is no /usr/local/bin/cook to make executable" >> $COOKLOG
    echo "ERROR there is no /usr/local/bin/cook to make executable" 
fi

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "there is no /usr/local/bin/cook to make executable"
    exit "$flavour_error"
else
    continue
fi

#
# There are two ways of running a pot jail: "Normal", non-blocking mode and
# "Nomad", i.e. blocking mode (the pot start command does not return until
# the jail is stopped).
# For the normal mode, we create a /usr/local/etc/rc.d script that starts
# the "cook" script generated above each time, for the "Nomad" mode, the cook
# script is started by pot (configuration through flavour file), therefore
# we do not need to do anything here.
# 

# Create rc.d script for "normal" mode:
echo "creating rc.d script to start cook" >> $COOKLOG
echo "creating rc.d script to start cook"

echo "#!/bin/sh
#
# PROVIDE: cook 
# REQUIRE: LOGIN
# KEYWORD: shutdown
#
. /etc/rc.subr
name=\"cook\"
rcvar=\"cook_enable\"
load_rc_config \$name
: ${cook_enable:=\"NO\"}
: ${cook_env:=\"\"}
command=\"/usr/local/bin/cook\"
command_args=\"\"
run_rc_command \"\$1\"
" > /usr/local/etc/rc.d/cook

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "there is a problem creating /usr/local/etc/rc.d/cook."
    exit "$flavour_error"
else
    continue
fi

if [ -e /usr/local/etc/rc.d/cook ];
then
    echo "Setting executable bit on cook rc file" >> $COOKLOG
    echo "Setting executable bit on cook rc file"
    chmod u+x /usr/local/etc/rc.d/cook && exit 0
else
    echo "ERROR /usr/local/etc/rc.d/cook does not exist" >> $COOKLOG
    echo "ERROR /usr/local/etc/rc.d/cook does not exist" && exit 1
fi

# test the exit code for error, exit with error code 1 if so
flavour_error=$?
if [ "$flavour_error" -ne 0 ]; then
    echo "/usr/local/etc/rc.d/cook does not exist"
    exit "$flavour_error"
else
    continue
fi

if [ $RUNS_IN_NOMAD = false ];
then
    # This is a non-nomad (non-blocking) jail, so we need to make sure the script
    # gets started when the jail is started:
    # Otherwise, /usr/local/bin/cook will be set as start script by the pot flavour
    echo "enabling cook in /etc/rc.conf" >> $COOKLOG
    echo "enabling cook in /etc/rc.conf"
    echo "cook_enable=\"YES\"" >> /etc/rc.conf
fi

exit 0
