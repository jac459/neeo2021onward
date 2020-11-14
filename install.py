
#import cookielib
import sys
import os
import apt
import re
import subprocess
import tempfile
#import getent
#import Tkinter as tk 
#import urllib
#import urllib2
#import unicodedata
#import zlib
#import shutil
#from urllib2 import Request
#import requests

InstalledCheckingVersion = 10
InstalledAndOK = 0
InstalledButNotOK = 90
NotInstalled = 99
MyPackages =  ["git","nodejs","npm"]
MyPackageVersion =  ("2.20.1","10.21.0 ","5.8.0","0")
MyPackageStatus =  [NotInstalled,NotInstalled,NotInstalled,NotInstalled]
MyPackageInstalled = ["","","",""]
InstalledCheckingVersion = 10
InstalledAndOk = 0
#AllDepsOK  = False
#DidAPTUpdate = False

#===============================================================================
# Define various  functions
#===============================================================================


def CheckPackageInstalled(ThisPackage):
   
    PackageCache.open()
    try:
       pkg = PackageCache[ThisPackage]
    except KeyError:
       print("Package ", ThisPackage,  " is not a package")
       return ""
    if pkg.is_installed:
        try: 
            inst_ver = pkg.installed.version
        except AttributeError:
            inst_ver = pkg.installedVersion
        return inst_ver
    else:
        return ""

    PackageCache.close()


def TestPackages_OK():
    global AllDepsOK
    AllDepsOK = True
    MyIndex = 0
    for ThisPackage in MyPackages: 
       Installed = CheckPackageInstalled(ThisPackage)
       if Installed != "":
          MyPackageStatus[MyIndex] = InstalledCheckingVersion		#Signal package is installed
          VersionOnly = re.match(r'^[0-9.:]*',Installed)
          i = VersionOnly[0].find(':') 
          if i != -1:
              Installed=VersionOnly[0][i+1:]
          else:
              Installed=VersionOnly[0]
          MyPackageInstalled[MyIndex] = Installed.strip() 
          if  MyPackageInstalled[MyIndex] < MyPackageVersion[MyIndex].strip():
              MyPackageStatus[MyIndex] = InstalledButNotOK                #Signal package is installed, but version is too low
              AllDepsOK = False
          else:
              MyPackageStatus[MyIndex] = InstalledAndOK                   #Signal package is installed with correct version
       else:
              AllDepsOK = False
       MyIndex = MyIndex +1
    return AllDepsOK


def DisplayPrimaryMenu():
    WT_HEIGHT =  20
    WT_WIDTH  = 40
    WT_MENU_HEIGHT = 12

    DoWhip = "whiptail --title 'Raspberry pi configurator for NEEO' --menu 'Setup Options' 30 70 20 " + \
             " --cancel-button Finish --ok-button Select " \
             "'0 Preferences' 'Display/change user preferences' "
    if AllDepsOK:         
       DoWhip += "'1 Check' 'All dependencies are Okay' "        
    else:
       DoWhip += "'1 Check' 'Check dependencies' " 
    DoWhip += "'2 Install dep' 'Install the required dependencies' \
             '3 Install Metadriver' 'Install and setup Metadriver' \
             '4 Install Mosquito' 'Install and setup Mosquito' \
             '5 Install NodeRed' 'Install and setup NodeRed' \
             '6 Refresh Activated' 'Refresh files in Activated & deactivated folders'  \
             '7 Simple' 'Simply install all of the above'  \
             '9 Exit' 'Exit the program'  2>" + LogDir + "/Mainmenu.txt" 
    Response = subprocess.call(DoWhip,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/Mainmenu.txt')
       Choice = fp.readline()
       fp.close()
       return  Choice
    else:
       print("User cancelled the dialog")
       return -99

def ShowPackageStatus():

    DoWhip = "whiptail --title 'Overview status of dependencies'  --msgbox "
    MyIndex = 0
    for ThisPackage in MyPackages:
       Content = "' Required: " + MyPackages[MyIndex] + " " + MyPackageVersion[MyIndex]   +  " "
       Content = Content.ljust(35, ' ')
       if  MyPackageStatus[MyIndex] == InstalledAndOK:
           Content += "Found:  "+ MyPackageInstalled [MyIndex] + " --> OK\n'"
       elif  MyPackageStatus[MyIndex] == InstalledButNotOK:
           Content += "Found:  " + MyPackageInstalled [MyIndex] + " --> Version is too low\n'"
       else:
           Content +=  "Not found --> Need to install\n'"
       MyIndex += 1
       DoWhip +=  Content 
    DoWhip +=  " 25 80 70 "
    subprocess.call(DoWhip,shell=True)

def Do_Install_dependencies():

    DoThis = SelectPackageToInstall()
    InstalledSomething = False
    if type(DoThis) == type(None) or DoThis.strip() == "":
       return
    for ThisPackage in DoThis.split('"'):
         if ThisPackage.strip() != "": 
            #print("Installing ",ThisPackage.strip())
            InstallPackage(ThisPackage.strip())
            InstalledSomething = True
    if InstalledSomething:
       PackageCache.update()

def DoAPTUpdate():
    APTUpdateCMD = "apt update -y 1>" + LogDir + "/BackgroundAPTUpdate.txt"
    Response = subprocess.call(APTUpdateCMD,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/BackgroundAPTUpdate.txt')
       Result = fp.readline()
       fp.close()
       #print("Did an apt update",Result) 
       return 

def InstallPackage(ThisPackage):
    global DidAPTUpdate
    InstalledSomething = False
    if DidAPTUpdate == False:
       DidAPTUpdate = True
       DoAPTUpdate()

    APTAddPackageCMD = "apt install -y " + ThisPackage + " 1>" + LogDir + "/BackgroundAPTInstall.txt"
    Response = subprocess.call(APTAddPackageCMD,shell=True)
    Result = ""
    if Response == 0:
       fp =  open(LogDir + '/BackgroundAPTInstall.txt')
       Result = fp.readline()
       fp.close()
       #print("Done apt install",Result)
    return Result

def SelectPackageToInstall():

    DoWhip = "whiptail --title 'Install dependencies'   --checklist  'Select packages you want to be installed'  25 78 4 "
    MyIndex = 0
    for ThisPackage in MyPackages:
       if  MyPackageStatus[MyIndex] != InstalledAndOK:
           Content = "'"+ MyPackages[MyIndex] + "' '" + MyPackages[MyIndex] + " " + MyPackageVersion[MyIndex]   +  "' "
           Content = Content.ljust(35, ' ') + "ON "
           DoWhip +=  Content 
       MyIndex += 1
    DoWhip += " 2>" + LogDir + "/BackgroundPackageToInstall.txt"
    Response = subprocess.call(DoWhip,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/BackgroundPackageToInstall.txt')
       Choice = fp.readline()
       fp.close()
       return Choice

def as_unix_user(uid, gid=None):  # optional group
    def wrapper(func):
        def wrapped(*args, **kwargs):
            pid = os.fork()
            if pid == 0:  # we're in the forked process
                if gid is not None:  # GID change requested as well
                    os.setgid(gid)
                os.setuid(uid)  # set the UID for the code within the `with` block
                func(*args, **kwargs)  # execute the function
                os._exit(0)  # exit the child process
        return wrapped
    return wrapper

def Do_Check_dependencies():
    if TestPackages_OK() != True:
       ShowPackageStatus()
def Do_PreferencesMenu():
    print("We are going to setup some preferences") 
def HandleChoice(i):
    switcher = {
            0: lambda: Do_PreferencesMenu(),
            1: lambda: Do_Check_dependencies(),
            2: lambda: Do_Install_dependencies(),
            3: lambda: Do_Install_Meta(),
            4: lambda: Do_Install_Mosquito(),
            5: lambda: Do_Install_NodeRed(),
            6: lambda: Do_Refresh_NEEOCustom(),
            7: lambda: Do_It_All(),
            9: lambda: Do_Exit(),
        }
    func = switcher.get(int(i[0]), lambda: 'Invalid')
    func()
    
    # Main menu looks like this:
    #DoWhip += "'1 Check' 'Check dependencies' " 
    #DoWhip += "'2 Install dep' 'Install the required dependencies' \
    #         '3 Install Metadriver' 'Install and setup Metadriver' \
    #         '4 Install Mosquito' 'Install and setup Mosquito' \
    #         '5 Install NodeRed' 'Install and setup NodeRed' \
    #         '6 Refresh Activated' 'Refresh files in Activated & deactivated folders'  \
    #         '7 Simple' 'Simply install all of the aboveo'  \
    #         '9 Exit' 'Exit the program'  2>" + LogDir + "/BackgroundOutput.txt" 


def Do_Install_Mosquito():
    Print("Now we install Mosquito.")

def Do_Install_NodeRed(): 
    Print("Now we install NodeRed.")
def Do_Refresh_NEEOCustom():
     print("We need to refresh 'Activated'and 'Deactivated' directories") 
     # save the non-volatile directories 

     tmpdirname = tempfile.TemporaryDirectory() 
     print('created temporary directory', tmpdirname)
     # Code to save user directories
def Do_It_All():
    Print("Now just run through all the options.")

def Do_Exit():
    sys.exit(12)


def Do_Install_Meta(): # Install Metadriver
    global AllDepsOK
    global OriginalHomeDir
    global OriginalUID
    global OriginalGID
    global InstallDir
    if AllDepsOK != True:
       DoWhip = "whiptail --title 'Example Dialog' --msgbox 'Not all dependencies are fullfilled, please run function 1 and 2 first.' 8 78"
       subprocess.call(DoWhip,shell=True)
       #print("Cannot continue, not all dependencies are fulfilled")
       return 12

    if os.path.isdir(InstallDir) == False:
       #print("Creating meta directory in ",OriginalHomeDir)
       #os.mkdir(InstallDir, 0o755)
       #os.chown(InstallDir,int(OriginalUID),int(OriginalGID) )
       DoMKDirCMD = "su -m "+ OriginalUsername + " -c 'mkdir  "  + '"' + InstallDir + '"' + " 2>"+ LogDir + "/BackgroundMkdir.txt'"
       print(DoMKDirCMD)
       Response = subprocess.call(DoMKDirCMD,shell=True)
       if Response == 0:
          fp =  open(LogDir + '/BackgroundMkdir.txt')
          LineIn = fp.readline()
          print(LineIn)
          fp.close()
       else:
          print("Fatal error ocurred  when creating directopry for  metadriver: ",InstallDir)
          sys.exit(12)

    DoNPMCMD = "su -m "+ OriginalUsername + " -c 'export HOME="+OriginalHomeDir + "&& npm install --prefix " + '"' + InstallDir + '"' + "    jac459/metadriver 2>" + LogDir + "/BackgroundNPMMeta.txt'"
    Response = subprocess.call(DoNPMCMD,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/BackgroundNPMMeta.txt')
       LineIn = fp.readline()
       print(LineIn)
       fp.close()
    else:
       print("Fatal error ocurred  when installing metadriver")
       sys.exit(12)

def DoSomeInit():
    global OriginalUsername
    global OriginalHomeDir
    global OriginalUID
    global OriginalGID
    global PackageCache
    global InstallDir
    global LogDir
    global CurrDir

    OriginalUsername = os.environ['SUDO_USER']
    DoThis = "getent passwd '" + OriginalUsername + "'  | cut -d: -f3,4,6 >BackgroundGetUserProperties.txt"
    Response = subprocess.call(DoThis,shell=True)
    if Response == 0:
       fp =  open('BackgroundGetUserProperties.txt')
       LineIn = fp.readline()
       Fields = LineIn.split(':')
       OriginalUID     = Fields[0]
       OriginalGID     = Fields[1]
       OriginalHomeDir = Fields[2].strip('\n') 
       fp.close()
    else:
       print("Fatal error ocurred  when accessing properties of original userid",OriginalUsername)
       sys.exit(12)

    CurrDir = os.getcwd()
    LogDir =  CurrDir +  "/log"
    
    if os.path.isdir(LogDir) == False:
       DoNPMCMD = "su -m "+ OriginalUsername + " -c 'mkdir  "  + '"' + LogDir + '"' + " 2>BackgroundMkdir.txt'"
       Response = subprocess.call(DoNPMCMD,shell=True)
       if Response == 0:
          fp =  open('BackgroundMkdir.txt')
          LineIn = fp.readline()
          print(LineIn)
          fp.close()
       else:
          print("Fatal error ocurred  when installing metadriver")
          sys.exit(12)

    InstallDir = OriginalHomeDir+"/.meta"
    PackageCache  = apt.cache.Cache() 
    #PackageCache.update()

# Driver program
global   DidAPTUpdate
global AllDepsOK
AllDepsOK = False
if __name__ == "__main__":
   DoSomeInit()
   GoOn = True
   DidAPTUpdate = False
   while GoOn == True:
       MenuChoice = DisplayPrimaryMenu()
       if MenuChoice == -99:
           GoOn = False
           continue
       else:
           HandleChoice(MenuChoice)

   #TestPackages_OK()



