If your have installed nodered earlier, but through the "vendor supplied script", you've noticed that the installer chokes on nodered.
You'll also see that both nodejs and npm that are found on your system are my=uch higer than required.

In essence, the script adds some repositories to apt that include "non-official packages"...

Although installer.py is purely meant to run on a freshly installed raspbian, we've noticed that many people try to run it on "more customised systems".
For the installer (install.py) to work properly, you have to remove these packages and remove the "non-official repositories.

Please note: this procedure is tested, but without any warranty!!!!! 
   
This is how you can get rid of the "non offical packages":

sudo mv /etc/apt/sources.list.d/nodesource.list ~
sudo touch /etc/apt/sources.list.d/nodesource.list
sudo apt update
sudo apt remove nodejs
sudo apt remove npm
sudo apt purge npm
sudo apt remove npm/stable
sudo apt purge npm/stable
sudo apt update
sudo apt install nodejs
sudo apt install npm
sudo apt remove nodered
sudo apt purge nodered

That should do it, you now have the correct version of the required packages
AND you can  now install nodered through the installer (install.py).
I need to check the autostartup of the older nodered, bt this is a good start. 