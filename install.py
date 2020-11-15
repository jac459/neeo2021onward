
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
import requests

InstalledCheckingVersion = 10
InstalledAndOK = 0
InstalledButNotOK = 90
NotInstalled = 99
PackageTypeUnknown = 0
PackageTypeAPT = 1
PackageTypeNPM = 2
PackageTypeManual = 3
MyPackages =  [{"name":"git","type":PackageTypeAPT,"versionreq": "2.20.1","status":NotInstalled,"installedversion":"","commandline":"git --version","phaserequired":0,"loc":"", "APTParm":"","APTParm2":"","APTUser":"","APTUser":""},
              {"name":"nodejs","type":PackageTypeAPT,"versionreq": "10.21.0","status":NotInstalled,"installedversion":"", "commandline": "nodejs --version","phaserequired":0,"loc":"", "APTParm":"","APTParm2":"","APTUser":""},
              {"name":"npm","type":PackageTypeAPT,"versionreq": "5.8.0","status":NotInstalled,"installedversion":"", "commandline": "npm --version","phaserequired":0,"loc":"", "APTParm":"","APTParm2":"","APTUser":""},
              {"name":"nodered","type":PackageTypeAPT,"versionreq": "","status":NotInstalled,"installedversion":"", "commandline": "node-red list","phaserequired":1,"loc": "", "APTParm":"","APTParm2":"","APTUser":""},
              {"name":"mosquitto","type":PackageTypeAPT,"versionreq": "","status":NotInstalled,"installedversion":"", "commandline": "node-red list","phaserequired":1,"loc": "", "APTParm":"","APTParm2":"","APTUser":""},
              {"name":"meta","type":PackageTypeNPM,"versionreq": "","status":NotInstalled,"installedversion":"", "commandline": "node-red list","phaserequired":1,"loc": ".meta", "APTParm":"npm install ","APTParm2":"jac459/metadriver","APTUser":""},
              {"name":"pm2","type":PackageTypeNPM,"versionreq": "","status":NotInstalled,"installedversion":"", "commandline": "node-red list","phaserequired":1,"loc": "", "APTParm":"npm install -g pm2 ","APTParm2":"","APTUser":"root"}
              ]

InstalledCheckingVersion = 10
PKGNPMIndex = -1
PKGNodeRedIndex = -1
InstalledAndOk = 0
BuildMetaPhase = 0
BuildNodeRedORMQTTPhase = -1

#===============================================================================
# Define various  functions
#===============================================================================


def CheckPackageInstalled(ThisPackage,ThisType):

    PackageCache.open()
    try:
       pkg = PackageCache[ThisPackage]
    except KeyError:
       PackageCache.close()
       return ""

    if pkg.is_installed:
        try: 
            inst_ver = pkg.installed.version
        except AttributeError:
            inst_ver = pkg.installedVersion
    else:
        return ""

    PackageCache.close()
    return inst_ver

def GetMyPackageFields(GetPKG):

    print("Looking for",GetPKG)
    for pkg in MyPackages:
        if pkg['name'] == GetPKG:
           return pkg

    DoWhip = "whiptail --title 'Example Dialog' --msgbox 'LOGIC-ERROR! Incorrect package requested "+ GetPKG +  "' 8 78"
    subprocess.call(DoWhip,shell=True)
    return ""

def TestPackages_OK(Phase):
    global AllDepsOK
    global CheckedDependenciesAlready

    CheckedDependenciesAlready = True
    AllDepsOK = True
    MyIndex = 0
    #"name":"git","type": "","versionreq": "2.20.1","status":0,"installedversion":"","commandline":"git --version","phaserequired":0}
    for pkg in MyPackages:
       if pkg['name']  == "npm":
          PKGNPMIndex =  MyIndex
       elif pkg['name']  == "nodered":
         PKGNodeRedIndex = MyIndex

       Installed = CheckPackageInstalled(pkg['name'],pkg['type'])
       if Installed != "":
          pkg['status'] = InstalledCheckingVersion		#Signal package is installed
          VersionOnly = re.match(r'^[0-9.:]*',Installed)
          i = VersionOnly[0].find(':')
          if i != -1:
              Installed=VersionOnly[0][i+1:]
          else:
               Installed=VersionOnly[0]
          pkg['installedversion'] = Installed.strip()
          if  pkg['installedversion'] < pkg['versionreq'].strip():
              pkg['status'] = InstalledButNotOK                #Signal package is installed, but version is too low
              if pkg['return AllDepsOK'] <= Phase:
                 AllDepsOK = False
          else:
              pkg['status'] = InstalledAndOK                   #Signal package is installed with correct version
       else:
              AllDepsOK = False
       MyIndex = MyIndex +1

    return AllDepsOK

def CheckDependencies(Phase):
    AllPAckagesForThisPhaseAreOK = True
    for pkg in MyPackages:
       if pkg['phaserequired']  <= Phase:
          if pkg['status']  !=  InstalledAndOK:
             AllPAckagesForThisPhaseAreOK = False

    return AllPAckagesForThisPhaseAreOK

def DisplayPrimaryMenu():
    global CheckedDependenciesAlready
    global AllDepsOK
    WT_HEIGHT =  20
    WT_WIDTH  = 40
    WT_MENU_HEIGHT = 12

    DoWhip = "whiptail --title 'Raspberry pi configurator for NEEO' --menu 'Setup Options' 30 70 20 " + \
             " --cancel-button Finish --ok-button Select "
    if CheckedDependenciesAlready == False:
       DoWhip += "'1 Check' 'Check dependencies'    \
             '7 Simple' 'Simply install all of the above'  \
             'P Preferences' 'Display/change user preferences'  \
             'X Exit' 'Exit the program'  2>" + LogDir + "/Mainmenu.txt"
    else:
       DoWhip += "'1 Check' 'Check dependencies'   \
             '2 Install dep' 'Install the required dependencies' \
             '3 Install Metadriver' 'Install and setup Metadriver' \
             '4 Install PM2' 'Install PM2' \
             '5 Install mosquitto' 'Install and setup mosquitto' \
             '6 Install NodeRed' 'Install and setup NodeRed' \
             '7 examples' 'Refresh examples in Activated directory'  \
             'S Startup' 'Create utostart for nodered'  \
             '8 Simple' 'Simply install all of the above'  \
             'P Preferences' 'Display/change user preferences'  \
             'X Exit' 'Exit the program'  2>" + LogDir + "/Mainmenu.txt"
    Response = subprocess.call(DoWhip,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/Mainmenu.txt')
       Choice = fp.readline()
       fp.close()
       return  Choice
    else:
       print("User cancelled the dialog")
       return "@"  # signal somethiong is wrong with the main menu

def ShowPackageStatus():

    DoWhip = "whiptail --title 'Overview status of dependencies'  --msgbox "
    for pkg in MyPackages:
       Content = "' Required: " + pkg['name'] + " " + pkg['versionreq']
       Content = Content.ljust(35, ' ')
       if pkg['type'] ==  PackageTypeAPT:
          Content += " APT "
       elif  pkg['type'] ==  PackageTypeNPM:
          Content += " NPM "
       if  pkg['status']  == InstalledAndOK:
           Content += "Found:  "+ pkg['installedversion']  + " --> OK\n'"
       elif  pkg['status'] == InstalledButNotOK:
           Content += "Found:  " + pkg['installedversion'] + " --> Version is too low\n'"
       else:
           Content +=  "Not found --> Need to install\n'"
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
            # lookup extra parms
            pkg = GetMyPackageFields(ThisPackage.strip())
            InstallPackage(pkg)
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

def InstallPackage(pkg):
    global DidAPTUpdate
    InstalledSomething = False
    if DidAPTUpdate == False:
       DidAPTUpdate = True
       DoAPTUpdate()
    if pkg['type'] == PackageTypeAPT:   #Is this an APT-package?
       APTAddPackageCMD = "apt install -y "+ pkg['name'] + " 1>" + LogDir + "/BackgroundAPTInstall" + pkg['name'] + ".txt"
       print(APTAddPackageCMD)
       Response = subprocess.call(APTAddPackageCMD,shell=True)
       Result = ""
       if Response == 0:
          fp =  open(LogDir + "/BackgroundAPTInstall" + pkg['name'] + ".txt")
          Result = fp.readline()
          fp.close()
          print("Done apt install",Result)
       return Result

    MyLoc = ""
    if pkg['type'] == PackageTypeNPM:   # Is this a NPM-package?
       if pkg['loc'] != "":              # Do we need to insyall it on a specific location?
          print("We need to check custom location now",pkg['loc'])
          InstallDir = OriginalHomeDir+"/"+pkg['loc']
          MyLoc = " --prefix " + '"' + InstallDir + '"' + " " 
          if os.path.isdir(InstallDir) == False:
             DoMKDirCMD = "su -m "+ OriginalUsername + " -c 'mkdir  "  + '"' + InstallDir + '"' + " 2>"+ LogDir + "/BackgroundMkdir.txt'"
             print(DoMKDirCMD)
             Response = subprocess.call(DoMKDirCMD,shell=True)
             if Response == 0:   
                fp =  open(LogDir + "/BackgroundMkdir.txt")
                LineIn = fp.readline()
                print(LineIn)
                fp.close()   
             else:
                print("Fatal error ocurred  when creating directory for  metadriver: ",InstallDir)
                sys.exit(12)
       if pkg['APTUser'] != "":
          APTNPMPackageCMD =  pkg['APTParm'] +  " "  +  MyLoc  + " " + pkg['APTParm2'] + "  2>" + LogDir + "/BackgroundNPM"+ pkg['name'] + ".txt"
       else:
          APTNPMPackageCMD = "su -m "+ OriginalUsername + " -c 'export HOME="+OriginalHomeDir + "&& " +  pkg['APTParm'] +  " "  +  MyLoc  + " " + pkg['APTParm2'] + "  2>" + LogDir + "/BackgroundNPM"+ pkg['name'] + ".txt'"
       print(APTNPMPackageCMD)
       Response = subprocess.call(APTNPMPackageCMD,shell=True)
       Result = ""
       if Response == 0:
          fp =  open(LogDir + "/BackgroundNPM" + pkg['name'] + ".txt")
          Result = fp.readline()
          fp.close()
          print("Done apt install",Result)
       return Result

def SelectPackageToInstall():

    DoWhip = "whiptail --title 'Install dependencies'   --checklist  'Select packages you want to be installed'  25 78 4 "
    MyIndex = 0
    for pkg in MyPackages:
       if  pkg['status']  != InstalledAndOK:
           Content = "'"+ pkg['name'] + "' '" + pkg['name'] + " " + pkg['versionreq']  +  "' "
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

def Do_Check_dependencies():
    if TestPackages_OK(0) != True:
       ShowPackageStatus()

def Do_PreferencesMenu():
    print("We are going to setup some preferences")

def HandleChoice(i):
    switcher = {
            "1": lambda: Do_Check_dependencies(),
            "2": lambda: Do_Install_dependencies(),
            "3": lambda: Do_Install_Meta(),
            "4": lambda: Do_Install_PM2(),
            "5": lambda: Do_Install_mosquitto(),
            "6": lambda: Do_Install_NodeRed(),
            "7": lambda: Do_Refresh_NEEOCustom(),
            "8": lambda: Do_It_All(),
            "s": lambda: Do_SetupServiceNodeRed(),
            "S": lambda: Do_SetupServiceNodeRed(),   
            "p": lambda: Do_PreferencesMenu(),
            "P": lambda: Do_PreferencesMenu(),
            "x": lambda: Do_Exit(),
            "X": lambda: Do_Exit()
        }
    func = switcher.get(i[0], lambda: 'Invalid')
    func()

def Do_Install_mosquitto():
    print("Dependencies for mosquitto okay?")
    if CheckDependencies(BuildNodeRedORMQTTPhase)!=True:   # n oit all dependencies have been fulfilled
       DoWhip = "whiptail --title 'Example Dialog' --msgbox 'Not all dependencies are fullfilled, please run function 1 and 2 first.' 8 78"
       subprocess.call(DoWhip,shell=True)
       return 12

    print("Now we install mosquitto.")
    print("First we need to get the gpg-key for mosquitto")
    print("wget http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key")
    DoCMD = "wget http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key 2>" + LogDir + "/BackgroundmosquittoWget.txt"
    Response = subprocess.call(DoCMD,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/BackgroundmosquittoWget.txt')
       Choice = fp.readline()
       fp.close()   
    else:
       print("Fatal error ocurred while getting gpg-keys for mosquitto")
       sys.exit(12)     
    print("Applying key, so we can get the mosquittopackage....")
    DoCMD = "apt-key add mosquitto-repo.gpg.key 2>" + LogDir + "/BackgroundmosquittoAddKey.txt"
    Response = subprocess.call(DoCMD,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/BackgroundmosquittoAddKey.txt')
       Choice = fp.readline()
       fp.close()   
    else:
       print("Fatal error ocurred while applying  gpg-keys for mosquitto")
       sys.exit(12)     
    print("Now we only need to update apt, so it will know the mosquitto package, then we can install ite....")    
    DoAPTUpdate()
    print("Ready to install mosquitto.....") 
    print("This will taske some time, please let this process continue....")
    InstallPackage("mosquitto") 

def Do_SetupServiceNodeRed():
    DONodeRedStart = "systemctl enable nodered.service"
    print(DONodeRedStart)
    Response = subprocess.call(DONodeRedStart,shell=True)
    if Response == 0:
       print("That's it, NodeRed is configured to autostart")
    else:
       print("Fatal error ocurred while setting up autostart NodeRed")
       sys.exit(12)
    DONodeRedStart = "systemctl start  nodered.service"
    Response = subprocess.call(DONodeRedStart,shell=True)
    print(DONodeRedStart)

def Do_Install_NodeRed(): 
    print("Dependencies for NodeRed okay?")
    if CheckDependencies(BuildNodeRedORMQTTPhase) != True:    # are all dependencies for thjis phase fulfilled?
       DoWhip = "whiptail --title 'Example Dialog' --msgbox 'Not all dependencies are fullfilled, please run function 1 and 2 first.' 8 78"
       subprocess.call(DoWhip,shell=True)
       return 12

    print("Now we install NodeRed.")
    print("This will taske some time, please let this process continiue....")
    InstallPackage("nodered") 

    DONodeRedStart = "systemctl enable nodered.service"
    print(DONodeRedStart)
    Response = subprocess.call(DONodeRedStart,shell=True)
    if Response == 0:
       print("That's it, NodeRed is installed and configured")
    else:
       print("Fatal error ocurred while installing NodeRed")
       sys.exit(12)

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

def Do_Install_PM2():

    print("Dependencies for PM2 okay?")
    if CheckDependencies(BuildMetaPhase)!=True:   # n oit all dependencies have been fulfilled
       DoWhip = "whiptail --title 'Example Dialog' --msgbox 'Not all dependencies are fullfilled, please run function 1 and 2 first.' 8 78"
       subprocess.call(DoWhip,shell=True)
       return 12

def Do_Install_Meta(): # Install Metadriver
    global AllDepsOK
    global OriginalHomeDir
    global OriginalUID
    global OriginalGID
    global InstallDir

    print("Dependencies for Metadriver okay?")
    if CheckDependencies(BuildMetaPhase)!=True:   # n oit all dependencies have been fulfilled
       DoWhip = "whiptail --title 'Example Dialog' --msgbox 'Not all dependencies are fullfilled, please run function 1 and 2 first.' 8 78"
       subprocess.call(DoWhip,shell=True)
       return 12

    if os.path.isdir(InstallDir) == False:
       DoMKDirCMD = "su -m "+ OriginalUsername + " -c 'mkdir  "  + '"' + InstallDir + '"' + " 2>"+ LogDir + "/BackgroundMkdir.txt'"
       Response = subprocess.call(DoMKDirCMD,shell=True)
       if Response == 0:
          fp =  open(LogDir + '/BackgroundMkdir.txt')
          LineIn = fp.readline()
          print(LineIn)
          fp.close()
       else:
          print("Fatal error ocurred  when creating directopry for  metadriver: ",InstallDir)
          sys.exit(12)

    DoMKdirCMD = "su -m "+ OriginalUsername + " -c 'export HOME="+OriginalHomeDir + "&& npm install --prefix " + '"' + InstallDir + '"' + "    jac459/metadriver 2>" + LogDir + "/BackgroundNPMMeta.txt'"
    Response = subprocess.call(DoMKdirCMD,shell=True)
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
global DidAPTUpdate
global AllDepsOK
global CheckedDependenciesAlready 
AllDepsOK = False
CheckedDependenciesAlready = False

if __name__ == "__main__":
   DoSomeInit()
   GoOn = True
   DidAPTUpdate = False
   while GoOn == True:
       MenuChoice = DisplayPrimaryMenu()
       if MenuChoice == "@":
           GoOn = False
           continue
       else:
           HandleChoice(MenuChoice)

   #TestPackages_OK()



