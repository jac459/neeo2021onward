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


# First, define some variables used in here
Statedir="/steady/.installer"
Statefile="$Statedir/state"
VersionFile="$Statedir/version"
LatestVersion=1.1
InstalledVersion=1.0  # assume that the first installer ran before.

#Following table maintains the version where a new or changed functionality was introduced; used to check if we need to execute an upgrade for a function  
Function_0_Introduced=1.0
Function_1_Introduced=1.0
Function_2_Introduced=1.0
Function_3_Introduced=1.0
Function_4_Introduced=1.0
Function_5_Introduced=1.0
Function_6_Introduced=1.0
Function_7_Introduced=1.0
Function_8_Introduced=1.0
Function_9_Introduced=1.0
Function_A_Introduced=1.1

# then define all functions that we are going to use.
usage() {
  cat << EOL
Installer for NEEO-Brain v$MyVersion 
Usage: $0 [options]

Options: 
  --help            display this help and exits
  --reset           Start installer from scratch)
  --upgrade         Upgrade environment to add/improve functionality
EOL
}

Do_Reset()
{
echo "Clearing statemachine, restarting from begin... you may get errors about packages already being installed..."
if [ -e "$Statedir" ]
    then 
    sudo rm -r "$Statedir" 
    fi 

}
Do_ReadState()
{
  if [ -e "$Statedir"  ];                   # do we have the state-directory in /steady?
      then 
      if [ ! -e "$Statefile"  ]  # yes, do we alsoi have the state file in there?
         then                                # no
         echo "Stage 0" > "$Statefile"       # create an empty stage-file
      fi 
      sudo chown neeo:wheel "$Statedir"      # make sure normal user can access the directory
  else
      sudo mkdir "$Statedir"                 # No state-0directory found, make it so we can save our state
      sudo chown neeo:wheel "$Statedir"      # make sure normal user can access the directory
      echo "Stage 0" > "$Statefile"          # and create an empty file 
      #FoundStage="0"  no longer needed                        # tell the installer we start from scratch
  fi
  LastLine=$(tail -n 1 "$Statefile")
  StageID=$(echo "$LastLine" | cut -c1-6) 
  if [ "$StageID" = "Stage " ]
      then 
      FoundStage=$(echo "$LastLine" | cut -c7-8) 
  else
      echo "Found $StageID but that doesn't match 'Stage '; so $FoundStage isn't valid either"
      GoOn=0
  fi

  if [ -e "$VersionFile" ]                 # Now find out which version of the installer ran (will be in /steady/.install/version unless user removed it / never ran it
      then                                 # file is available,m look at last succesful installation to obtain that version 
      LastLine=$(tail -n 1 "$VersionFile")
      if [ ! "$LastLine" = "" ] 
         then
	      InstalledVersion=`echo $LastLine | cut -d ":" -f 1`    # format of line is 1.0:+2020-12-05 16:27:09
      fi
  fi
}

Do_Mount_root()
{
#0
   echo "Stage 0: Setup a rewritable root-partition (includes entry in /etc/fstab)"

   if [ "$Upgrade_requested"  ]
      then 
      return      #nothing to do
   fi  

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
   echo "Stage 1: Setting up directories and rights"

   if [ "$Upgrade_requested"  ] 
      then 
      return      #nothing to do
   fi

   sudo mkdir /steady/neeo-custom
   sudo chown neeo:wheel /steady/neeo-custom
   sudo chmod -R 775 /steady/neeo-custom
   echo "Stage 2" >> "$Statefile"
}

Do_Reset_Pacman()
{
#2
   echo "Stage 2: Restoring pacman to a workable state"

   if [ "$Upgrade_requested"  ] 
      then 
      return      #nothing to do
   fi

   MyPacmanVersion=$(pacman --version|grep 'Pacman v')
   if [ "$MyPacmanVersion" = ".--. Pacman v5.2.2 - libalpm v12.0.2" ]
      then
      echo "Pacman is already up-to-date"
   else
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
   fi   
   echo "Stage 3" >> "$Statefile"
}

Do_Install_NVM()
{
#3
    echo "Stage 3: installing NVM, then secondary npm&node"

       
       
   if [ "$Upgrade_requested"  ]
      then
      return      #nothing to do
   fi

    if [ -e ~/.nvm ]
       then 
      echo "NVM already installed"
    else   
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    fi 
    sudo chmod -R ugo+rx /home/neeo/.nvm 
    MyBashrc=$(cat ~/.bashrc |grep 'export NVM_DIR="$HOME/.nvm')
    if [ "$?" -ne 0 ]
       then
        echo 'export NVM_DIR="$HOME/.nvm" ' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm'>> ~/.bashrc
    fi
    . .bashrc   
    nvm install --lts=erbium
    if [ "$?" -ne 0 ]
       then
        echo 'Error installing npm&node (nvm install --lts=erbium)'

        echo 'This error happens sometimes and is easy to fix'
        echo 'Please execute the following command, then run installmeta again: . .bashrc (yes: dot blank dot!)'
        sleep 10s
        exit 12
    fi
    MyBashrc=$(cat ~/.bashrc |grep 'export PM2_HOME=/steady/neeo-custom/pm2-meta')   # add some usefull commands to .bashrc to make life easier
    if [ "$?" -ne 0 ]
       then
        echo 'export PM2_HOME=/steady/neeo-custom/pm2-meta' >> ~/.bashrc
    fi
    cd /steady/neeo-custom
    echo "Stage 4" >> "$Statefile"

}

Do_Finish_NVM()
{
#4
   echo "Stage 4: Finishing setup npm&node"

       
   if [ "$Upgrade_requested"  ]
      then
      return      #nothing to do
   fi

   cd /steady/neeo-custom/
   npm install npm -g
   if [ "$?" -ne 0 ]
      then
       echo 'Error installing npm (npm install npm -g)'
       exit 12
   fi
       cd ~
    echo "Stage 5" >> "$Statefile"
}

Do_Install_Git()
{
#5
   echo "Stage 5: installing GIT"
       
   if [ "$Upgrade_requested"  ]
      then
      return      #nothing to do
   fi

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
   echo "Stage 6: installing Metadriver (JAC459/metadriver)"
       
   #if [ "$Upgrade_requested"  ]
   #   then
   #   return                                                           # in tis case, upgrade will be requiresd
   #fi

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
   echo "Stage 7: installing Mosquitto"
       
   if [ "$Upgrade_requested"  ]
      then
      return      #nothing to do
   fi

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
   echo "Stage 8: installing Node-Red"
       
   if [ "$Upgrade_requested"  ]
      then
      return      #nothing to do
   fi

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
#9
   echo "Stage 9: Activating services in PM2"
       
   if [ "$Upgrade_requested"  ]
      then
      return      #nothing to do
   fi

   MyBashrc=$(cat ~/.bashrc |grep '/steady/neeo-custom/pm2-meta')   # add some usefull commands to .bashrc to make life easier
   if [ "$?" -ne 0 ]
       then
        echo 'sudo chmod 777 /steady/neeo-custom/pm2-meta/pub.sock' >> ~/.bashrc
        echo 'sudo chmod 777 /steady/neeo-custom/pm2-meta/rpc.sock'>> ~/.bashrc
   fi 
   . ~/.bashrc
   sudo PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 startup
   sudo chown neeo /steady/neeo-custom/pm2-meta/rpc.sock /steady/neeo-custom/pm2-meta/pub.sock

   PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 start mosquitto
   PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 start node-red -f  --node-args='--max-old-space-size=128'
   PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 start /steady/neeo-custom/node_modules/\@jac459/metadriver/meta.js
   sudo PM2_HOME='/steady/neeo-custom/pm2-meta' pm2 save
    echo "Stage A" >> "$Statefile"
}

Do_Add_Backup_solution()
{
#A
   echo "Stage A: Setting up backup"

   if [ "$Upgrade_requested"  && "$InstalledVersion" \> "$Function_A_Introduced" ]
      then
      return      #nothing to do
   fi

   sudo pacman -S --overwrite  '/*' --noconfirm  rsync
   if [ "$?" -ne 0 ]
       then
        echo 'Install of rsync failed'
        exit 12
    fi
    echo "Stage B" >> "$Statefile"

}

Do_Upgrade()
{
   if [[ ("$InstalledVersion"  = "1.0") && ("$Foundstage"="A") ]]        # fix the "old v1.0 Finish-action", so that is compatible with newer versions
      then
      FoundStage="Z"
   fi
  
   if [ "$FoundStage" != "Z" ]  # Yes, but did we already have a completely installed system?
      then
      echo "Please let installer run first to a succesful end before upgrading: $FoundStage"
      Upgrade_requested=0       # reset update-request to no
   else
     if [ !  "$LatestVersion" \> "$InstalledVersion"  ]  # is the installed version lower than the latest availalbe version (My Version)?
        then
         echo "No need to upgrade, you are already on the latest version ($LatestVersion)"
         Upgrade_requested=0       # reset update-request to no
     else
         echo "We will be upgrading this installation from v$InstalledVersion into v$LatestVersion"
         FoundStage=0
     fi
   fi


}    

Do_Finish()
{
echo "$LatestVersion:"+$(date +"%Y-%m-%d %T") >>$VersionFile
echo "We are done installng, your installation is now at level v$LatestVersion\n"

}

##Main routine



if [ $# -gt 0 ]; then
  # Parsing any parameters passed to us
  while (( "$#" )); do
    case "$1" in
      --help)
        usage && exit 0
        shift
        ;;
      --reset)
        Do_Reset
        shift
        ;;
      --upgrade)
        Upgrade_requested=1
        shift
        ;;   
      -*|--*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 1
        ;;
      *)
        echo "Please use correct format for arguments $1 not recognised" >&2
        usage &&exit 1
        ;; 
    esac
  done
fi

GoOn=1
Do_ReadState                   # check to see if we ran before; if so, get the state of the previous runs and the version of installer thatran
echo $InstalledVersion

echo "We are running in stage $FoundStage of 9"

if [ "$Upgrade_requested"=1 ]
   then
      Do_Upgrade                                    # Check if upgrade is possible/allowed
      if [ "$Upgrade_requested" != 1 ]              # Did Do_Upgrade function made a decision overriding update-request?
         then
         return
      fi
   fi 

#    case $FoundStage in

GoOn=1
while (( "$GoOn"==1 )); do
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
          FoundStage=A
       ;;
       A)
          Do_Add_Backup_solution
          FoundStage=B
       ;;
       B)
          FoundStage=Z
          echo "Stage Z" >> "$Statefile"           # If we've come here, FoundStage can be set to the max position: Z
       ;;  
       Z)
          Do_Finish
          GoOn=0
       ;;       
       *)
          echo -n "Package already ran till end"
          GoOn=0
       ;;
    esac

echo ""  
done


