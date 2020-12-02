#!/bin/bash
#
# Meta Installer for NEEO-Brain
#
# This script runs as a kind of state-machine with the follwoing states:
#  1; Initial   - This is the initial invocation of the script
#     Should only be run on freshly installed neeo Brain-systems. This means a new Brain, or one that has been reset to factory settings 
#     This phase HAS to run once!
#     This phase is finished with a reboot while setting the phase, followed by a reboot. 
#  2; Started, valid input argument received, mounted root-fs rw and now restoring pacman
#  3; Started,pacman done; now installing nvm 
#  4; Rebooting 
#  5; Directly after the reboot, installer restarted
#  6; Setting up user-envir for PM2, installing npm and meta
#  7; Installing mosquitto and nodered
#  8; Adding users (mosquitto, changing profile for neeo-user to chmod /steady/neeo-custom/pm2-meta/pub.sock & /steady/neeo-custom/pm2-meta/rpc.sock to 777
#  9; Setting up autopstart via PM2
#  9; Signalling we have run seuccesfully  
usage() {
  cat << EOL
Usage: $0 [options]

Options:
  --help            display this help and exits
  --1               Start installer phase 1 (before reboot)
  --2               Start installer phase 2 (final, after the reboot)
EOL
}

Do_ReadState()
{
  LastLine=$(tail -n 1 "$Statefile")
  StageID=$(echo "$LastLine" | cut -c1-6) 
  echo "$StageID"
  if [[ "$StageID" = "Stage " ]]
      then 
      FoundStage=$(echo "$LastLine" | cut -c7-8) 
  else
      echo "Found $StageID but that doesn't match 'Stage '; so $FoundStage isn;t valid either"
      exit 12   
  fi
}

Do_Mount_root()
{
#0
   echo "Step #0: Mounting root rw"
   MyMounts=$(mount|grep 'dev/mmcblk0p2 ')
   if [ $(echo "$MyMounts" | grep '(ro') ]
      then 
      echo "/ is still ro"
      sudo mount -o remount,rw /
      if [ "$?" -ne 0 ]
         then
         echo "The script failed" >&2
         exit 1  
      fi
   fi
   MyFstab=$(grep 'dev/mmcblk0p2  /       ext2    ro         ' /etc/fstab)
   if [ "$MyFstab" ]                                                        # Do we still have the root as ro-only in fstab?  
      then
      sudo sed -i 's_dev/mmcblk0p2  /       ext2    ro         _dev/mmcblk0p2  /       ext2    rw,noatime_' /etc/fstab
       if [ "$?" -ne 0 ]
         then
           echo "Coud not update fstab" >&2
          exit 1   
        fi
       echo "/etc/fstab is now patched, continuing"
    else
       echo "/etc/fstab was already patched, so it seems, continuing"
    fi
    echo "Stage 1" >> "$Statefile"
} 

Do_Setup_steady_directory_struct()
{
#1  
   sudo mkdir /steady/neeo-custom
   sudo chown neeo:wheel /steady/neeo-custom
   sudo chmod -R 775 /steady/neeo-custom
   echo "Stage 2" >> "$Statefile"
}

Do_Reset_Pacman()
{
#2
   sudo pacman -Sy --noconfirm
   if [ "$?" -ne 0 ]
       then
        echo 'error occured during pacman restore (pacman -Sy --noconfirm)'
        exit 12
   fi
   sudo pacman -S --force --noconfirm pacman
   if [ "$?" -ne 0 ]
       then
        echo 'error occured during pacman restore (pacman -S --force --noconfirm pacman)'
        exit 12
   fi   
    echo "Stage 3" >> "$Statefile"
}

Do_Install_NVM()
{
#3
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    sudo chmod -R ugo+rx /home/neeo/.nvm 
    MyBashrc=$(cat ~/.bashrc |grep 'export NVM_DIR="$HOME/.nvm')
    if [ "$?" -ne 0 ]
       then
        echo 'export NVM_DIR="$HOME/.nvm" ' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm'>> ~/.bashrc
        .bashrc
    fi
#    /home/neeo/.nvm/nvm.sh  --install --lts=erbium   #somehow, this doesn't work when called from a shell script. 
#    if [ "$?" -ne 0 ]
#       then
#        echo 'Error installing npm (nvm install --lts=erbium)'
#        exit 12
#    fi
    MyBashrc=$(cat ~/.bashrc |grep 'export PM2_HOME=/steady/neeo-custom/pm2-meta')   # add some usefull commands to .bashrc to make life easier
    if [ "$?" -ne 0 ]
       then
        echo 'export PM2_HOME=/steady/neeo-custom/pm2-meta' >> ~/.bashrc
    fi
    cd /steady/neeo-custom
    echo "Stage 4" >> "$Statefile"
    echo "Please execute the following commands: (then start installmeta.sh again)"
    echo ". ~/.bashrc"
    echo "nvm install --lts=erbium"
    echo "cd ~" 
    echo "then run installer again: . installmeta.sh"
    GoOn="0"
    return 
#    sleep 10s
#    sudo reboot now

    if [ "$?" -ne 0 ]
       then
        echo 'Error requesting a reboot, please check and reboot manually (then restart installer again)'
        exit 12 
    fi
}

Do_Finish_NVM()
{
#4
   cd /steady/neeo-custom/
   npm install npm -g
   if [ "$?" -ne 0 ]
      then
       echo 'Error installing npm (npm install npm -g)'
       exit 12
   fi
    echo "Stage 5" >> "$Statefile"
}
Do_Install_Git()
{
#5
   sudo pacman -S --overwrite  '/*' --noconfirm  git
   if [ "$?" -ne 0 ]
       then
        echo 'Install of Git failed'
        exit 12
    fi   
    echo "Stage 6" >> "$Statefile"
}

Do_Install_Meta()
{
#6

   cd /steady
   if [[ -e "pm2-meta" ]]
       then 
      echo "/steady/pm2-meta already exist"
   else

      sudo mkdir pm2-meta
   fi
   cd /steady/neeo-custom/ 
   npm install npm -g 
   if [ "$?" -ne 0 ]
       then
        echo 'Install of global npm failed'
        exit 12
    fi

   npm install jac459/metadriver
   if [ "$?" -ne 0 ]
       then
        echo 'Install of metadriver failed'
        exit 12
    fi
    echo "Stage 7" >> "$Statefile"
}

Do_Install_Mosquitto()
{
#7
   sudo useradd -u 1002 mosquitto
   sudo pacman -S  --noconfirm --overwrite  /usr/lib/libnsl.so,/usr/lib/libnsl.so.2,/usr/lib/pkgconfig/libnsl.pc  mosquitto
   if [ "$?" -ne 0 ]
       then
        echo 'Install of Mosquitto failed'
        exit 12
    fi   
    echo "Stage 8" >> "$Statefile"
}

Do_Install_NodeRed()
{
#8
   sudo npm install -g --unsafe-perm node-red
   if [ "$?" -ne 0 ]
       then
        echo 'Install of NodeRed failed'
        exit 12
    fi
    echo "Stage 9" >> "$Statefile"
}


Do_Setup_PM2()
{
   MyBashrc=$(cat ~/.bashrc |grep '/steady/neeo-custom/pm2-meta')   # add some usefull commands to .bashrc to make life easier
   if [ "$?" -ne 0 ]
       then
        echo 'sudo chmod 777 /steady/neeo-custom/pm2-meta/pub.sock' >> ~/.bashrc
        echo 'sudo chmod 777 /steady/neeo-custom/pm2-meta/rpc.sock'>> ~/.bashrc
   fi 
   sudo PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 startup
   sudo chown neeo /steady/neeo-custom/pm2-meta/rpc.sock /steady/neeo-custom/pm2-meta/pub.sock

   PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 start mosquitto
   PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 start node-red -f  --node-args='--max-old-space-size=128'
   PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 start /steady/neeo-custom/node_modules/\@jac459/metadriver/meta.js
   sudo PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 save
    echo "Stage A" >> "$Statefile"
}

    
Do_Finish()
{
echo "We are done installng"
}

##Main routine

STAGE="0"        # Assume that we we will start from scratch 
if [ $# -gt 0 ]; then
  # Parsing any parameters passed to us
  while (( "$#" )); do
    case "$1" in
      --help)
        usage && exit 0
        shift
        ;;
      --1)
        STAGE=="1"
        shift
        ;;
      --2)
        STAGE="2"
        shift
        ;;
      -*|--*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 1
        ;;
    esac
  done
fi

Statedir="/steady/.installer"
Statefile="/steady/.installer/state"
#empty stage-file
if [[ -e "$Statedir" ]];
    then 
    if [[ -e "$Statefile" ]];
       then  Do_ReadState
    else
       echo "Stage 0" > "$Statefile"       
    fi 
    sudo chown neeo:wheel "$Statedir"
else
    sudo mkdir "$Statedir"
    sudo chown neeo:wheel "$Statedir"
    echo "Stage 0" > "$Statefile"
    FoundStage="0"
fi
echo "We are in stage $FoundStage"

#    case $FoundStage in

GoOn="1"
while (( "$GoOn"=="1" )); do
    echo "$FoundStage"
    case $FoundStage in
       0)
          Do_Mount_root
          FoundStage=1
       ;;
       1)
          Do_Setup_steady_directory_struct
          FoundStage=2
       ;;
       2)
          Do_Reset_Pacman
          FoundStage=3
       ;;
       3)
         Do_Install_NVM
         FoundStage=4 
       ;;
       4)
         Do_Finish_NVM
         FoundStage=5
       ;;
       5)
          Do_Install_Git 
          FoundStage=6
       ;;
       6)
          Do_Install_Meta 
          FoundStage=7
       ;;
       7)
          Do_Install_Mosquitto
          FoundStage=8
       ;;
       8)
          Do_Install_NodeRed
          FoundStage=9
       ;;
       9)
          Do_Setup_PM2
          GoOn=0
       ;;
       *)
          echo -n "Package already ran till end"
          GoOn=0
       ;;
    esac

echo ""  
done


