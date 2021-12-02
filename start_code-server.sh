#!/usr/bin/env bash

# A script to start code-server on the ETH Euler cluster and interacting with it through a web browser
# Joao Sousa, December 2021 @ETH Zurich
# Adapted from Samuel Fux (https://gitlab.ethz.ch/sfux/Jupyter-on-Euler-or-Leonhard-Open)


# CONFIGURATION OPTIONS
##########################################################

# SSH key location is the path to your SSH key. Please specify the path if you are using a non-standard name for your SSH key
SSH_KEY_LOCATION=$EULER_SSH_KEY

# Waiting time interval after starting code-server. Check every $WAITING_TIME_INTERVAL seconds if the job already started
WAITING_TIME_INTERVAL=10


# HELP MESSAGE
##########################################################

# function to print usage instructions
function print_usage {
        echo -e "Usage:\tstart_code-server.sh NETHZ_USERNAME NUM_CORES MEM_PER_CORE RUN_TIME\n"
        echo -e "Arguments:\n"
        echo -e "NETHZ_USERNAME\t\tNETHZ username for which code-server should be started"
        echo -e "NUM_CORES\t\tNumber of cores to be used on the cluster (<32)"
	      echo -e "MEM_PER_CORE\t\tMemory limit in MB per core\n"
        echo -e "RUN_TIME\t\tRun time limit for code-server on the cluster (HH:MM)"
        echo -e "Example:\n"
        echo -e "./start_code-server.sh josousa 4 04:00 2048\n"
}

# if number of command line arguments is different from 4 or if $1==-h or $1==--help
if [ "$#" !=  4 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    print_usage
    exit
fi



# GENERAL VARIABLES
##########################################################

# save working directory as a variable to save reconnect_info
WORKINGDIR=$PWD

# check if SSH_KEY_LOCATION is empty or contains a valid path
if [ -z "$SSH_KEY_LOCATION" ]; then
    SSH_KEY_OPTION=""
else
    SSH_KEY_OPTION="-i $SSH_KEY_LOCATION"
fi



# COMMAND LINE ARGUMENTS
##########################################################

# Parse and check command line arguments (NETHZ username, number of cores, memory limit per NUM_CORES, run time limit)

# set Euler cluster as host and load the modules
CHOSTNAME="euler.ethz.ch"
PCOMMAND="gcc/6.3.0 code-server/3.12.0 eth_proxy r/4.0.2 python/3.8.5 julia tmux radian"

# no need to do checks on the username. If it is wrong, the SSH commands will not work
USERNAME="$1"
echo -e "NETHZ username: $USERNAME"

# number of cores to be used
NUM_CORES=$2

# check if NUM_CORES is an integer
if ! [[ "$NUM_CORES" =~ ^[0-9]+$ ]]; then
    echo -e "Incorrect format. Please specify number of cores as an integer and try again.\n"
    print_usage
    exit
fi

# check if NUM_CORES is <= 32
if [ "$NUM_CORES" -gt "32" ]; then
    echo -e "No distributed memory supported, therefore number of cores needs to be smaller or equal to 32.\n"
    print_usage
    exit
fi
echo -e "code-server will run on $NUM_CORES cores"

# memory per core
MEM_PER_CORE=$3

# check if MEM_PER_CORE is an integer
if ! [[ "$MEM_PER_CORE" =~ ^[0-9]+$ ]]
    then
        echo -e "Memory limit must be an integer, please try again.\n"
        print_usage
        exit
fi
echo -e "Memory per core set to $MEM_PER_CORE MB\n"

# run time limit
RUN_TIME="$4"

# check if RUN_TIME is provided in HH:MM format
if ! [[ "$RUN_TIME" =~ ^[0-9][0-9]:[0-9][0-9]$ ]]; then
    echo -e "Incorrect format. Please specify runtime limit in the format HH:MM and try again.\n"
    print_usage
    exit
else
    echo -e "Run time limit set to $RUN_TIME"
fi





# CHECK LEFT OVER FILES
##########################################################

# check if some old files are left from a previous session and delete them
echo -e "Checking for left over files from previous sessions"
if [ -f $WORKINGDIR/reconnect_info ]; then
        echo -e "Found old reconnect_info file, deleting it ..."
        rm $WORKINGDIR/reconnect_info
fi

ssh $SSH_KEY_OPTION -T $USERNAME@$CHOSTNAME <<ENDSSH
if [ -f /cluster/home/$USERNAME/codeserver_info ]; then
        echo -e "Found old codeserver_info file, deleting it ..."
        rm /cluster/home/$USERNAME/codeserver_info
fi
if [ -f /cluster/home/$USERNAME/codeserver_ip ]; then
	echo -e "Found old codeserver_ip file, deleting it ..."
        rm /cluster/home/$USERNAME/codeserver_ip
fi 
ENDSSH



# CONNECTING TO EULER AND START CODE-SERVER
##########################################################

# Run the code-server job on Euler and save ip, port and the token

# in the files codeserver_ip and codeserver_info in the home directory of the user on Euler
echo -e "Connecting to Euler to start code-server in a batch job"
ssh $SSH_KEY_OPTION $USERNAME@$CHOSTNAME bsub -n $NUM_CORES -W $RUN_TIME -R "rusage[mem=$MEM_PER_CORE]" <<ENDBSUB
if [ -f /cluster/work/nme/software/config/nme_startup.sh ]; then . /cluster/work/nme/software/config/nme_startup.sh; fi
module load $PCOMMAND
export XDG_RUNTIME_DIR=
PORT=$((3 * 2**14 + RANDOM % 2**14))
IP_REMOTE="\$(hostname -i)"
echo "Remote IP:\$IP_REMOTE" >> /cluster/home/$USERNAME/codeserver_ip
SESSION="code-server`pwd | md5 | cut -b -3`"
tmux attach-session -d -t $SESSION || tmux new-session -s $SESSION
code-server --extensions-dir=/cluster/work/nme/software/libraries/code-server/3.12.0 --verbose --proxy-domain=http://proxy.ethz.ch:3128 --bind-addr="\${IP_REMOTE}:\${PORT}" &> /cluster/home/$USERNAME/codeserver_info
ENDBSUB



# RECEIVING REMOTE IP and PORTS
##########################################################

# wait until code-server has started, poll every $WAITING_TIME_INTERVAL seconds to check if $HOME/codeserver_info exists
# once the file exists and is not empty, code-server has been startet and is listening
ssh $SSH_KEY_OPTION $USERNAME@$CHOSTNAME "while ! [ -e /cluster/home/$USERNAME/codeserver_info -a -s /cluster/home/$USERNAME/codeserver_info ]; do echo 'Waiting for code-server to start, sleep for $WAITING_TIME_INTERVAL sec'; sleep $WAITING_TIME_INTERVAL; done"

# get remote ip and port from files stored on Euler
echo -e "Receiving ip and port code-server"

remoteip=$(ssh $SSH_KEY_OPTION $USERNAME@$CHOSTNAME "cat /cluster/home/$USERNAME/codeserver_ip | grep -m1 'Remote IP' | cut -d ':' -f 2")
remoteport=$(ssh $SSH_KEY_OPTION $USERNAME@$CHOSTNAME "cat /cluster/home/$USERNAME/codeserver_info | grep -m1 'HTTP server listening on' | cut -d '/' -f 3 | cut -d ':' -f 2")

if  [[ "$remoteip" == "" ]]; then
    echo -e "Error: remote ip is not defined. Terminating script."
    echo -e "Please login to the cluster and check with bjobs if the batch job is still running."
    exit 1
fi

if  [[ "$remoteport" == "" ]]; then
    echo -e "Error: remote port is not defined. Terminating script."
    echo -e "Please login to the cluster and check with bjobs if the batch job is still running."
    exit 1
fi

echo -e "Remote IP address: $remoteip"
echo -e "Remote port: $remoteport"

# get a free port on local computer
echo -e "Determining free port on local computer"
local_port=8899
echo -e "Local port: $local_port"



# WRITE RECONNECT_INFO FILE
##########################################################

echo -e "Restart file \n" >> $WORKINGDIR/reconnect_info
echo -e "Remote IP address: $remoteip\n" >> $WORKINGDIR/reconnect_info
echo -e "Remote port: $remoteport\n" >> $WORKINGDIR/reconnect_info
echo -e "Local port: $local_port\n" >> $WORKINGDIR/reconnect_info
echo -e "SSH tunnel: ssh $USERNAME@$CHOSTNAME -L $local_port:$remoteip:$remoteport -N &\n" >> $WORKINGDIR/reconnect_info
echo -e "URL: http://localhost:$local_port\n" >> $WORKINGDIR/reconnect_info



# SSH TUNNEL FROM LOCAL COMPUTER TO COMPUTE NODE
##########################################################

# setup SSH tunnel from local computer to compute node via login node
echo -e "Setting up SSH tunnel for connecting the browser to code-server"
ssh $SSH_KEY_OPTION $USERNAME@$CHOSTNAME -L $local_port:$remoteip:$remoteport -N &

# SSH tunnel is started in the background, pause 5 seconds to make sure
# it is established before starting the browser
sleep 5

# save url in variable
codeserver_url=http://localhost:$local_port
echo -e "Starting browser and connecting it to code-server"
echo -e "Connecting to url "$codeserver_url

if [[ "$OSTYPE" == "linux-gnu" ]]; then
        xdg-open $codeserver_url
elif [[ "$OSTYPE" == "darwin"* ]]; then
        open $codeserver_url
elif [[ "$OSTYPE" == "msys" ]]; then # Git Bash on Windows 10
        start $codeserver_url
else
        echo -e "Your operating system does not allow to start the browser automatically."
        echo -e "Please open $codeserver_url in your browser."
fi
