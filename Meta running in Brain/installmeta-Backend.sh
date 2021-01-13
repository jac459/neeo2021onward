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
LatestVersion=1.6
InstalledVersion=1.0  # assume that the first installer ran before.
Upgrade_requested=0
UpgradeMetaOnly_requested="0"
GoOn=1                # the main loop controller
Determine_versions=0
RetryCountPacman=10   # becasue of the instability of some archlinux repositories, url-error 502 might occur

#Following table maintains the version where a new or changed functionality was AddedOrChanged; used to check if we need to execute an upgrade for a function  
Function_0_AddedOrChanged=1.0
Function_1_AddedOrChanged=1.0
Function_2_AddedOrChanged=1.5
Function_3_AddedOrChanged=1.0
Function_4_AddedOrChanged=1.0
Function_5_AddedOrChanged=1.0
Function_6_AddedOrChanged=1.0
Function_7_AddedOrChanged=1.0
Function_8_AddedOrChanged=1.0
Function_9_AddedOrChanged=1.0
Function_A_AddedOrChanged=1.3
Function_B_AddedOrChanged=1.3 
Function_C_AddedOrChanged=1.5
Function_X_AddedOrChanged=1.2

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
Exec_install_jq=A
Exec_install_python=B
Exec_install_broadlink=C
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
        GoOn=0
        return
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
         echo "Stage Z" > "$Statefile"       # create an empty stage-file
      fi 
      sudo chown neeo:wheel "$Statedir"      # make sure normal user can access the directory
  else
      sudo mkdir "$Statedir"                 # No state-0directory found, make it so we can save our state
      sudo chown neeo:wheel "$Statedir"      # make sure normal user can access the directory
      echo "Stage Z" > "$Statefile"          # and create an empty file 
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
      GoOn=0
      
   fi
    FoundStage="$1"
    echo "Stage $1" >> "$Statefile"
    echo "$FoundStage"
}

Do_Version_Check()
{
#Special_1

   if [[ ! -e  "/steady/neeo-custom/.meta"  ]]
       then 
       echo "Error: Metadriver is not yet installed"
       return 
   fi

   pushd . 1>/dev/null

   cd /steady/neeo-custom/.meta/node_modules/@jac459/metadriver
   MyVersion=$(cat package.json | jq ._id|xargs | cut -d @ -f3) 
   popd  >/dev/null

   MyPKG=$(curl https://raw.githubusercontent.com/jac459/metadriver/master/package.json -s)
   LastVersion=$(echo $MyPKG | jq ._id|xargs | cut -d @ -f3)

   export InfoString="Last version: $LastVersion -  Installed version: $MyVersion"
   echo $InfoString
   
   return
}
function Do_Mount_root()
{
#0
   echo "Stage 0: Setup a rewritable root-partition (includes entry in /etc/fstab)"
   NextStep=$Exec_setup_steady_stage

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
    Do_SetNextStage $NextStep
} 

function Do_Setup_steady_directory_struct()
{
#1  
   echo "Stage $Exec_setup_steady_stage: Setting up directories and rights"
   NextStep=$Exec_reset_pacman

   if [ ! -e /steady/neeo-custom ]
      then   
      sudo mkdir /steady/neeo-custom
      sudo chown neeo:wheel /steady/neeo-custom
      sudo chmod -R 775 /steady/neeo-custom
   fi

   MyBashrc=$(cat ~/.bashrc | grep -i '/steady/neeo-custom/.pm2/' ) # atill old style chmods in .bashrc?
   if [[ "$MyBashrc" != "" ]]  # yes
      then
      echo "Removing stale chmod statementas form .bashrc, saving old version as ~.bashrc.old"
      sed '/\/steady\/neeo-custom\/.pm2/d' .bashrc >~/bashrcx
      mv ~/.bashrc ~/.bashrc.old
      mv ~/bashrcx  ~/.bashrc
   fi 

   Do_SetNextStage $NextStep
}


      

function SubFunction_Update_Pacman()
{
#2a

   #Before updating, we need to download old, saved package for systemd. 
   #Because the systemd-update somehow blocks all HTTP(S)- traffic, so we do it now

   # and as we found out, the package  systemd-libs (247.2-1 causes problems with HTTP(S) not resolving anymore, so let's install an earlier version of it (downgrade it) 
   pushd .  >/dev/null
   if [[ -e ~/safepackages/systemd-libs-246.6-1.1-armv7h.pkg.tar.xz ]]
      then
      echo "Saved package already downloaded"
   else
      mkdir ~/safepackages
   	cd ~/safepackages
      curl -k 'https://raw.githubusercontent.com/jac459/neeo2021onward/main/Meta%20running%20in%20Brain/systemd-libs-246.6-1.1-armv7h.pkg.tar.xz' -o systemd-libs-246.6-1.1-armv7h.pkg.tar.xz
   fi

   sudo pacman -Su pacman --noconfirm --force     # use old style pacman command
   if [[ ! "$?" == 0 ]]
       then 
       echo "Problems updating the system, run aborted"
       exit  
   fi
   # and downgrade systemd-package 
   cd ~/safepackages
   sudo pacman -U systemd*  --noconfirm --overwrite '/*' # will give: warning: downgrading package systemd-libs (247.2-1 => 246.6-1.1)
# and as we found out, the package  systemd-libs (247.2-1 causes problems with HTTP(S) not resolving anymore, so let's install an earlier version of it (downgrade it) 

   cd ~
   rm -r ~/safepackages

   popd >/dev/null
} 

function Do_Reset_Pacman()
{
#2
   echo "Stage $Exec_reset_pacman: Restoring pacman to a workable state"
   NextStep=$Exec_install_nvm

   MyYear=$(date +'%Y')   # Test to see if we have a corruoted date (timesyncd fails)
   if [[ "$MyYear" == "2018" ]]
      then                # we have the bug
      sudo date -s '2021-01-01 00:00:00'  # set a more recent date so that we do not have issues with certificates
   fi

   echo "Filling/updating Pacman's repositories" 
   sudo pacman -Syy   

   pushd .  >/dev/null
   MyPacman=$(sudo pacman --version) 
   if [[ ! "$MyPacman" == *"Pacman v5.0.2"* ]]; then 
      # pacman is higher than 5.0.2? (5.0.2. = neeo-supplied level)
      echo "Pacman is already at the correct level"
   	#sudo pacman -Su pacman --noconfirm --overwrite '/*' #use  new style
   else
      echo "Running old system-files, need to update"
      SubFunction_Update_Pacman     # call subfunction to handle updating the system and pacman
   fi
   # the update will break the timesync-daemon, now requiring a userid for the time sync-daemon
   # so let's add it if it's not there yet.  
   MyPasswd=$(cat /etc/passwd | grep -i systemd-timesync)
   if [ "$?" -ne 0 ]
      then
       sudo useradd systemd-timesync -m -d /home/systemd-timesync
   fi

   # and remove some annoying error-messages on login because of a missing dunction in perl
    MyPerlAppend=$(cat /etc/profile.d/perlbin.sh |grep 'append_path ()')
    if [[ "$MyPerlAppend" == "" ]]
       then
        echo "append_path () {
          case \":$PATH:\" in
              *:\"$\1\":*)
                  ;;
              *)
                  PATH=\"${PATH:+$PATH:}$1\"
          esac
        }" > ~/perlbins1.sh
        sudo cp /etc/profile.d/perlbin.sh /etc/profile.d/perlbin.sh.org
        if [ "$?" -ne 0 ]
           then
           echo "Error in saving old perlbin-profile, not updating"
        else
           cat ~/perlbins1.sh /etc/profile.d/perlbin.sh > ~/perlbin.sh 
           sudo cp ~/perlbin.sh /etc/profile.d/perlbin.sh
           rm ~/perlbins1.sh
           rm ~/perlbin.sh 
        fi
   fi
   popd  >/dev/null  
   Do_SetNextStage $NextStep


}

function Do_Install_NVM()
{
#3
   echo "Stage $Exec_install_nvm: installing NVM, then secondary npm&node"
   NextStep=$Exec_finish_nvm      

   pushd .  >/dev/null
   if [ -e  ~/.nvm/nvm.sh ]
      then 
      echo "NVM already installed"
   else   
      mkdir ~/.nvm 
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
      sudo chmod -R ugo+rx /home/neeo/.nvm 
   fi

   MyBashrc=$(cat ~/.bashrc |grep 'export NVM_DIR="$HOME/.nvm')
   if [ "$?" -ne 0 ]
      then
       echo 'export NVM_DIR="$HOME/.nvm" ' >> ~/.bashrc
       echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm'>> ~/.bashrc
   fi
   . ~/.bashrc   
   export NVM_DIR="$HOME/.nvm" 
   cd ~/.nvm 
   MyNode=$(node -v)
   if [[ $MyNode == "v12.20.0" ]]
      then
      echo "Node is already installed"
   else
      . ~/.nvm/nvm.sh 
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
   fi

   MyBashrc=$(cat ~/.bashrc |grep 'export PM2_HOME=/steady/neeo-custom/.pm2neeo/.pm2')   # add some usefull commands to .bashrc to make life easier
   if [ "$?" -ne 0 ]
      then
       echo 'export PM2_HOME=/steady/neeo-custom/.pm2neeo/.pm2' >> ~/.bashrc
   fi
   . ~/.bashrc
   Do_SetNextStage $NextStep

}

function Do_Finish_NVM()
{
#4
   echo "Stage $Exec_finish_nvm: Finishing setup npm&node"
   NextStep=$Exec_install_git
       
  pushd .  >/dev/null
   MyNPM=$(npm -v)
   if [[ ! "$MyNPM" == "" ]]  
      then
      echo "NPM 6.14.9 was already installed, skipping" 
   else
      cd /steady/neeo-custom/
      npm install npm -g  --no-fund
      if [ "$?" -ne 0 ]
         then
          echo 'Error installing npm (npm install npm -g)'
          GoOn=0
          popd  >/dev/null 
          return
      fi 
   fi
       popd >/dev/null 
    Do_SetNextStage $NextStep

}

function Do_Install_Git()
{
#5
   echo "Stage $Exec_install_git: installing GIT"
   NextStep=$Exec_install_meta     

   MyCommand=$(command -v git)
   if [[ "$MyCommand" == "" ]]
      then 
      MyRetries=$RetryCountPacman
      NoSuccessYet=1
      while  [  $NoSuccessYet -eq 1 ] ; do
         sudo pacman -S --overwrite  '/*' --noconfirm  git
         if [ "$?" -ne 0 ]
             then
             if [[ $MyRetries -gt 1 ]]
                then 
                echo 'Error occured during Install of Git - retrying'
             else 
               echo ' Error occured during Install of Git - giving up'
               GoOn=0
               return
             fi          
         else
           NoSuccessYet=0       # signal done, break the loop
         fi
         ((MyRetries=MyRetries-1))
      done
   else
      echo "Git is already installed"   
   fi
    Do_SetNextStage $NextStep

}

function Do_Install_Meta()
{
#6
   echo "Stage $Exec_install_meta: installing Metadriver (JAC459/metadriver)"
      
   if [[ "$UpgradeMetaOnly_requested" == "1" ]]
      then
      NextStep=$Exec_setup_pm2
   else
      NextStep=$Exec_install_mosquitto     
   fi

  pushd .  >/dev/null
   cd /steady/neeo-custom/ 
   if [[ ! -e  ".meta"  ]]
       then 
      mkdir .meta
   fi
   cd .meta 
   npm install jac459/metadriver  --no-fund
   if [ "$?" -ne 0 ]
       then
        echo 'Install of metadriver failed'
        GoOn=0
        popd >/dev/null 
        return
   fi
   popd >/dev/null 

   Do_SetNextStage $NextStep

}

function Do_Install_Mosquitto()
{
#7
   echo "Stage $Exec_install_mosquitto: installing Mosquitto"
   NextStep=$Exec_install_nodered      

   MyCommand=$(command -v mosquitto)
   if [[ "$MyCommand" == "" ]]
      then 
      MyRetries=$RetryCountPacman
      NoSuccessYet=1
      while  [[  $NoSuccessYet -ne 0 ]] ; do
         sudo pacman -S  --noconfirm --overwrite  /usr/lib/libnsl.so,/usr/lib/libnsl.so.2,/usr/lib/pkgconfig/libnsl.pc  mosquitto
         if [ "$?" -ne 0 ]
             then
             if [[ $MyRetries -gt 1 ]]
                then 
                echo 'Error occured during Install of Mosquitto - retrying'
             else 
                echo ' Error occured during Install of Mosquitto - giving up'
               GoOn=0
               return
             fi          
         else
          NoSuccessYet=0       # signal done, break the loop
         fi
         ((MyRetries=MyRetries-1))
      done
   fi 
 
    Do_SetNextStage $NextStep
}

function Do_Install_NodeRed()
{   
#8
   echo "Stage $Exec_install_nodered: installing Node-Red"
   NextStep=$Exec_backup_solution


 
   if [[ ! -e /steady/neeo-custom/.node-red/node_modules/node-red/red.js ]]
      then 
 
      echo ""
      echo ""
      echo "This tsk will run and multiple ways to install are attempted"
      echo "    Therefore you WILL see errors, IGNORE ˜THEM!"
      echo "     Check last statements, should be:"
      echo "        + node-red@1.2.6"
      echo "        added 316 packages from 284 contributors"
      echo ""
      echo ""       

      pushd . >/dev/null
      mkdir /steady/neeo-custom/.node-red
      cd /steady/neeo-custom/.node-red
      npm install --unsafe-perm node-red  --no-fund
      if [[ "$?" -ne 0 ]]
          then
         echo 'Install of NodeRed failed'
         GoOn=0
         popd >/dev/null
         return
      fi
      cd /steady/neeo-custom/.node-red/node_modules/node-red
      ln -s red.js node-red.js
      popd >/dev/null
   fi 
   Do_SetNextStage $NextStep 

}

function Do_Backup_solution()
{
#9
   echo "Stage $Exec_backup_solution: Setting up backup"
   NextStep=$Exec_install_jq

   MyCommand=$(command -v rsync)
   if [[ "$MyCommand" == "" ]]
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
   Do_SetNextStage $NextStep

}

function Do_install_jq()
{
#A
   echo "Stage $Exec_install_jq : add jq package"
   NextStep=$Exec_install_python

   MyCommand=$(command -v jq)
   if [[ "$MyCommand" == "" ]]
      then
      MyRetries=$RetryCountPacman
      NoSuccessYet=1
      while  [  $NoSuccessYet -ne 0 ] ; do
         sudo pacman -S --overwrite  '/*' --noconfirm  jq
         if [ "$?" -ne 0 ]
             then
             if [[ $MyRetries -gt 1 ]]
                then
                echo 'Error occured during Install of jq - retrying'
             else
               echo ' Error occured during Install of jq	 - giving up'
               GoOn=0
               return
             fi
         else
          NoSuccessYet=0       # signal done, break the loop
         fi 
         ((MyRetries=MyRetries-1))
      done
   fi

   Do_SetNextStage $NextStep

}


function Do_install_python()
{
#B
   echo "Stage $Exec_install_python : add python3 package"
   NextStep=$Exec_install_broadlink

   MyCommand=$(command -v python3)
   if [[ "$MyCommand" == "" ]]
      then
      MyRetries=$RetryCountPacman
      NoSuccessYet=1
      while  [  $NoSuccessYet -ne 0 ] ; do
         sudo pacman -S --overwrite  '/*' --noconfirm  python python-pip
         if [ "$?" -ne 0 ]
             then
             if [[ $MyRetries -gt 1 ]]
                then
                echo 'Error occured during Install of python - retrying'
             else
               echo ' Error occured during Install of python         - giving up'
               GoOn=0
               return
             fi
         else
          NoSuccessYet=0       # signal done, break the loop
         fi
         ((MyRetries=MyRetries-1))
      done
   fi  
       
   Do_SetNextStage $Exec_install_broadlink
   
}

function Do_install_broadlink()
{
#C
   echo "Stage $Exec_install_broadlink : add broadlink support"
   NextStep=$Exec_setup_pm2

   pushd . >/dev/null
   if [[ ! -e /steady/neeo-custom/.broadlink ]]
      then 
      cd /steady/neeo-custom
      if [[ ! -e ".broadlink" ]]
         then
         mkdir .broadlink
      fi
      cd .broadlink
   fi

   if [[ ! -e /steady/neeo-custom/.broadlink/python-broadlink/setup.py ]]
      then
      git clone https://github.com/mjg59/python-broadlink
      if [ "$?" -ne 0 ]
         then
            echo 'Error occured during download of broadlink - retrying'
            popd >/dev/null
            GoOn=0
            return
      fi
   fi 

   # next step will Always install broadlink driver, even if it is there already... just too much uncertainty where to check if it is already installed  
   cd /steady/neeo-custom/.broadlink/python-broadlink 
   sudo python setup.py install
   if [ "$?" -ne 0 ]
      then
      popd >/dev/null
      echo 'Error occured during Install of broadlink support'
      GoOn=0
      return
   fi
   popd >/dev/null

   Do_SetNextStage $NextStep
}

function SubFunction_Remove_Old_PM2()
{  
#Xa
   echo "Stage $Exec_setup_pm2: Removing older versions of PM2"

# Remove old versions of PM2 that are setup to run as service

   pm2 kill 2>/dev/null 1>/dev/null          #Kill old pm2-process that runs as user neeo
   sudo pm2 kill 2>/dev/null 1>/dev/null     #Kill old pm2-process that might have been started by the user by mistake (sudo pm2 xxx)

}


function Do_Setup_PM2()
{
#X

   echo "Stage $Exec_setup_pm2: Activating services in PM2"
   NextStep=$Exec_finish   

   if [[  "$UpgradeMetaOnly_requested" == "1" ]]
      then 
         pm2 restart meta
         Do_SetNextStage $NextStep
         return
   fi 
   sudo chown -R neeo /steady/neeo-custom/.pm2neeo 1>/dev/null 2>/dev/null  
   SubFunction_Remove_Old_PM2    # first run the remove "old-style PM2" function 
         
   pushd . >/dev/null
   cd /steady/neeo-custom
   if [[ ! -e ".pm2neeo" ]]
       then
      mkdir .pm2neeo
      MyRemoveOld=$(sudo rm -r /steady/neeo-custom/.pm2)        # remove directories that were used by older PM2-instances  
      MyRemoveOld=$(sudo rm -r /steady/neeo-custom/pm2-meta)    $ same
   fi
   
   pm2 startup
   sudo chown -R neeo /steady/neeo-custom/.pm2neeo 1>/dev/null 2>/dev/null
   sudo env PM2_HOME=/steady/neeo-custom/.pm2neeo/.pm2/  /var/opt/pm2/lib/node_modules/pm2/bin/pm2 startup systemd -u neeo --hp /steady/neeo-custom/.pm2neeo/ 2>/dev/null 1>/dev/null
   sudo chown -R neeo /steady/neeo-custom/.pm2neeo 1>/dev/null 2>/dev/null

   export PM2_HOME=/steady/neeo-custom/.pm2neeo/.pm2 # make sure we can run the next pm2-commands under the correct PM2 (the one we just setuop) 
   pm2 delete mosquitto 2>/dev/null 1>/dev/null
#   pm2 start mosquitto  -o "/dev/null" -e "/dev/null"  # we'll keep this one for later
   pm2 start mosquitto
   if [[ "$?" != 0 ]]
      then 
      echo "Error adding mosquitto-start to PM2"
      GoOn=0
      return
   fi 

   cd /steady/neeo-custom/.node-red/node_modules/node-red
   pm2 delete node-red  2>/dev/null 1>/dev/null          #Kill old pm2-process that runs as user neeo
   pm2 start node-red.js   --node-args='--max-old-space-size=128'
   if [[ "$?" != 0 ]]
      then 
      echo "Error adding node-red-start to PM2"
      GoOn=0
      return      
   fi 

   cd /steady/neeo-custom/.meta/node_modules/@jac459/metadriver
   pm2 delete meta  2>/dev/null 1>/dev/null          #Kill old pm2-process that runs as user neeo
   pm2 start --name meta meta.js  --  '{"Brain":"localhost"}'

   if [[ "$?" != 0 ]]
      then 
      echo "Error adding meta-start to PM2"
      GoOn=0
      return
   fi

   popd >/dev/null

   pm2 save
   Do_SetNextStage $NextStep
}


function Do_Finish()
{
echo "$LatestVersion:"+$(date +"%Y-%m-%d %T") >>$VersionFile
echo "We are done installng, your installation is now at level v$LatestVersion"

echo "*******************************************************************************************************"
echo "*                                                                                                     *"
echo "*                       !!!!!!!!!!!!!!!!! IMPORTANT!!!!!!!!!!!!!!!!!                                  *"
echo "*                                                                                                     *"
echo "*        To setup the correct user-profile, you MUST either:                                          *"
echo "*        - execute this command: . ~/.bashrc                                                          *"
echo "*     OR - exit this session and start it again                                                       *"
echo "*                                                                                                     *"
echo "*                                                                                                     *"
echo "*                                                                                                     *"
echo "*                                                                                                     *"
echo "*******************************************************************************************************"


}

function    Do_State_Machine()
{
   # We come here if we want the state machine to run.
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
          $Exec_backup_solution)
             Do_Backup_solution
          ;;
          $Exec_install_jq)
             Do_install_jq
          ;;
          $Exec_install_python)
             Do_install_python
          ;;
          $Exec_install_broadlink)
             Do_install_broadlink
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
 
}

function Do_Check_Last_Run()
{ 
# This routine determines if we will continue the previous incompolete run, or start all over again
   if [[ ("$InstalledVersion"  == "1.0") && ("$FoundStage" == "A") ]]        # fix the "old v1.0 Finish-action", so that is compatible with newer versions
      then
      FoundStage="Z"
   fi

   if [ "$FoundStage" != "Z" ]  # Yes, but did we already have a completely installed system?
      then
      echo "Installer was interupted last time it ran, continuing from that point"
      echo "If you want to start this run from the start, please add the --reset argument when starting this script"
   else
      FoundStage=$Exec_all_stages
   fi

}

function RunMain()
{
#This is the main routine, it handles the logic after init is done

   # This one just determines the current version of meta and the latest available one
   if [ "$Determine_versions" == "1" ]
      then
         Do_Version_Check                              # Check if upgrade is possible/allowed
         return
      fi

   GoOn=1
   Do_ReadState                   # check to see if we ran before; if so, get the state of the previous runs and the version of installer thatran
   echo $InstalledVersion

   echo "We are running in stage $FoundStage of $Exec_finish_done"
   Do_Check_Last_Run

   Do_State_Machine

}
function Check_Call_Level()
{
  if [[ $SHLVL -lt 2 ]]
     then
     echo ""
     echo ""
     echo ""   
     echo "This installer needs to be started without the '.'but with 'sh'  in front of the installmeta.sh"
     echo "   please run sh installerneta.sh"
     echo ""
     echo ""
     echo ""
     GoOn=0
  fi
}


##Main routine

# first setup a cntrol-C handler
trap no_ctrlc SIGINT

  GoOn=1

  if [ $# -gt 0 ]; then
    # Parsing any parameters passed to us
    while (( "$#" )); do
      case "$1" in
      --help)
        usage
        GoOn=0
        ;;
      --reset)
        Do_Reset
        ;;
      --meta-only)
        Upgrade_requested=1
        UpgradeMetaOnly_requested="1"
        ;;
      --get-versions)
        Determine_versions=1
        ;;
      -*|--*=) # unsupported flags
        echo ""
        echo ""
        echo ""
        echo "Error: Unsupported flag $1" 
        echo ""
        echo ""
        echo ""
        usage
        GoOn=0
        ;;
      *)
        echo "Please use correct format for arguments, $1 is not recognised" 
        usage
        GoOn=0
        ;;
      esac
      shift
    done
  fi

  Check_Call_Level

  if [[ "$GoOn" == "1" ]]
     then 
      echo "Starting State machine that will orchestrate installaton actions"
     RunMain 
  fi
