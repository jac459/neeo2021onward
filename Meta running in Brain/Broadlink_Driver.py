from flask import Flask, request, jsonify
import json
import broadlink
import time
import binascii
import struct
import math
from broadlink.exceptions import ReadError, StorageError
from flask import request

# Files for ADB_Shell commands: over network
from adb_shell.adb_device import AdbDeviceTcp, AdbDeviceUsb
from adb_shell.auth.sign_pythonrsa import PythonRSASigner
import logging

logging.getLogger().setLevel(logging.DEBUG)

logger = logging.getLogger('websockets')
logger.setLevel(logging.INFO)

# create console handler and set level to debug
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)

# create formatter
formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

# add formatter to ch
ch.setFormatter(formatter)

# add ch to logger
logger.addHandler(ch)


TIMEOUT = 30  # Timeout for learn
TICK = 32.84
ConnectedHosts = []
ADBHostList = {}
ADBDevice = ""

### Full credits need to go to Felipe Diel / MJG59 for his EXCELLENT Broadlink driver. 
# A lot of code in this program was inspired or even obtained from hs fgithub site: https://github.com/mjg59/python-broadlink
### So all credits need to go to him..........

def shutdown_server():
    func = request.environ.get('werkzeug.server.shutdown')
    if func is None:
        raise RuntimeError('Not running with the Werkzeug Server')
    func()

def format_durations(data):
    result = ''
    for i in range(0, len(data)):
        if len(result) > 0:
            result += ' '
        result += ('+' if i % 2 == 0 else '-') + str(data[i])
    return result

def to_microseconds(bytes):
    result = []
    #  print bytes[0] # 0x26 = 38for IR
    index = 4
    while index < len(bytes):
        chunk = bytes[index]
        index += 1
        if chunk == 0:
            chunk = bytes[index]
            chunk = 256 * chunk + bytes[index + 1]
            index += 2
        result.append(int(round(chunk * TICK)))
        if chunk == 0x0d05:
            break
    return result

def lirc2gc(cmd):
    result = "" 
    NextByte=False 
    for code in cmd:  # .split(" "):
        if NextByte:
            result+=","
        else:
            NextByte=True
        result += str(round(abs(int(int(code)*0.038400))))
    return "sendir,1:1,1,38400,3,1,"+result

def gc2lirc(gccmd):
    frequency = int(gccmd.split(",")[3])*1.0/1000000
    pulses = gccmd.split(",")[6:]
    return [int(round(int(code) / frequency)) for code in pulses]

def lirc2broadlink(pulses):
    array = bytearray()

    for pulse in pulses:
        pulse = math.floor(pulse * 269 / 8192)  # 32.84ms units

        if pulse < 256:
            array += bytearray(struct.pack('>B', pulse))  # big endian (1-byte)
        else:
            array += bytearray([0x00])  # indicate next number is 2-bytes
            array += bytearray(struct.pack('>H', pulse))  # big endian (2-bytes)

    packet = bytearray([0x26, 0x00])  # 0x26 = IR, 0x00 = no repeats
    packet += bytearray(struct.pack('<H', len(array)))  # little endian byte count
    packet += array
    packet += bytearray([0x0d, 0x05])  # IR terminator

    # Add 0s to make ultimate packet size a multiple of 16 for 128-bit AES encryption.
    remainder = (len(packet) + 4) % 16  # rm.send_data() adds 4-byte header (02 00 00 00)
    if remainder:
        packet += bytearray(16 - remainder)

    return packet


def Convert_GC_to_Broadlink(stream): 

    pulses = gc2lirc(stream)
    packet = lirc2broadlink(pulses)
    pcodes = [int(binascii.hexlify(packet[i:i+2]), 16) for i in range(0, len(packet), 2)]
    #result = commandname.replace(' ', '_').replace('/','_').lower() +" "+ binascii.b2a_hex(packet).decode('utf-8')
    result = binascii.b2a_hex(packet).decode('utf-8')
    return result 

def Convert_Broadlink_to_GC(stream): 
    #First convert Broadlink-format to Lirc
    data = bytearray.fromhex(''.join(stream))
    durations = to_microseconds(data)
    print("Broadlink: durations",durations)
    #Then convert format from Lirc to GC
    result = lirc2gc(durations)
    return result


# broadlink 26004600949412371237123712121212121212121212123712371237121212121212121212121237123712371212121212121212121212121212121212371237123712371237120006050d05
# LIRC Pulses: [4521, 4521, 555, 1692, 555, 1692, 555, 1692, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 1692, 555, 1692, 555, 1692, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 1692, 555, 1692, 555, 1692, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 1692, 555, 1692, 555, 1692, 555, 1692, 555, 1692, 555, 46953]
# GC 'sendir,1:1,1,37825,1,1,171,171,21,64,21,64,21,64,21,21,21,21,21,21,21,21,21,21,21,64,21,64,21,64,21,21,21,21,21,21,21,21,21,21,21,64,21,64,21,64,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,64,21,64,21,64,21,64,21,64,21,1776'


def Connect_Broadlink():

   host = request.args.get('host')
   type = int(request.args.get('type'),16) 
   mac  = bytearray.fromhex(request.args.get('mac'))
   print("host, type, mac:",host,type,mac)
   dev = broadlink.gendevice(type, (host, 80), mac)
   print("We have a device") 
   dev.auth()
   print('dev=',dev)
   return dev


def Connect_ADB():
    global ADBDevice
    host = request.args.get('host')
    print("ADB_Driver: host:",host)
    logger.info("ADB_Driver: connecting to host: "+host)
    try:                                            # Checking if we are already connected.
       ADBDevice = ADBHostList[host]["ADBSocket"]       
       return 
    except:
        logger.info("Setting up connection ADB with "+host)

    ADBDevice = AdbDeviceTcp(host, 5555, default_transport_timeout_s=5.)
    ## Load the public and private keys so we can connect to Android and authenticate ourself (also for future use) 
    adbkey = '/home/neeo/ADB_Shell_key'
    with open(adbkey) as f:
        priv = f.read()

    with open(adbkey + '.pub') as f:
        pub = f.read()
    signer = PythonRSASigner(pub, priv)

    ADBDevice.connect(rsa_keys=[signer],auth_timeout_s=5)

    ADBHostList.setdefault(host, {})["ADBSocket"] = ADBDevice
    logger.info("Hostlist is now ")
    logger.info(ADBHostList)
    return

def Send_ADB():
    global ADBDevice
    logger.info(ADBDevice)
    # Send a shell command
    Command = request.args.get('command')
    AsRoot = request.args.get('root',default='')
    if AsRoot == 'yes':  
        Response = ADBDevice.root()
    print("Command is:",Command)
    Response = ADBDevice.shell(Command)
    if Response is None:
        return {}

    Response = Response.strip().split("\r\n")
    retcode = Response[-1]
    output = "\n".join(Response[:-1])

    return {"retcode": retcode, "output": output}
    #return Response

app = Flask(__name__)

@app.route('/')
def index():
    return 'Server Works!'

@app.route('/QUIT')
def quit():
    print("Received shutdown request")
    # return 'Quitting'
    shutdown_server()
    return 'Server shutting down...'    
  
@app.route('/adb',  methods=['GET','POST'])
def _adb():
    print("ADB_Driver:")
    ADBDevice = Connect_ADB()  
    print("ADB_Driver: Connection to device succeeded")
    Response = Send_ADB()
    return Response 


@app.route('/xmit',  methods=['GET','POST'])
def _xmit():
    print("Broadlink_Driver: xmit-request")
    dev = Connect_Broadlink()  
    print("Broadlink_Driver: Connection to Broadlink succeeded")
    data = request.args.get('stream')
    print("Broadlink_Driver: Sending data", data)
    SendThis = bytearray.fromhex(data)
    dev.send_data(SendThis)
    return 'OK'


@app.route('/xmitGC', methods=['GET','POST'])
def _xmitGC():
    print("Broadlink_Driver: Send GC requested")
    dev = Connect_Broadlink()  
    print("Broadlink_Driver: Connection to Broadlink succeeded")
    data = request.args.get('stream')
    print("Broadlink_Driver: Input data", data)

    # Now convert the Global Cache format to our format
    print("Broadlink_Driver: GC data", data)    
    ConvData = Convert_GC_to_Broadlink(data)    
    print("Broadlink_Driver: Conversion done, sending this data", ConvData)
    SendThis = bytearray.fromhex(ConvData)
    dev.send_data(SendThis)
    return 'OK'

@app.route('/GCToBroad', methods=['GET','POST'])
def ConvertBroadtoGC(Stream):
    print("Broadlink_Driver: Conversion GC to Broadlink  requested")
    # Now convert the Global Cache format to our format
    ConvData = Convert_GC_to_Broadlink(Stream)    
    print("Broadlink_Driver: Conversion done, returning this data", ConvData)
    #SendThis = bytearray.fromhex(ConvData)
    SendThis = ConvData    
    return SendThis

@app.route('/BroadtoGC', methods=['GET','POST'])
def BroadtoGC():
    print("Broadlink_Driver: Conversion Broadlink to GC  requested")
    data = request.args.get('stream')
    print("Broadlink_Driver: Input data", data)
    ConvData = ConvertBroadtoGC(data)
    # Now convert the Global Cache format to our format
    print("Broadlink_Driver: GC data", ConvData)    
    return ConvData 

@app.route('/rcve',  methods=['GET','POST'])
def _rcve():
    #data = request.args.get['stream']
    print("Broadlink_Driver: Learning requested")
    dev = Connect_Broadlink()
    print("Broadlink_Driver: Connection to Broadlink succeeded")    
    print("Broadlink_Driver: Learning for",TIMEOUT,"ms")
    dev.enter_learning()
    start = time.time()
    while time.time() - start < TIMEOUT:
        time.sleep(1)
        try:
            data = dev.check_data()
        except (ReadError, StorageError):
            continue
        else:
            break
    else:
        #print("No data received...")
        return 'timeout'
    Learned = ''.join(format(x, '02x') for x in bytearray(data))
    print("Broadlink_Driver: Learned:", Learned)
    return Learned

@app.route('/rcveGC',  methods=['GET','POST'])
def _rcveGC():
    Learned=_rcve()
    return ConvertBroadtoGC(Learned)

def main():
    app.run(host='0.0.0.0', port=5000)

        
if __name__ == '__main__':
    main()
