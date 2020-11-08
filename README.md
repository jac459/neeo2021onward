README.MD

NOTE!!!!!!!! WORK IN PROGRESS, THE CONTENT WAS INITIALLY DEFINED BUT NJOT REVIEWEED YET !!!!!!!!!!!!!!!!!!!!NOTE
USE AT YOUR OWN RISK AT THIS MOMEN˜T

This READM file describes the work that has been done by the Telegram community "FindingNEEO" which has one global objective:
Make certain that the original NEEO-remote is still useable after NEEO/C4 shuts down their cloud-infrastructure.

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
The Brain's hardware (based on an Allwinner A20 cpu) is complex but not really powerful, but since most custom drivers don't need many resources, it's a nice way to reduce extra hardware.

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

Q. Can I run the rooted Brain on a virtualised system?
A. This should be possible, but hasn't really been pursued. Current experience shows no benefit of such a (more powerful) solution: custom drivers work very well on the Brain's rooted hardware.
  
  
  
