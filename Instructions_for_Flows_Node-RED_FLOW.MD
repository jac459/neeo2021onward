This document provides a general description on how to add a flow to Node-RED, customize and deploy it.

We will assume you are using a pre-configured NEEO eco system on your NEEO-Brain, as delivered by the installmetya.sh script.
This means that all traffic between meta, mosquitto and Node-RED will stay local (IP-address = 127.0.0.1) 

Within this document, we'll be using two distinct type of "nodes" in here:


1) MQTT as the default communication-method with the Metadriver running on the NEEO Brain.
2) Target-nodes which represent the equipment; this could be you TV, AVReceiver, but also a SONOS-device.
We'll use <ip-address Brain> as the IP-address of your brain (don't type the < and > sign).

As an example, in this document we'll use the target "SamsungTV" to refer to our target-nodes; depending on your situation, the name of the node will be different.  

Okay, let's get to work.
In short, when you want to add a flow to Node-TRED, the following actions are required (we'll explain each action separately):

A) Obtain the flow from its original location (usually github) and import it into Node-RED.
B) Add dependencies if needed.
C) Configure flow
D) Deplay (activate) flow


========================================================================================
A) Obtain the flow from its original location (usually github) and import it into Node-RED.
The custom driver SamsungTV2012 sends all of its actions over MQTT (Mosquitto), where a Node-red flow needs to pick them up.
This functionality is included in the flow SamsungTV2012 Flow.json, located in its package at directory "node-red Flow".

You can import this file by copy&paste its content into a new node-red flow, but also by downloading the flow and importing it by selecting the downloaded file on node-red. 

First, open  in your browser the github repository containing the custom driver for your device (in ths example https://github.com/jac45eta-SamsungTV2012) and open the file SamsungTV2012 Flow.json located in directory "node-red Flow". This  will show you the content of the flow.
Important: in the line just above the actual content, you'll see two icons named RAW and BLAME. Click on RAW...
Copy entire content of the raw-window go the clipboard 

Open your browser and goto <ip-address Brain>:1880
This should open the node-red GUI.
In the top of the browser window, you'll see a black line with left the name Node-RED and the logo, while at the right, you'll have 3 horizontal bars. The 3 bars will show a submenu for Node-RED.
Click on the 3-bars/submenu. 
You'll now see the submenu, with the function "import". Click on import.
In the window you can now paste the content of your clipboard.
Important: do not import yet, first click at "import to" the "New flow" button so you do not overwrite any flow that is already opened in Node-RED.
Now click Import.

That's it!

========================================================================================
B) Add dependencies if needed.

Some flows need additional packages (nodes) that deliver specific functionality and are developed by others than the Metadriver-team. 
For SamsungTV2012, we do need such an external node, called "node-red-contrib-samsungTV". 
This extra node can be installed  through the Node-RED submenu we used to start the import of the flow, but this time choose function "Manage palette". 

A dialog name "User settings" will open with 3 tabs at the left. Click the tab "Palette". Thios part of the dialog shows two Tabs at the top: "Nodes" and "Install". 
The Nodes-tab shows all the nodes that are installed. You can see if there's already a line with the extra node we need ("node-red-contrib-samsungTV"), but normally, it should not be there yet.
Now open the Tab-Install. You'll see the search field (magnifying glass with the text "search module"). Type "node-red-contrib-samsungTV" (without quotes) in there.
Once done, you'll see the node with a button to install it. Click on install, confirm you indeed want to install it and wait for the process to complete successfully.
That's it, you now have installed the extra node required for your flow to work. If you check the Tab-Palette, you'll now see the extra node.

========================================================================================
C) Configure flow
As each network is different and IP-addresses vary, you need to tell Node-RED where to listen and talk to.
The Node-RED flow needs to be told where it will receive the buttons pressed (MQTT on META) and what IP-address your Samsung TV has.
When you look at the window with the SamsungTV2012-flow, you'll see an icon on the left called NEEO, representing the product MQTT running on the NEEO-Brain while at the right, a box called Samsung is present which represents your TV.
In fact, its good practice to have the input to a flow on the left and the output to the right.

We'll need to change the IP-address of our Samsung TV. To do so, double-click on the icon SamsungTV (output-node, so located at the right of the flow). You;ll see IP, with a default IP-address in it. Change the default IP-address and set it to the IP-address of your SamsungTV.
Click "Update" at the right of this dialog and click 'Done".

Now we'll check the IP-address of the connection to Mosquitto. The icon on the left, called NEEO represents the product MQTT running on the NEEO-Brain. Double click on that icon to open the properties of this "node". Now click on the pencil, right to the field named Server.
You'll see that the IP-address is already configured as local (127.0.0.1), which is the correct value for a pre-configured NEEO eco system on your NEEO-Brain. If you're running mosquitto on another system, you'll have to fill the address of that mosquitto-system here.
Again, on a pre-configured NEEO eco system on your NEEO-Brain, the node should be already correctly configured (IP: 127.0.0.1), so you do not need to change it. 

========================================================================================
D) Deplay (activate) flow
Last, we're going to "Deploy" this flow and the changes we made to it; Node-RED is already telling us that we have not-deployed changes by the bright red Icon labeled "Deploy: at the rioght, just besides the submenu icon (3 bars).
You always need to look at the Deploy-icon to know if the last changes are actually activated...

As soon as you click on Deploy, Node-RED will check flow and parameters and if they are found correct, it will activate the flow with changes. 

Now you are all set to control your Samsung TV through HTTP.... 

One note however: Some devices shutdown their internal processor when powered-off, and won't respond to commands send over the network.
For this, we'll still need to send an InfraRed-command to  your TV to power on. This is normally done by the Brain, but it could be handled by a Broadlink IR_transmitter as well

