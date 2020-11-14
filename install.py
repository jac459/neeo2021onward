
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
def ShowPackagesInList(PackageList):
    for i in PackageList:
        print (i)

def FillPackageCache(MyCache):
    PackageCache = apt.cache.Cache()
    PackageCache.update()

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
             " --cancel-button Finish --ok-button Select "
    if AllDepsOK:         
       DoWhip += "'1 Check' 'All dependencies are Okay' "        
    else:
       DoWhip += "'1 Check' 'Check dependencies' " 
    DoWhip += "'2 Install dep' 'Install the required dependencies' \
             '3 Install Metadriver' 'Install and setup Metadriver'  2>BackgroundOutput.txt"
    Response = subprocess.call(DoWhip,shell=True)
    if Response == 0:
       fp =  open('BackgroundOutput.txt')
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

def Do_MainMenu_2():

    DoThis = SelectPackageToInstall()
    InstalledSomething = False

    if DoThis.strip() == "":
       return
    for ThisPackage in DoThis.split('"'):
         if ThisPackage.strip() != "": 
            print("Installing ",ThisPackage.strip())
            InstallPackage(ThisPackage.strip())
            InstalledSomething = True
    if InstalledSomething:
       PackageCache.update()

def DoAPTUpdate():
    APTUpdateCMD = "apt update -y 2>BackgroundOutput.txt"
    Response = subprocess.call(APTUpdateCMD,shell=True)
    if Response == 0:
       fp =  open('BackgroundOutput.txt')
       Result = fp.readline()
       fp.close()
       print("Did an apt update",Result) 
       return 

def InstallPackage(ThisPackage):
    global DidAPTUpdate
    InstalledSomething = False
    if DidAPTUpdate == False:
       DidAPTUpdate = True
       DoAPTUpdate()

    APTAddPackageCMD = "apt install -y " + ThisPackage + " 2>BackgroundOutput.txt"
    Response = subprocess.call(APTAddPackageCMD,shell=True)
    Result = ""
    if Response == 0:
       fp =  open('BackgroundOutput.txt')
       Result = fp.readline()
       fp.close()
       print("Done apt install",Result)
       PackageCache.update()
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
    DoWhip += " 2>BackgroundOutput.txt"
    Response = subprocess.call(DoWhip,shell=True)
    if Response == 0:
       fp =  open('BackgroundOutput.txt')
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

def test1():
    print("Current UID: {}".format(os.getuid()))  # prints the UID of the executing user
    Response = subprocess.call("id",shell=True)

@as_unix_user(1000,1000)
def test2(ExecThisCmd):
    subprocess.call(ExecThisCmd,shell=True)    
    #print("Current UID: {}".format(os.getuid()))  # prints the UID of the executing user
    #Response = 0
    return 0 

def Do_MainMenu_1():
    if TestPackages_OK() != True:
       ShowPackageStatus()

def HandleChoice(i):
    switcher = {
            1: lambda: Do_MainMenu_1(),
            2: lambda: Do_MainMenu_2(),
            3: lambda: Do_MainMenu_3(),
            4: lambda: Do_MainMenu_4(),
            5: lambda: Do_MainMenu_5(),
            6: lambda: Do_MainMenu_6(),
            7: lambda: Do_MainMenu_7(),
            8: lambda: Do_MainMenu_8(),
            9: lambda: Do_MainMenu_9()
        }
    func = switcher.get(int(i[0]), lambda: 'Invalid')
    func()


def Do_MainMenu_3(): # Install Metadriver
    global AllDepsOK
    global OriginalHomeDir
    global OriginalUID
    global OriginalGID
    if AllDepsOK != True:
       print("Cannot continue, not all dependencies are fulfilled")
       sys.exit()

    InstallDir = OriginalHomeDir+"/meta"
    if os.path.isdir(InstallDir):
       # save the non-volatile directories 

       tmpdirname = tempfile.TemporaryDirectory() 
       print('created temporary directory', tmpdirname)
    else:
       print("Creating meta directory in ",OriginalHomeDir)
       os.mkdir(InstallDir, 0o755)
       os.chown(InstallDir,int(OriginalUID),int(OriginalGID) )
       
    fp =  open('do_npm.sh','w')
    fp.write("#/bin/bash!\n")
    fp.write("export HOME="+OriginalHomeDir+"\n") 
    fp.write("npm install --prefix '" + InstallDir + "' jac459/metadriver\n")
    fp.close()
    os.chmod("do_npm.sh", 0o777)

    DoNPMCMD = 'su -m '+ OriginalUsername + ' -c "sh do_npm.sh >bb.txt" '
    DoNPMCMD = "su -m "+ OriginalUsername + " -c 'export HOME="+OriginalHomeDir + "&& npm install --prefix " + '"' + InstallDir + '"' + "    jac459/metadriver'"
    print(DoNPMCMD)
    Response = subprocess.call(DoNPMCMD,shell=True)
    if Response == 0:
       fp =  open('BackgroundOutput.txt')
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

    OriginalUsername = os.environ['SUDO_USER']
    DoThis = "getent passwd '" + OriginalUsername + "'  | cut -d: -f3,4,6 >BackgroundOutput.txt"
    Response = subprocess.call(DoThis,shell=True)
    if Response == 0:
       fp =  open('BackgroundOutput.txt')
       LineIn = fp.readline()
       Fields = LineIn.split(':')
       OriginalUID     = Fields[0]
       OriginalGID     = Fields[1]
       OriginalHomeDir = Fields[2].strip('\n') 
       fp.close()
    else:
       print("Fatal error ocurred  when accessing properties of original userid",OriginalUsername)
       sys.exit(12)
    PackageCache  = apt.cache.Cache() 
    PackageCache.update()

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



