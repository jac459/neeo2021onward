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
#  8; Adding users (mosquitto, changing profile for neeo-user to chmod /steady/neeo-custom/.pm2/pub.sock & /steady/neeo-custom/.pm2/rpc.sock to 777
#  9; Setting up autopstart via PM2
#  9; Signalling we have run seuccesfully  


# First, define some variables used in here
Statedir="/steady/.installer"
Statefile="$Statedir/state"
FoundStage=0
VersionFile="$Statedir/version"
LatestVersion=1.1
InstalledVersion=1.0  # assume that the first installer ran before.
Upgrade_requested=0
UpgradeMetaOnly_requested="0"
GoOn=1                # the main loop controller
RetryCountPacman=10   # becasue of the instability of some archlinux repositories, url-error 502 might occur

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

# Following are the various stages that can be executed
Exec_mount_root_stage=0
Exec_setup_steady_stage=1
Exec_reset_pacman=2
Exec_install_nvm=3
Exec_finish_nvm=4
Exec_install_git=5
Exec_install_meta=6
Exec_install_mosquitto=7
Exec_install_nodered=8
Exec_backup_solution=9 
Exec_setup_pm2=X 
Exec_all_stages=0
Exec_finish=Y 
Exec_finish_done=Z

# then define all functions that we are going to use.

ctrlc_count=0

function no_ctrlc()
{
    let ctrlc_count++
    echo
    if [[ $ctrlc_count == 1 ]]; then
        echo "cntrl-C hit, please confirm with another cntrl-c."
    elif [[ $ctrlc_count == 2 ]]; then
        echo "That's it.  I quit."
        exit
    fi
}

function usage() {
  cat << EOL
Installer for NEEO-Brain v$MyVersion 
Usage: $0 [options]

Options: 
  --help            display this help and exits
  --reset           Start installer from scratch)
  --meta-only       Only pull a new version of metadriver, and restart it
  --upgrade         Upgrade environment to add/improve functionality
  --get-versions    Output current version of meta and the last available one
EOL
}

function Do_Reset()
{
echo "Clearing statemachine, restarting from begin... you may get errors about packages already being installed..."
if [ -e "$Statedir" ]
    then 
    sudo rm -r "$Statedir" 
    fi 

}

function Do_ReadState()
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
  if [ "$LastLine" != "" ] 
     then
     StageID=$(echo "$LastLine" | cut -c1-6) 
     if [ "$StageID" = "Stage " ]
         then 
         FoundStage=$(echo "$LastLine" | cut -c7-8) 
     else
         echo "Found $StageID but that doesn't match 'Stage '; so $FoundStage isn't valid either"
         GoOn=0
     fi
  else
     FoundStage=0 			  # file with state found, but with no content; assume it's not there and start at stage 0
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

function Do_SetNextStage()
{
   if [ "$1" = "" ]
      then 
      echo "error in setting nextstage; input for nextstage is empty"
      exit 12
   fi
    FoundStage="$1"
    echo "Stage $1" >> "$Statefile"
    echo "$FoundStage"
}

Do_Version_Check()
{
#Special_1
   pushd .

   cd /steady/neeo-custom/ 
   if [[ ! -f  "steady/neeo-custom.meta"  ]]
       then 
       echo "Error: Metadriver is not yet installed"
       return 
   fi
   cd /steady/neeo-custom/.meta/node_modules/@jac459/metadriver
   MyVersion=$(npm  list @jac459/metadriver  --no-fund|cut -d '@' -f 2)
   echo "$MyVersion"


}
function Do_Mount_root()
{
#0
   echo "Stage 0: Setup a rewritable root-partition (includes entry in /etc/fstab)"

   if [ "$Upgrade_requested" == 1   ]
      then 
      echo "skip this step"
      Do_SetNextStage $Exec_setup_steady_stage
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
         GoOn=0
         return  
      fi
   fi
   MyFstab=$(grep 'dev/mmcblk0p2  /       ext2    ro         ' /etc/fstab)
   if [ "$MyFstab" ]                                                        # Do we still have the root as ro-only in fstab?  
      then
      sudo sed -i 's_dev/mmcblk0p2  /       ext2    ro         _dev/mmcblk0p2  /       ext2    rw,noatime_' /etc/fstab
       if [ "$?" -ne 0 ]
         then
           echo "Coud not update fstab" >&2
           GoOn=0
           return
        fi
       echo "/etc/fstab is now patched, continuing"
    else
       echo "/etc/fstab was already patched, so it seems, continuing"
    fi
    Do_SetNextStage $Exec_setup_steady_stage
} 

function Do_Setup_steady_directory_struct()
{
#1  
   echo "Stage $Exec_setup_steady_stage: Setting up directories and rights"

   if [ "$Upgrade_requested" == 1   ] 
      then 
      Do_SetNextStage $Exec_reset_pacman  
      return      #nothing to do
   fi

   sudo mkdir /steady/neeo-custom
   sudo chown neeo:wheel /steady/neeo-custom
   sudo chmod -R 775 /steady/neeo-custom
   Do_SetNextStage $Exec_reset_pacman

}

function Do_Reset_Pacman()
{
#2
   echo "Stage $Exec_reset_pacman: Restoring pacman to a workable state"

   if [ "$Upgrade_requested" == "1"  ] 
      then 
       Do_SetNextStage $Exec_install_nvm
      return      #nothing to do
   fi
   ln -s /etc/ca-certificates/extracted/ca-bundle.trust.crt /etc/ssl/certs/ca-certificates.crt
   curl -k 'https://raw.githubusercontent.com/jac459/neeo2021onward/main/Meta%20running%20in%20Brain/safepackages.tgz' -o ~/safepackages.tgz 
   pushd . 
   mkdir ~/safepackages
   cd ~/safepackages
   tar -xvf ~/safepackages.tgz
   cd var/cache/pacman/pkg
   sudo pacman -U * --noconfirm --force 
#   MyPacmanVersion=$(pacman --version|grep 'Pacman v')
#   if [[ "$MyPacmanVersion" == *"v5.2.2"* ]]
#      then
#      echo "Pacman is already up-to-date"
#   else
##      MyRetries=$RetryCountPacman
 #     NoSuccessYet=1
 #     while  [  $NoSuccessYet -ne 0 ] ; do
 #        sudo pacman -Syu --noconfirm
 #        if [ "$?" -ne 0 ]
 #            then
 #            if [[ $MyRetries -gt 1 ]]
 #               then 
 #               echo 'Error occured during pacman restore (pacman -Sy --noconfirm) - retrying'
 #            else 
 ##              echo 'Error occured during pacman restore (pacman -Sy --noconfirm); giving up'
##             GoOn=0
 #             return
#             fi          
#         else
#          NoSuccessYet=0       # signal done, break the loop
#         fi
#         ((MyRetries=MyRetries-1))
#      done 

 #     MyRetries=$RetryCountPacman
 #     NoSuccessYet=1
 #     while  [  $NoSuccessYet -ne 0 ] ; do
 #        sudo pacman -S --force --noconfirm pacman
 #        if [ "$?" -ne 0 ]
 #            then
 #            if [[ $MyRetries -gt 1 ]]
 #               then 
 #               echo 'Error occured during pacman restore (pacman -S --force --noconfirm pacman) - retrying'
 #            else 
 #              echo 'Error occured during pacman restore (pacman -S --force --noconfirm pacman); giving up'
 #              GoOn=0
 #              return
 #            fi          
 #        else
 #         NoSuccessYet=0       # signal done, break the loop
 #        fi
 #        ((MyRetries=MyRetries-1))
 #     done 

#   fi   
popd
   Do_SetNextStage $Exec_install_nvm


}

function Do_Install_NVM()
{
#3
    echo "Stage $Exec_install_nvm: installing NVM, then secondary npm&node"
       
   if [ "$Upgrade_requested" == 1  ]
      then
       Do_SetNextStage $Exec_finish_nvm
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
    . ~/.bashrc   
    nvm install --lts=erbium
    if [ "$?" -ne 0 ]
       then
        echo 'Error installing npm&node (nvm install --lts=erbium)'

        echo 'This error happens sometimes and is easy to fix'
        echo 'Please execute the following command, then run installmeta again: . ~/.bashrc (yes: dot blank dot!)'
        sleep 10s
        GoOn=0
        return
    fi
    MyBashrc=$(cat ~/.bashrc |grep 'export PM2_HOME=/steady/neeo-custom/.pm2')   # add some usefull commands to .bashrc to make life easier
    if [ "$?" -ne 0 ]
       then
        echo 'export PM2_HOME=/steady/neeo-custom/.pm2' >> ~/.bashrc
    fi
    Do_SetNextStage $Exec_finish_nvm

}

function Do_Finish_NVM()
{
#4
   echo "Stage $Exec_finish_nvm: Finishing setup npm&node"
       
   if [ "$Upgrade_requested" == 1 ]
      then
      Do_SetNextStage $Exec_install_git
      return      #nothing to do
   fi
   MyNPM=$(npm -v)
   if [[ "$MyNPM" == "6.14.9" ]]
      then
      echo "NPM 6.14.9 was already installed, skipping" 
   else
      pushd . 
      cd /steady/neeo-custom/
      npm install npm -g  --no-fund
      if [ "$?" -ne 0 ]
         then
          echo 'Error installing npm (npm install npm -g)'
          GoOn=0
          popd 
          return
      fi 
   fi
       popd 
    Do_SetNextStage $Exec_install_git

}

function Do_Install_Git()
{
#5
   echo "Stage $Exec_install_git: installing GIT"
       
#   if [ "$Upgrade_requested" == 1 ]
#      then
#      Do_SetNextStage $Exec_install_meta
##      return      #nothing to do
#   fi
#  MyGit=$(command -v git)
#  if [[ "$MyGit" == "" ]]
##      then 
#      MyRetries=$RetryCountPacman
#      NoSuccessYet=1
#      while  [  $NoSuccessYet -eq 1 ] ; do
#         sudo pacman -S --overwrite  '/*' --noconfirm  git
##         if [ "$?" -ne 0 ]
 ##            then
 #            if [[ $MyRetries -gt 1 ]]
 #               then 
 #               echo 'Error occured during Install of Git - retrying'
 #            else 
 #              echo ' Error occured during Install of Git - giving up'
 #              GoOn=0
 #              return
 #            fi          
 #        else
 #         NoSuccessYet=0       # signal done, break the loop
 ##        fi
 #        ((MyRetries=MyRetries-1))
 #     done
 #  else
 #     echo "Git is already installed"   
 #  fi
    Do_SetNextStage $Exec_install_meta

}

function Do_Install_Meta()
{
#6
   echo "Stage $Exec_install_meta: installing Metadriver (JAC459/metadriver)"
       
   #if [ "$Upgrade_requested" == 1 ]
   #   then
   #   return                                                           # in tis case, upgrade will be requiresd
   #fi
   pushd .

   cd /steady/neeo-custom/ 
   if [[ ! -f  ".meta"  ]]
       then 
#      echo "/steady/neeo-custom/.meta already exist"
#   else
      mkdir .meta
   fi
   cd .meta 
   npm install jac459/metadriver  --no-fund
   if [ "$?" -ne 0 ]
       then
        echo 'Install of metadriver failed'
        GoOn=0
        popd 
        return
    fi
   popd 
   if [  "$UpgradeMetaOnly_requested" == "1" ]
       then
       Do_SetNextStage $Exec_setup_pm2
   else
       Do_SetNextStage $Exec_install_mosquitto
        no need for install of pacman-packages, done witht tar
   fi
}

function Do_Install_Mosquitto()
{
#7
   echo "Stage $Exec_install_mosquitto: installing Mosquitto"
       
   if [ "$Upgrade_requested" == 1 ]
      then
      Do_SetNextStage $Exec_install_nodered
      return      #nothing to do
   fi
 # MyMosquitto=$(command -v mosquitto)
 #  if [[ "$MyMosquitto" == "" ]]
 #     then 
      sudo useradd -u 1002 mosquitto
#      MyRetries=$RetryCountPacman
#      NoSuccessYet=1
#      while  [  $NoSuccessYet -ne 0 ] ; do
#         sudo pacman -S  --noconfirm --overwrite  /usr/lib/libnsl.so,/usr/lib/libnsl.so.2,/usr/lib/pkgconfig/libnsl.pc  mosquitto
#         if [ "$?" -ne 0 ]
#             then
#             if [[ $MyRetries -gt 1 ]]
#                then 
##                echo 'Error occured during Install of Mosquitto - retrying'
 #            else 
 #              echo ' Error occured during Install of Mosquitto - giving up'
 #              GoOn=0
 #              return
 #            fi          
 #        else
 #         NoSuccessYet=0       # signal done, break the loop
 #        fi
 #        ((MyRetries=MyRetries-1))
 #     done
 #  fi 
 
    Do_SetNextStage $Exec_install_nodered 
}

function Do_Install_NodeRed()
{   
#8
   echo "Stage $Exec_install_nodered: installing Node-Red"
       
   if [ "$Upgrade_requested" == 1 ]
      then
      Do_SetNextStage $Exec_backup_solution
      return      #nothing to do
   fi


   #sudo npm install -g --unsafe-perm node-red # since 2020-12-05, global install produces the following error :
#        > publish-please@5.5.2 preinstall /home/neeo/.nvm/versions/node/v12.20.0/lib/node_modules/node-red/node_modules/publish-please
#     > node lib/pre-install.js
#
#
#     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#     !! Starting from v2.0.0 publish-please can't be installed globally.          !!
#     !! Use local installation instead : 'npm install --save-dev publish-please', !!
#     !! Or use npx if you do not want to install publish-please as a dependency.  !!
#     !! (learn more: https://github.com/inikulin/publish-please#readme).          !!
#     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#     npm WARN optional SKIPPING OPTIONAL DEPENDENCY: fsevents@^2.1.2 (node_modules/node-red/node_modules/jest-haste-map/node_modules/fsevents):
#     npm WARN notsup SKIPPING OPTIONAL DEPENDENCY: Unsupported platform for fsevents@2.2.1: wanted {"os":"darwin","arch":"any"} (current: {"os":"linux","arch":"arm"})
#
#     npm ERR! code ELIFECYCLE
#     npm ERR! errno 1
#     npm ERR! publish-please@5.5.2 preinstall: `node lib/pre-install.js`
#     npm ERR! Exit status 1
 
   if [[ ! -e /steady/neeo-custom/.node-red/node_modules/node-red/red.js ]]
      then 
      pushd .
      mkdir /steady/neeo-custom/.node-red
      cd /steady/neeo-custom/.node-red
      npm install --unsafe-perm node-red  --no-fund
      if [ "$?" -ne 0 ]
          then
         echo 'Install of NodeRed failed'
         GoOn=0
         popd
         return
      fi
      cd /steady/neeo-custom/.node-red/node_modules/node-red
      ln -s red.js node-red.js
      popd
   fi 
   Do_SetNextStage $Exec_setup_pm2    #$Exec_backup_solution 
}

function Do_Backup_solution()
{
#A
   echo "Stage $Exec_backup_solution: Setting up backup"

   if [ "$Upgrade_requested" == "1" && "$InstalledVersion" > "$Function_A_Introduced" ]
      then
      Do_SetNextStage $Exec_setup_pm2
      return      #nothing to do
   fi

  MyRSync=$(command -v rsync)
   if [[ "$MyRSync" == "" ]]
      then 
      MyRetries=$RetryCountPacman
      NoSuccessYet=1
      while  [  $NoSuccessYet -ne 0 ] ; do
         sudo pacman -S --overwrite  '/*' --noconfirm  rsync
         if [ "$?" -ne 0 ]
             then
             if [[ $MyRetries -gt 1 ]]
                then 
                echo 'Error occured during Install of rsync - retrying'
             else 
               echo ' Error occured during Install of rsync - giving up'
               GoOn=0
               return
             fi          
         else
          NoSuccessYet=0       # signal done, break the loop
         fi
         ((MyRetries=MyRetries-1))
      done 
   fi 
   Do_SetNextStage $Exec_setup_pm2

}

function Do_Setup_PM2()
{
#X
   echo "Stage $Exec_setup_pm2: Activating services in PM2"
       
   if [  "$UpgradeMetaOnly_requested" == "1" ]
      then 
         PM2_HOME='/steady/neeo-custom/.pm2' pm2 restart meta
         Do_SetNextStage $Exec_finish
         return
   fi 
   pushd .
   cd /steady/neeo-custom
   if [[ ! -e ".pm2" ]]
       then
      mkdir .pm2
   fi

   MyBashrc=$(cat ~/.bashrc |grep '/steady/neeo-custom/.pm2')   # add some usefull commands to .bashrc to make life easier
   if [ "$?" -ne 0 ]
       then
        echo 'sudo chmod 777 /steady/neeo-custom/.pm2/pub.sock' >> ~/.bashrc
        echo 'sudo chmod 777 /steady/neeo-custom/.pm2/rpc.sock'>> ~/.bashrc
   fi 
   sudo PM2_HOME='/steady/neeo-custom/.pm2' pm2 startup
   sleep 5s


   . ~/.bashrc
   sudo chown neeo /steady/neeo-custom/.pm2/rpc.sock /steady/neeo-custom/.pm2/pub.sock

   MyPM2=$(PM2_HOME='/steady/neeo-custom/.pm2' pm2 list)
   if [[ $(echo "$MyPM2" | grep -i 'mosquitto') == "" ]]
       then
       PM2_HOME='/steady/neeo-custom/.pm2' pm2 start mosquitto
   else
       PM2_HOME='/steady/neeo-custom/.pm2' pm2 restart mosquitto
   fi   
   if [[ "$?" != 0 ]]
      then 
      echo "Error adding mosquitto-start to PM2"
   fi 

   if [[ $(echo "$MyPM2" | grep -i 'node-red') == "" ]];
      then 
      cd /steady/neeo-custom/.node-red/node_modules/node-red
      PM2_HOME='/steady/neeo-custom/.pm2' pm2 start node-red.js -f  --node-args='--max-old-space-size=128'
   else 
      PM2_HOME='/steady/neeo-custom/.pm2' pm2 restart node-red
   fi
   if [[ "$?" != 0 ]]
      then 
      echo "Error adding node-red-start to PM2"
   fi 


   if [[ $(echo "$MyPM2" | grep -i 'meta') == "" ]];
      then    
      cd /steady/neeo-custom/.meta/node_modules/\@jac459/metadriver
      PM2_HOME='/steady/neeo-custom/.pm2' pm2 start meta.js
   else 
      PM2_HOME='/steady/neeo-custom/.pm2' pm2 restart meta
   fi 
   if [[ "$?" != 0 ]]
      then 
      echo "Error adding meta-start to PM2"
   fi

   popd

   sudo PM2_HOME='/steady/neeo-custom/.pm2' pm2 save
   Do_SetNextStage $Exec_finish
}

function Do_Upgrade()
{
   if [[ ("$InstalledVersion"  = "1.0") && ("$FoundStage"="A") ]]        # fix the "old v1.0 Finish-action", so that is compatible with newer versions
      then
      FoundStage="Z"
   fi

  
   if [ "$FoundStage" != "Z" ]  # Yes, but did we already have a completely installed system?
      then
      echo "Please let installer run first to a succesful end before upgrading: $FoundStage"
      Upgrade_requested=0       # reset update-request to no
   else
      if [  "$UpgradeMetaOnly_requested" == "1" ]
            then 
            echo "We will be upgrading metadriver only; then we will restart metadriver"
            Do_SetNextStage "$Exec_install_meta"
            Upgrade_requested=1       # reset update-request to no
      else
         if [ !  "$LatestVersion" \> "$InstalledVersion"  ]  # is the installed version lower than the latest availalbe version (My Version)?
            then
            echo "No need to upgrade, you are already on the latest version ($LatestVersion)"
            Upgrade_requested=0       # reset update-request to no
         else         
           echo "We will be upgrading this installation from v$InstalledVersion into v$LatestVersion"
           Do_SetNextStage "$Exec_all_stages"
         fi
      fi
   fi


}    

function Do_Finish()
{
echo "$LatestVersion:"+$(date +"%Y-%m-%d %T") >>$VersionFile
echo "We are done installng, your installation is now at level v$LatestVersion"

}

##Main routine

# first setup a cntrol-C handler
trap no_ctrlc SIGINT

if [ $# -gt 0 ]; then
  # Parsing any parameters passed to us
  while (( "$#" )); do
    case "$1" in
      --help)
        usage && return
        shift
        ;;
      --reset)
        Do_Reset
        shift
        ;;
      --meta-only)
        Upgrade_requested=1
        UpgradeMetaOnly_requested="1"
        shift
        ;; 
      --upgrade)
        Upgrade_requested=1
        shift
        ;;   
     --get-versions)   
        Determine_versions=1
        shift
        ;;
      -*|--*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        return
        ;;
      *)
        echo "Please use correct format for arguments $1 not recognised" >&2
        usage &&return
        ;; 
    esac
  done
fi

GoOn=1
Do_ReadState                   # check to see if we ran before; if so, get the state of the previous runs and the version of installer thatran
echo $InstalledVersion

echo "We are running in stage $FoundStage of 9"

# Special functions go first. 

# This one just determines the current version of meta and the latest available one
if [ "$Determine_versions" == 1 ]
   then
      Do_Version_Check                              # Check if upgrade is possible/allowed
      return
   fi 


# Do we need to run a special check first, before entering the state-machine?
if [ "$Upgrade_requested" == 1 ]
   then
      Do_Upgrade                                    # Check if upgrade is possible/allowed
      if [ "$Upgrade_requested" != 1 ]              # Did Do_Upgrade function made a decision overriding update-request?
         then
         echo "Upgrade was rejected"
         return
      fi
   fi 



# We come here if we want the stste machine to run. 
# This may be for an entire run, a restarted run, or selected entries-only

while (( "$GoOn"==1 )); do
#    echo " case with $FoundStage"
    case $FoundStage in
       $Exec_mount_root_stage)
          Do_Mount_root
       ;;
       $Exec_setup_steady_stage)
          Do_Setup_steady_directory_struct
       ;;
       $Exec_reset_pacman)
          Do_Reset_Pacman
       ;;
       $Exec_install_nvm)
         Do_Install_NVM
       ;;
       $Exec_finish_nvm)
         Do_Finish_NVM
       ;;
       $Exec_install_git)
          Do_Install_Git 
       ;;
       $Exec_install_meta)
          Do_Install_Meta 
       ;;
       $Exec_install_mosquitto)
          Do_Install_Mosquitto
       ;;
       $Exec_install_nodered)
          Do_Install_NodeRed
       ;;
       $Exec_setup_pm2)
          Do_Setup_PM2
       ;;
       $Exec_backup_solution)
          Do_Backup_solution
       ;;
       $Exec_finish)                                          # this is just a placeholder
          Do_SetNextStage $Exec_finish_done    # If we've come here, FoundStage can be set to the max position: Z
       ;;  
       $Exec_finish_done)
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


