from flask import Flask, request, jsonify
import json
import broadlink
import time
from broadlink.exceptions import ReadError, StorageError
TIMEOUT = 30  # Timeout for learn



def format_durations(data):
    result = ''
    for i in range(0, len(data)):
        if len(result) > 0:
            result += ' '
        result += ('+' if i % 2 == 0 else '-') + str(data[i])
    return result


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

app = Flask(__name__)

@app.route('/')
def index():
    return 'Server Works!'

@app.route('/QUIT')
def quit():
    return 'Quitting'
  
@app.route('/xmit',  methods=['GET','POST'])
def _xmit():
    print("In xmit")
    dev = Connect_Broadlink()  
    print("Connected to broadlik")
    data = request.args.get('stream')
    print("Stream:", data)
    SendThis = bytearray.fromhex(data)
    print("Stream: ", SendThis)
    dev.send_data(SendThis)
    return 'OK'


@app.route('/rcve',  methods=['GET','POST'])
def _rcve():
    #data = request.args.get['stream']
    dev = Connect_Broadlink()
    
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
    return Learned

