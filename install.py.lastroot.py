
import sys
import os
import os.path
import apt
import subprocess
import re
import shutil, glob
import datetime
import time
import argparse
import json

InstalledCheckingVersion = 10
InstalledAndOK = 0
InstalledButNotOK = 90
NotInst = 99
PackageTypeUnknown = 0
PackageTypeAPT = 1
PackageTypeNPM = 2
PackageTypeManual = 3
MyPackages =  [
              {"name":"git","type":PackageTypeAPT,"reqvers": "2.20.1","status":NotInst,"Inst_Vers":"","CMDLine":"git --version","loc":"", "PKGParm":"","PKGParm2":"","PackageUSER":"","PackageUSER":"","mydep":{},"startcmd":{}},
              {"name":"nodejs","type":PackageTypeAPT,"reqvers": "10.21.0","status":NotInst,"Inst_Vers":"", "CMDLine": "nodejs --version","loc":"", "PKGParm":"","PKGParm2":"","PackageUSER":"","mydep":{},"startcmd":{}},
              {"name":"npm","type":PackageTypeAPT,"reqvers": "5.8.0","status":NotInst,"Inst_Vers":"", "CMDLine": "npm --version","loc":"", "PKGParm":"","PKGParm2":"","PackageUSER":"","mydep":{},"startcmd":{}},
              {"name":"pm2","type":PackageTypeNPM,"reqvers": "","status":NotInst,"Inst_Vers":"", "CMDLine": "node-red list","phaserequired":1,"loc": "", "PKGParm":"npm install -g pm2 ","PKGParm2":"","PackageUSER":"root","mydep":{"npm"},"startcmd":{"pm2 save","pm2 startup"}},
              {"name":"nodered","type":PackageTypeAPT,"reqvers": "","status":NotInst,"Inst_Vers":"", "CMDLine": "node-red list","phaserequired":1,"loc": "", "PKGParm":"","PKGParm2":"","PackageUSER":"","mydep":{"nodejs","npm"},"startcmd":{"pm2 start /usr/bin/node-red -f --node-args='--max-old-space-size=128' --  -v"}},
              {"name":"mosquitto","type":PackageTypeAPT,"reqvers": "","status":NotInst,"Inst_Vers":"", "CMDLine": "node-red list","phaserequired":1,"loc": "", "PKGParm":"","PKGParm2":"","PackageUSER":"","mydep":{},"startcmd":{"systemctl stop mosquitto","systemctl disable mosquitto","pm2 start mosquitto -f -- -v  "}},
              {"name":"meta","type":PackageTypeNPM,"reqvers": "","status":NotInst,"Inst_Vers":"", "CMDLine": "node-red list","phaserequired":1,"loc": ".meta", "PKGParm":"npm install ","PKGParm2":"jac459/metadriver","PackageUSER":"","mydep":{"npm","git","pm2"},"startcmd":{"pm2 start .meta/node_modules/@jac459/metadriver/meta.js -f" }}
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

def HandleErrorShowOutput(MyError,GiveError,FileName):
    DoWhip = "whiptail --yesno '"+GiveError+"\nClick ok to see output containing the error' --title '"+MyError+"' 10 80"
    if subprocess.call(DoWhip,shell=True)==False: 
       DoWhip = "whiptail --textbox --scrolltext  '"+FileName+"'  40 80"
       subprocess.call(DoWhip,shell=True)

def CheckDirectory(TestDir):

    if os.path.exists(TestDir) and os.path.isdir(TestDir):
       return 1
    else:
       return 0

def GetMyPackageFields(GetPKG):

    for pkg in MyPackages:
        if pkg['name'] == GetPKG:
           return pkg

    DoWhip = "whiptail --title 'Example Dialog' --msgbox 'LOGIC-ERROR! Incorrect package requested "+ GetPKG +  "' 8 78"
    subprocess.call(DoWhip,shell=True)
    return ""

def CheckAPTPackageInstalled(pkg):

    try:
       PkgC = PackageCache[pkg['name']]
    except KeyError:
       PackageCache.close()
       return 0
    if not PkgC.is_installed:
       return 0

    try: 
         Installed_version = PkgC.installed.version
    except AttributeError:
         Installed_version = PkgC.Inst_Vers

    pkg['status'] = InstalledCheckingVersion           #Signal package is installed
    VersionOnly = re.match(r'^[0-9.:]*',Installed_version)
    i = VersionOnly[0].find(':')
    if i != -1:
       Installed=VersionOnly[0][i+1:]
    else:
       Installed=VersionOnly[0]
    pkg['Inst_Vers'] = Installed.strip()

    return 1

def CheckNPMPackageInstalled(pkg):

    if " -g " in pkg['PKGParm']:
       doglob = " -g "
    else:
       doglob = ""
       if CheckDirectory(OriginalHomeDir+"/"+pkg['loc']):        #is this an existing directory?
          os.chdir(OriginalHomeDir+"/"+pkg['loc'])               # yes, switch to the directory
       else:
          return 0

    NPMListCMD = "npm list --no-color "+ doglob+" 2>/dev/null| grep -i " + pkg['name']+"@ 1>" + LogDir + "/BackgroundNPMList.txt "
    Response = subprocess.call(NPMListCMD,shell=True)
    if Response == 0:  # success for npm list
       fp =  open(LogDir + '/BackgroundNPMList.txt')
       Result = fp.readline()
       fp.close()
       pkg['status'] = InstalledCheckingVersion
       MyVersion = Result.split('@')
       pkg['Inst_Vers']  = MyVersion[1].strip()
       return 1
    else:
       AllDepsOK = False
       return 0

def TestThisPackage_OK(pkg):

       if pkg['status'] == InstalledAndOK:
          return

       pkg['status'] = NotInst
       if pkg['type']  == PackageTypeAPT:
          Installed = CheckAPTPackageInstalled(pkg)
       elif pkg['type'] == PackageTypeNPM:
          Installed = CheckNPMPackageInstalled(pkg)

       if not Installed:
          AllDepsOK = False
          return

       if  pkg['Inst_Vers'] < pkg['reqvers'].strip():
           pkg['status'] = InstalledButNotOK                #Signal package is installed, but version is too low
           AllDepsOK = False
       else:
           pkg['status'] = InstalledAndOK                   #Signal package is installed with correct version

def TestPackages_OK(Silent = False):
    global AllDepsOK
    global CheckedDependenciesAlready
    CheckedDependenciesAlready = True
    AllDepsOK = True
    ChangedDir = False                                          # assume we'll stay in the current directory
    if not Silent:
       print("")
       print("Checking installation status of all packages, this may take a while")
       print("")

    PackageCache.open()

    for pkg in MyPackages:
        TestThisPackage_OK(pkg)

    os.chdir(CurrDir)                                       #Return to the original directory , as we may have changed while testing NPM-packages
    PackageCache.close()
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

    if CheckedDependenciesAlready == False:
       DoWhip = "whiptail --title 'Raspberry pi configurator for NEEO' --menu '"
       for pkg in MyPackages:
                  Content = "\nRequired: " + pkg['name'] + " " + pkg['reqvers']
                  Content = Content.ljust(25, ' ')
                  if  pkg['type'] ==  PackageTypeAPT:
                      Content += " APT "
                  elif  pkg['type'] ==  PackageTypeNPM:
                      Content += " NPM "
                  Content +=  " Not checked yet"
                  DoWhip +=  Content
       DoWhip += "\n\nSetup Options' 45 70 10 " + \
              " --cancel-button Finish --ok-button Select  \
             '1 Check' 'Check packages'    \
             '7 examples' 'Refresh examples in Activated directory'  \
             'X Exit' 'Exit the program'  2>" + LogDir + "/Mainmenu.txt"
    else:
       DoWhip = "whiptail --title 'Raspberry pi configurator for NEEO' --menu  'Package status:\n\n"
       for pkg in MyPackages:
                  Content = "Required: " + pkg['name'] + " " + pkg['reqvers']
                  Content = Content.ljust(25, ' ')
                  if  pkg['type'] ==  PackageTypeAPT:
                      Content += " APT "
                  elif  pkg['type'] ==  PackageTypeNPM:
                      Content += " NPM "
                  if  pkg['status']  == InstalledAndOK:
                      Content += "Found:  "+ pkg['Inst_Vers']  + " --> OK\n"
                  elif  pkg['status'] == InstalledButNotOK:
                      Content += "Found:  " + pkg['Inst_Vers'] + " --> Version is too low\n"
                  else:
                      Content +=  "Not found --> Need to install\n"
                  DoWhip +=  Content
       DoWhip +=   "Setup options\n' 45 70 15 " + \
             " --cancel-button Finish --ok-button Select "\
             "'1 Check' 'Check packages installation status'   \
             '2 Install' 'Install missing packages' \
             '7 examples' 'Refresh examples in Activated directory'  \
             'S Startup' 'Create autostart for all installed packages'  \
             '8 Simple' 'Simply install all of the above'  \
             'X Exit' 'Exit the program'"
       DoWhip += " 2>" + LogDir + "/Mainmenu.txt"  
#             'n Startup' 'Create autostart for all nodered'  \
    Response = subprocess.call(DoWhip,shell=True)
    if Response == 0:
       fp =  open(LogDir + '/Mainmenu.txt')
       Choice = fp.readline()
       fp.close()
       return  Choice
    else:
       print("User cancelled the dialog")
       Do_Exit(0)
       return "@"  # signal somethiong is wrong with the main menu

def ShowPackageStatus():

    DoWhip = "whiptail --title 'Overview status of dependencies'  --msgbox "
    for pkg in MyPackages:
       Content = "' Required: " + pkg['name'] + " " + pkg['reqvers']
       Content = Content.ljust(35, ' ')
       if pkg['type'] ==  PackageTypeAPT:
          Content += " APT "
       elif  pkg['type'] ==  PackageTypeNPM:
          Content += " NPM "
       if  pkg['status']  == InstalledAndOK:
           Content += "Found:  "+ pkg['Inst_Vers']  + " --> OK\n'"
       elif  pkg['status'] == InstalledButNotOK:
           Content += "Found:  " + pkg['Inst_Vers'] + " --> Version is too low\n'"
       else:
           Content +=  "Not found --> Need to install\n'"
       DoWhip +=  Content
    DoWhip +=  " 25 80 70 "
    subprocess.call(DoWhip,shell=True)

def Do_Install_dependencies(Silent):

    if Silent:
       DoThis = ""
       for pkg in MyPackages:
           DoThis  = DoThis + '"' +  pkg['name'] + '" '
    else:
       DoThis = SelectPackageToInstall()

    InstalledSomething = False
    if type(DoThis) == type(None) or DoThis.strip() == "":
       return

    for ThisPackage in DoThis.split('"'):
        if ThisPackage.strip() != "":
           pkg = GetMyPackageFields(ThisPackage.strip())        # lookup extra parms, now we only have the name of the pac kage, not the actual array
           InstallPackage(pkg)                                  # install the package
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

def InstallPackageAPT(pkg):
    global PackageCache

    APTAddPackageCMD = "apt install -y "+ pkg['name'] + " 1>" + LogDir + "/BackgroundAPTInstall" + pkg['name'] + ".txt"
    print(APTAddPackageCMD)
    Response = subprocess.call(APTAddPackageCMD,shell=True)
    if Response:
       HandleErrorShowOutput("Error APT-install","Could not install package "+ pkg['name'], LogDir + "/BackgroundAPTInstall" + pkg['name'] + ".txt" )
       print("Done apt install",Result)
    else:
       PackageCache.close()  
       PackageCache  = apt.cache.Cache()
       PackageCache.open()
       TestThisPackage_OK(pkg)

    return Response 

def InstallPackageNPM(pkg):

       MyLoc = ""
       if pkg['loc'] != "":              # Do we need to insyall it on a specific location?
          print("Checking custom location now",pkg['loc'])
          InstallDir = OriginalHomeDir+"/"+pkg['loc']
          MyLoc = " --prefix " + '"' + InstallDir + '"' + " "
          if os.path.isdir(InstallDir) == False:
             DoMKDirCMD = MySudo +  "mkdir  "  + '"' + InstallDir + '"' + " 2>"+ LogDir + "/BackgroundMkdir.txt'"
             Response = subprocess.call(DoMKDirCMD,shell=True)
             if Response:
                print("Fatal error ocurred  when creating directory for  package:",pkg['name'],InstallDir)
                Do_Exit(12)

       if pkg['PackageUSER'] != "":
          APTNPMPackageCMD =  pkg['PKGParm'] +  " "  +  MyLoc  + " " + pkg['PKGParm2'] + "  2>" + LogDir + "/BackgroundNPMInstall"+ pkg['name'] + ".txt"
       else:
          APTNPMPackageCMD = MySudo + "export HOME="+OriginalHomeDir + "&& " +  pkg['PKGParm'] +  " --no-color "  +  MyLoc  + " " + pkg['PKGParm2'] + "  2>" + LogDir + "/BackgroundNPMInstall"+ pkg['name'] + ".txt'"

       print(APTNPMPackageCMD)
       Response = subprocess.call(APTNPMPackageCMD,shell=True)

       if Response:
          HandleErrorShowOutput("Error NPM-install","Could not install package "+ pkg['name'], LogDir + "/BackgroundNPMInstall" + pkg['name'] + ".txt" )
       TestThisPackage_OK(pkg)                     # Refresh status of this package 
       return Response

def InstallPackage(pkg):
    global DidAPTUpdate
    InstalledSomething = False
    if DidAPTUpdate == False:
       DidAPTUpdate = True
       DoAPTUpdate()

    if pkg['mydep']!= "":
       for dep in pkg['mydep']:
           FoundDep = False
           for Testpkg in MyPackages: 
               if  Testpkg['name'] == dep:
                   if Testpkg['status'] != InstalledAndOK:
                      DoWhip = "whiptail --title 'Missing dependencies'  --msgbox 'Not all packages that are required for "+  pkg['name'] + " are installed.\n\n\nMissing:" +  dep  + "'  25 80 70 "
                      subprocess.call(DoWhip,shell=True)
                      return
                   else: 
                      FoundDep = True
                      break 
           if not FoundDep:
              DoWhip = "whiptail --title 'Missing  dependencies'  --msgbox '"+ pkg['name'] + "Has an unknown package defined as dependency:\n\n\n:" +  dep  + "'  25 80 70 "
              subprocess.call(DoWhip,shell=True)
              return

    if pkg['type'] == PackageTypeAPT:   #Is this an APT-package?
       Response =  InstallPackageAPT(pkg)
    elif pkg['type'] == PackageTypeNPM:   #Is this an NPM-package?
       Response =  InstallPackageNPM(pkg)

def SelectPackageToInstall():

    DoWhip = "whiptail --title 'Install dependencies'   --checklist  'Select packages you want to be installed'  25 78 15 "
    MyIndex = 0
    for pkg in MyPackages:
       if  pkg['status']  != InstalledAndOK:
           Content = "'"+ pkg['name'] + "' '" + pkg['name'] + " " + pkg['reqvers']  +  "' "
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

def Do_Check_dependencies(Silent):
    TestPackages_OK()
    #if not Silent:
    #   ShowPackageStatus()

def Do_ListDependencies(Silent):

    TestPackages_OK(Silent)

    data = {}
    for pkg in MyPackages:
        data[pkg['name']] = []
        data[pkg['name']].insert(1, { 'name': pkg['name']})
        data[pkg['name']].insert(0, { 'status': str(pkg['status']) })
        data[pkg['name']].insert(0, { 'dependency': str(pkg['mydep']) })
        data[pkg['name']].insert(0, { 'Inst_Vers': pkg['Inst_Vers']  })

    print(json.dumps(data,sort_keys=True, indent=4, separators=(',', ': ')))

def HandleChoice(i,Silent=False):
    switcher = {
            "1": lambda: Do_Check_dependencies(Silent),
            "2": lambda: Do_Install_dependencies(Silent),
            "7": lambda: Do_Refresh_NEEOCustom(Silent),
            "8": lambda: Do_It_All(Silent),
            "s": lambda: Do_SetupStartups(Silent),
            "S": lambda: Do_SetupStartups(Silent),
#            "n": lambda: Do_SetupServiceNodeRed(Silent),
#            "N": lambda: Do_SetupServiceNodeRed(Silent),
            "L": lambda: Do_ListDependencies(Silent),
            "x": lambda: Do_Exit(0),
            "X": lambda: Do_Exit(0)
        }
    func = switcher.get(i[0], lambda: 'Invalid')
    func()

def Do_SetupStartups(Silent):
    #i = 0 
    for pkg in MyPackages:
        if pkg['status'] == InstalledAndOk  and len(pkg['startcmd']) > 0:
           if not Silent:
              print("Setting up startup for",pkg['name'],": ",pkg['startcmd'])
    #       i=i+1 
    #       PipeFile =  LogDir + "/BackgroundSetupStart_"+ pkg['name'] + "#" + str(i)+".txt"
           PipeFile =  LogDir + "/BackgroundSetupStart_"+ pkg['name'] + ".txt"
           if  os.path.isfile(PipeFile):
               os.remove(PipeFile)                                       # remove outputfile
           for StartupCMD in pkg['startcmd']:
               DoMKDirCMD = StartupCMD +  " 1>>"+ PipeFile
    #           if pkg['PackageUSER'] != "root" and StartupCMD[0:9] != "systemctl":
    #               DoMKDirCMD = MySudo + "export HOME="+OriginalHomeDir + "&& "+ DoMKDirCMD +"'"
                if not Silent:
                   print(DoMKDirCMD)
               Response = subprocess.call(DoMKDirCMD,shell=True)
               if Response:
                  print("Fatal error ocurred in Startupcmd",StartupCMD,"for  package:",pkg['name'],PipeFile)
                  Do_Exit(12)

def Do_SetupServiceNodeRed():
    DONodeRedStart = "systemctl enable nodered.service"
    print(DONodeRedStart)
    Response = subprocess.call(DONodeRedStart,shell=True)
    if Response == 0:
       print("That's it, NodeRed is configured to autostart")
    else:
       print("Fatal error ocurred while setting up autostart NodeRed")
       Do_Exit(12)
    DONodeRedStart = "systemctl start  nodered.service"
    Response = subprocess.call(DONodeRedStart,shell=True)
    print(DONodeRedStart)

def Do_RenameDir(srcDir,destDir):
    try:
        os.rename(srcDir,destDir)
    except EnvironmentError:
       DoError = "whiptail --title 'SAVE-Dialog' --yesno  'Error renaming old archive dikrecxtory' 8 78 "
       subprocess.call(DoError,shell=True)
       Do_Exit(12)

def Do_GetMetaLibrariesfromGithub():

    UniqueName = datetime.datetime.now().strftime("%Y-%m%d %H.%M.%S")                          # prepare to geta unique archive-name for directories
    GitDir = OriginalHomeDir+"/GIT "+ UniqueName
    os.mkdir(GitDir, mode=0o755 )

    DoGetGit = "git clone 'https://github.com/jac459/metadriver' -b 'master' '" + GitDir +"' 2>"+  LogDir + "/BackgroundGitCone.txt"
    print(DoGetGit)
    Response = subprocess.call(DoGetGit,shell=True)
    if Response:
       print("Seems like an error has occured in GIT clone")
       HandleErrorShowOutput("Error", "Error obtaining new Activated and deactivate directory!!\nYour saved activated and deactivated directories will be restore to metadriver-directory",LogDir + "/BackgroundGitCone.txt" )
       return ""
    return GitDir+"/"

def Do_Copy(src, dst, symlinks=False, ignore=None):
    print("Do_Copy %s %s",src,dst)
    if not os.path.exists(dst):
        os.makedirs(dst)
    for item in os.listdir(src):
        s = os.path.join(src, item)
        d = os.path.join(dst, item)
        if os.path.isdir(s):
            copytree(s, d, symlinks, ignore)
        else:
            if not os.path.exists(d) or os.stat(s).st_mtime - os.stat(d).st_mtime > 1:
                shutil.copy2(s, d)

def Do_MoveNoReplace(InSrcDir,InDestDir):

    print("Do_MoveNoReplace",InSrcDir, InDestDir)
    for src_dir, dirs, files in os.walk(InSrcDir):
       dst_dir = src_dir.replace(InSrcDir, InDestDir, 1)
       if not os.path.exists(dst_dir):
           os.makedirs(dst_dir)
       for file_ in files:
           src_file = os.path.join(src_dir, file_)
           dst_file = os.path.join(dst_dir, file_)
           if os.path.exists(dst_file):
               #  Same file alreadcy in DestDir, don't move it.
              continue
           shutil.move(src_file, dst_dir)
 
def Do_SaveHouseKeepingThisDir(SrcDir,TypeDir,DestDir):

    print("Do_SaveThisDir",SrcDir,TypeDir,DestDir)
    UniqueName = datetime.datetime.now().strftime("%Y-%m%d %H.%M.%S")                          # prepare to geta unique archive-name for directories
    for file in os.listdir(SrcDir+TypeDir):                       # Do we even have a meta0directory with this subdir (TypeDir: activated or deactivated)
                                                                  # Yes, now Check to see if there is an activated directory in the meta-directory.MetaActivatedDir
       print(SrcDir,"Has folder",TypeDir,"So we need the cleanup")
       if os.path.isdir(DestDir):                                 # Check to see if Save-directory already exists (~/SaveMetaInstall)
           print(DestDir,"already exists, no need top make it")
           if os.path.isdir(DestDir+TypeDir):                    # Yes, it exists... do we have this directory ( parm TypDir = "activated" or "deactivated") in  there?
              print("But it already has directory: ",TypeDir,"We'll rename it") 
              Do_RenameDir(DestDir+TypeDir,DestDir+TypeDir+" "+UniqueName)   # rename it to an archive name (~/SaveMetaInstall/archive ttttmmdd : hh:mm:ss)
           print("Rename done")
       else:
           print("Making .#SaveMetaInstall")
           os.mkdir(DestDir, mode=0o755 )
       return 1
    return 0

def Do_SaveHouseKeeping(MetaDir,SaveDir):

    print("SaveHousekeeping",MetaDir,SaveDir)
    Do_SaveHouseKeepingThisDir(MetaDir, "activated",SaveDir)
    Do_SaveHouseKeepingThisDir(MetaDir, "deactivated",SaveDir)


def Do_MoveThisDir(SrcDir,TypeDir,DestDir,ReplaceParm):

    print("Do_MoveThisDir",SrcDir,TypeDir,DestDir,ReplaceParm)
    if ReplaceParm:
       Do_Copy(SrcDir+TypeDir,DestDir+TypeDir)
    else:
       Do_MoveNoReplace(SrcDir+TypeDir,DestDir+TypeDir)

  ####     shutil.rmtree(SrcDir+TypeDir)

def Do_MoveDirs(SrcDir,DestDir,ReplaceParm):

    print("Do_MoveDirs",SrcDir,DestDir)
    Do_MoveThisDir(SrcDir, "activated",DestDir,ReplaceParm)
    Do_MoveThisDir(SrcDir, "deactivated",DestDir,ReplaceParm)

def Do_Refresh_NEEOCustom(Silent):

    global SaveDir 
    print("Do_Refresh_NEEOCustom")
    MetaDir = OriginalHomeDir+"/.meta/node_modules/@jac459/metadriver/"
    SaveDir = OriginalHomeDir+"/.SaveMetaInstall/"

    Do_SaveHouseKeeping(MetaDir,SaveDir)                                # first, some housekeeping on .SaveMetaInstall
    Do_MoveDirs(MetaDir,SaveDir,True)                                   # Now move ALL files from meta to .SaveMetaInstall (True means replace)

    GitDir = Do_GetMetaLibrariesfromGithub()
    if GitDir == "":
        return
    Do_MoveDirs(GitDir,MetaDir,True)                                    # Now move ALL files from meta to .SaveMetaInstall (True means replace
    Do_MoveDirs(SaveDir,MetaDir,False)                                  # Next, move back all files that were saved into the neew Meta-directory, without REPLACING ANYONE  (False)
    shutil.rmtree(GitDir)

def Do_It_All():
    Print("Now just run through all the options.")

def SetAccessRights(ThisDir):

    for root, dirs, files in os.walk(ThisDir):
        for TheDir in dirs:
            os.chown(os.path.join(root, TheDir), OriginalUID,  OriginalGID)
        for file in files:
            os.chown(os.path.join(root, file), OriginalUID,  OriginalGID)
    if os.path.isdir(ThisDir):
       os.chown(ThisDir, OriginalUID,  OriginalGID)

def Do_Exit(RC):                                                        #exit, but first set  logdirectory+fils in it to original user&group

    SetAccessRights(LogDir)                                             #Before we say goodbye, we set accessrights on some folders to or own user
    SetAccessRights(SaveDir) 
    sys.exit(RC)

def DoSomeInit():
    global OriginalUsername
    global OriginalHomeDir
    global OriginalUID
    global OriginalGID
    global PackageCache
    global InstallDir
    global LogDir
    global CurrDir
    global MySudo 
    global SaveDir

    MyUsername = os.environ['USER']
    if MyUsername!='root':
       print("please call this program with elevated rights (sudo xxx)")
       sys.exit(12)                                              # Do_Exit() will notwork, since we do not have variable LOGDIR defined yet.
    OriginalUsername = os.environ['SUDO_USER']

    CheckArgs()                                                  # Let's first check if we have optional arguments passed to us

    DoThis = "getent passwd '" + OriginalUsername + "'  | cut -d: -f3,4,6 >BackgroundGetUserProperties.txt"
    Response = subprocess.call(DoThis,shell=True)                #get originalo users homedir, GID en UID from /etc/passwd file
    if Response == 0:
       fp =  open('BackgroundGetUserProperties.txt')
       LineIn = fp.readline()
       Fields = LineIn.split(':')
       OriginalUID     = int(Fields[0])
       OriginalGID     = int(Fields[1])
       OriginalHomeDir = Fields[2].strip('\n')
       fp.close()
    else:
       print("Fatal error ocurred  when accessing properties of original userid",OriginalUsername)
       Do_Exit(12)

    SaveDir = OriginalHomeDir+"/.SaveMetaInstall/"
    CurrDir = os.getcwd()                                        #what's the current directory
    LogDir =  CurrDir +  "/log"
    MySudo =  "su -m "+ OriginalUsername + " -c '"
    if os.path.isdir(LogDir) == False:                           # Check to see if LOG-directory already exists (~/log)
       DoMKDIRLog = MySudo + "mkdir  "+ LogDir + " 2>BackgroundMkdirLog.txt'"   # No, so create it
       print(DoMKDIRLog)
       Response = subprocess.call(DoMKDIRLog,shell=True)
       if Response == 0:
          fp =  open('BackgroundMkdirLog.txt')
          LineIn = fp.readline()
          print(LineIn)
          fp.close()
       else:
          print("Fatal error ocurred  when installing metadriver")
          Do_Exit(12)

    InstallDir = OriginalHomeDir+"/.meta"
    PackageCache  = apt.cache.Cache()

def Do_Silent_Commands():

   if MyArgs.Install:
      HandleChoice(1,True)

   if MyArgs.InstallRefresh:
      HandleChoice(1,True) 

   if  MyArgs.List:
      HandleChoice("L",True) 

def CheckArgs():

    global MyArgs       
    parser = argparse.ArgumentParser(description='NEEO custom devicedriver host builder')
    parser.add_argument(
        '--Install',
        action='store_true',
        help='No menu will be displayed, just executes functions 1, 2 and S, resulting in a fully installed host, but without refreshing the "activated" and "deactivated" directories'
    )
    parser.add_argument(
        '--InstallRefresh',
        action='store_true',
        help='No menu will be displayed, just executes functions 1, 2 and S, resulting in a fully installed host, but without refreshing the "activated" and "deactivated" directories'
    )
    parser.add_argument(
        '--List',
        action='store_true',
        help='No menu will be displayed, just executes functions 7. This will  return an overview of all required packages with their install-status and -version (format: JSON).'
    )

    MyArgs = parser.parse_args()

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

   if MyArgs.Install or MyArgs.InstallRefresh  or MyArgs.List :
      Do_Silent_Commands()
      GoOn = False


   while GoOn == True:
       MenuChoice = DisplayPrimaryMenu()
       if MenuChoice == "@":                        # fatal error while displaying main menu
           GoOn = False
           continue
       else:
           HandleChoice(MenuChoice)


