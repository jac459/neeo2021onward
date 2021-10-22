#!/bin/bash
#
# Driver script for Meta Installer NEEO-Brain
#
GoOn=1                # the main loop controller
Parm1=$1              # Save parameters passed to driver
Parm2=$2
Parm3=$3

function Do_Mount_root()
{
   # This function makes sure that we have a root-filesystem that is writable, as we're going to need it for sure.
   MyMounts=$(mount|grep 'dev/mmcblk0p2 ')
   if [[ $(echo "$MyMounts" | grep '(ro') ]]
      then 
      echo "/ is still ro, remounting it rw"
      sudo mount -o remount,rw /
      if [ "$?" -ne 0 ]
         then
         echo "The script failed" 
         GoOn=0
         return  
      fi
   fi
} 

function RunMain()
{
#This is the main routine, it picks up after some small checks/initializations
#  Its main purpose is to load the actual backend-code and run it. 
   MyName="installmeta.sh"
   pushd . >/dev/null
   if [[ ( "$MyPath"  == "/tmp/$MyName") || (! -e ~/$MyName) ]] 
      then
      echo "Copying installmeta.sh to homedir ($HOME) for future use"
      cp $BASH_SOURCE ~
   fi

   MyURL='https://raw.githubusercontent.com/jac459/neeo2021onward/main/Meta%20running%20in%20Brain/installmeta-Backend.sh'
   # beta: MyURL=https://raw.githubusercontent.com/jac459/neeo2021onward/Beta-2021-01%233/Meta%20running%20in%20Brain/installmeta-Backend.sh'
   sudo rm -r ~/installmeta-Backend.sh 2>/dev/null
   MyCurl=$(curl $MyURL -s -k -o ~/installmeta-Backend.sh)
   if [ "$?" -ne 0 ]
      then
      echo "Could not download backend, contact support via discord channel"
      GoOn=0
      return  
   fi    

   sh ~/installmeta-Backend.sh $Parm1 $Parm2 $Parm3

   sudo rm -r ~/installmeta-Backend.sh 
}

function Check_elevated_rights
{
    
    MyUsername=$USER
    if [[ "$MyUsername" ==  "root" ]]
      then
       echo "please call this program with normal rights (do not use sudo or su)"
       GoOn=0 
   fi                             
}

function Check_Call_Level()
{
  if [[ $SHLVL -lt 2 ]]
     then
     echo ""
     echo ""
     echo ""   
     echo "This installer needs to be started without the '.'but with 'sh'  in front of the installmeta.sh"
     echo "   please run sh installermeta.sh"
     echo ""
     echo ""
     echo ""
     GoOn=0
  fi
}


##Main routine

MyPath=$0
MyExecutable=$BASH_SOURCE   # save the name and location of this script, we might need to copy script later
Check_Call_Level
if [[  "$GoOn" == "1" ]] 
   then
   Check_elevated_rights
   if [[  "$GoOn" == "1" ]]
      then 
      Do_Mount_root
      if [[  "$GoOn" == "1" ]] 
      then 
         RunMain
      fi
   fi
fi
