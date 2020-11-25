README.MD

NOTE!!!!!!!! WORK IN PROGRESS, THE CONTENT WAS INITIALLY DEFINED BUT NOT REVIEWED YET !!!!!!!!!!!!!!!!!!!!NOTE
USE AT YOUR OWN RISK AT THIS MOMENT

This README.MD file describes the work that has been done by the Telegram community "FindingNEEO" which has one global objective:
Make certain that the original NEEO-remote is still useable after NEEO/C4 shuts down their cloud-infrastructure.

# Key informations about the future of neeo
## Why is beginning of 2021 an important date for neeo users?
### Neeo and Control4
As you may or may not know, the company which created your neeo remote has been acquired by another company, Control4.
Control4 will NOT use neeo the way we do today and therefore the neeo remote product as we know it, is discontinued.
#### User impact 1
Since the control4 acquisition has happened, the support given by the company has already strongly declined and no more new devices are supported or improved since Q1 2019.
#### User impact 2
In Q1 2021, control4 will stop to provide the on-line services it currently provides:
That means that if you purchase a new device, even if this device was supported by neeo, you won't be able to add it anymore.
Also the TV channels list won't be updated anymore.


Various projects are running that will support this goal:
1) The Neeo Brain has been patched so that root-login to it now is possibly allowing modifications to it.  
2) The Metadriver is developed to support easier development of actual device-drivers.
3) Knowledge is continuously exchanged between the members.

Following is a short explanation of the projects mentioned above.

1) Patching of the Neeo Brain device.
Patching of the Neeo Brain started out just for fun: would it be possible to login to the device and see if we can modify it to more suit our needs.
A clever guy succeeded quite easily (according to himself) and created a way for everybody to apply this patch to their own device. 
Though this patch introduces very powerful access to the NEEO device, its use is currently limited to these areas as far as we know:
A) Run custom device drivers on the Brain itself.
B) Access to the Brain's filesystem so that backups can be made without the cloud.
C) Still in progress, but firmware is being prepared that already contains a (large) suite of drivers, ready to be used out of the box.

Area A) now allows to run custom device drivers on the Brain itself, where we needed extra hardware before. 
This extra hardware was normally a Raspberry PI, or a virtualized Linux system.
The Brain's hardware (based on an Allwinner A20 cpu) is complex but not really powerful, but since most custom drivers don't need many resources, it's a nice way to reduce extra hardware. (By the way, the remote runs on an STM32F429)

Area B) allows for backing up of the settings and installed custom drivers.

2) The Metadriver is currently the project drawing thew most attention.
It is a privately developed Meta driver that supports easy development of custom drivers; hence the name "Meta".. 
Standalone, the Metadriver doesn't deliver any functionality, but it provides an environment that greatly supports development with minimal code.
If you have API-documentation of the device that you want to controll, you only need a little knowledge of programming to create your own driver. 
Currently, custom drivers using the Metadriver are: HUE, Yamaha, Roon, .......

3) We have a diverse member base, with many members knowledgable of IT, some without any technical experience and die-hard Linux and Javascript-developers.
The current communication vehicle is a Telegram group, but we are looking into alternatives like Github, Wordpress etc.

After this introduction, the questions most found will be answered (FAQ).

FAQ
Q. Why should I be interested in these developments? 
A. NEEO/Control4 will shutdown the Cloud infrastructure that is used for installing new device support on your remote AND for recovering from logical damage to your remote (corrupted firmware / filesystem).

Q. When will NEEO/Control4 shutdown the cloud infrastructure?
A. The latest information is that they will shutdown Q1/2021

Q. What's the benefit from rooting my Brain?
A. See the text above, starting with "1) Patching of the Neeo Brain device."

Q. Will rooting my device void my warranty? 
A. Technically yes, but you should consider how long and valuable that warranty is: if you do nothing, your device will soon not be able to be used for new equipment that you purchase.

Q. I am afraid of patching my device, isn't it dangerous?
A. Not really. The community now contains over 120 members, many of them have rooted their device without any problems.  

Q. How can I root my device? 
A. Just go over to https://builder.dontvacuum.me/neeo.html and fill in the fields there. Shortly after you sent in the information, you will receive an email with explanation, links to images and a key that you should use

Q. When is the best moment to root the device?
A. Though you can root the device at any time, regardless of the situation with the NEEO cloud, it is advised to root your device soon; or at least request the patched firmware and save that for later.
The rooting solution is currently hosted on private infrastructure though we are looking into migrating this to a commercial and share infratructure.

Q. Is my remote backuped now when I do not root it?
A. Currently it is backed up through NEEO cloud. But this will end Q1/2021. 

Q. Is my remote backuped when I root it?
A. It will still be backed up through NEEO's cloud till Q1/2021, but you should now plan on making these backups yourself. See above "B) Access to the Brain's filesystem so that backups can be made without the cloud.".

Q. How can I backup my device myself?
A. On a rooted device, you can login to the brain and backup custom drivers and setting with the following command:
 XXXXXXXXXXXXXXXXXXXXXXX needs to be filled in XXXXXXXXXXXXXXXXXXX
 
Q. Can I make custom drivers myself?
A. Yes you can. You need to understand a bit of Javascript (look at other examples and learn from them) and you need to know how the device that you want the NEEO remote to be controlled, CAN be controlled.\
   See TUTORIALS.MD for further explanation.
    
Q. I'm a N00B in this area, what can I do with "a rooted NEEO Brain"?
A. There's work in progress on custom firmware that will include a (large) suite of custom drivers, supporting many devices: NEEO, HUE, Yamaha, Roon etc.

Q. I already have custom drivers running on my own hardware (Raspberry pi, virtual Linux etc.)
A. That is still a viable solution! You do not need to root your brain per se to run custom drivers. 

Q. Do I need to root my Brain to run the Metadriver?
A. No, you can also run it on additional hardware yourself, like a Raspberry Pi.

Q. I see a new firmware from NEEO is available, can I install that and then root my Brain again?
A. Not directly! A firmware update needs to be checked before it can be patched. Check the Telegram community, they are probably already aware of it.   

Q. Can I run the rooted Brain on a virtualised system?
A. This should be possible, but hasn't really been pursued. Current experience shows no benefit of such a (more powerful) solution: custom drivers work very well on the Brain's rooted hardware.
  
Q. Can I replace the battery of my remote?
A. Yes you can. A perfect, but expensive replacement is this one: http://www.honcell.com/products/models/id/2043.html. 
But, since this is a standard LiPo battery with specifications: 3 leads 3.7V 1000Mah 383759 (the latter being the dimensions), you can find similar batteries on ebay and aliexpress (just use the specifications to search for). 
The only problem you might have when buying them, is that the NEEO-remote has a battery-connector and that most batteries only come with 3 leads, requiring some soldering.

Q. What means "A custom device driver"? 
A. You need a driver for each type of device you want to control by your NEEO remote. The NEEO-company developed drivers for many devices and you copuld ask them to support additional ones.
When the NEEO-company was purchased by Control4, development was more or less halted, so officially, you cannot control equipment that wasn't developed by NEEO.
However, it IS possible to add support for a device through code making a driver that wasn't provided by the NEEO-company, these are known as "Custom device drivers".

Q. I do not want a driver, I want my NEEO just to support a piece of equipment!
A. Every piece of equipment that is controlled by your NEEO remote needs a driver, to "drive that type of device/equipment".  

Q. What's the talk about "the NEW C4-remote versus the classic NEEO? They are both NEEO, right?
A. When Control4 bought the NEEO-company, they stated that the N˜EEO-remote that came from NEEO (we call it the classic NEEO Remote) would no longer be sold.
Shortly after that, Control4 announced "their NEEO remote", which is often called NEEO-C4, NEEO-Control4 or YIO. It's a totally different device.

Q. Should I forget about my NEEOremote and buy a C4-NEEO (YIO)?
A. You could, but the YIO is much more expensive and has a totally locked down firmware. If you want additional equipment to be supported, it has top be developed by Control4 which cost a lot of money again.

Q. Can we reflash the Brain and Remote so that it will become "the new C4-NEEO"?
A. Probably not. Control4 probably uses (slightly) different hardware. It was never the intention of this community to convert the classic NEEO-remote to a C4 as this would probably violate Control4-copyrights.    

Q. Can I send my own IR-codes via the Brain?
A. Yes you can. You need to have the IR-code in global cache format. This is an 

example:
http://192.168.1.2:3000/irblaster/send_ir?code=sendir,1:1,1,38000,3,1,152,155,19,78,19,78,19,78,19,78,19,39,19,39,19,78,19,39,19,78,19,39,19,78,19,39,19,39,19,41,18,39,19,39,19,78,19,78,19,39,19,78,19,40,19,78,19,39,19,78,19,330

Q. My remote keeps saying "Reconnecting" with a spoinning circle, what can I do?
A. The remote probably has problems connecting to your wifi. DO the following:
1. Hold the power button on the NEEO Remote for 15 seconds
2. Wait a few seconds
3. Press the power & mute button simultaneously for a few seconds
4. You should see the option for recovery, follow the on-screen steps.
You will now getbthe option to go into recovery mode (by pressing the menu button).
The remote will do some initalization, then tells you that it needs your help, and to place the remote close to the brain.
Press the black plastic cover on the Brain for 8 seconds, then the remotre will pair with the Brain and receive the new wifi-credentials. That should help you.
