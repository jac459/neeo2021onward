
### Below are all the commands that need to run on your freshly rooted brain.

##Installation of metadriver (and prerequisites) on NEEO-Brain 
login through ssh -i <key-ending with id_rsa> -l neeo

Then execute these commands:

  curl -k https://raw.githubusercontent.com/jac459/neeo2021onward/main/Meta%20running%20in%20Brain/installmeta.sh -o /tmp/installmeta.sh && sh /tmp/installmeta.sh 

  ( for the Beta-version, use these commands:
  curl -k https://raw.githubusercontent.com/jac459/neeo2021onward/Beta-2021-01%233/Meta%20running%20in%20Brain/installBeta.sh -o /tmp/installBeta.sh && sh /tmp/installBeta.sh 

## What happens here?
1) This will download a small (driver-) program from github to a writable temporary folder.
2) This executes the driver program.
   The program first prepares the Brain, copies itself to the user's homedirectory (/home/neeo), then it
   downloads the actual installer from github and runs it.

For future runs of the installer, you can simply run the same driver program from user neeo's homedirectory like this:
    sh ~/installmeta.sh without the need to manually grab any code from internet, thats all taken care of by the driver.

## We've noticed that some official sites (mirrors) hosting the necessary archlinux-packages are a bitinstable (overloaded).
You will notice this with errors like these 
"error: failed retrieving file 'krb5-1.18.2-1-armv7h.pkg.tar.xz' from mirror.archlinuxarm.org : The requested URL returned error: 502""
Key in here is the error 502......  This is something we cannot solve as these aren't our servers, just rerun the installer the same way and it will pick up where it stopped.

The installer determines if it needs to restart a previously interrupted run. It can be run again and again without problems, it detects itself if something needs to be updated/installed. 
Just run it. It runs till Stage Z, signalling that it has ran till completion. If it finds errors it cannot resolve by itself, it will abort with some (hopefully) helpful messages.
Look at the message, if it instructs you to run a command following that, otherwise you can ask for help in the support page on discord.
If you receive a message (more or less) similar as this:
chmod: cannot access '/steady/neeo-custom/.pm2   <etc .etc .etc>
You can ignore it. It has  no effect on neeo or meta and will be fixed in a next version of installer-backend ** Fixed in installer V1.7**). 

If all went well, you should now be able to see node-red as a webpage server from your brain: <IP-address Brain>:1880 in your browser


## All of the meta-services (mosquitto, node-red and metadriver) are started under a user-version of PM2, leaving NEEO's processes alone. 
Most users will only be interested in the new user-services, so we have added assignment of PM2_HOME to the user-directory for PM2 (in .bashrc). 
You can check the status of these user services with this command:
pm2 list <-- this gives you the status of all 3 user-services, they need to have status online
If you want to see the output of meta, use this command:
pm2 log meta
This shows you a running output of the output from meta; any new message will show there until you hit cntrl-c

Restarting meta:
pm2 restart meta

Please note that all commands in this textfile are CASE-sensitive!!! Type them in exactly as they are presentes here. 

## Parameters supported

The following parameters can be used to control behavior of the installer:  
  ** --help **            display this help and exits
  ** --reset **           Start installer from scratch; this is handy if installer seems stuck, can always be used
  ** --FreeSpace **     Removes logfiles from /steady filesystem to free up space. 
  ** --meta-only **       Only pull a new version of metadriver, and restart it
  ** --get-versions **    Output current version of meta and the last available one

Normally, you should not use any parameter. It is adviced to not use --meta_only, but just start installer from the beginning.
This way, you are sure that all requirements for .meta are fulfilled.
