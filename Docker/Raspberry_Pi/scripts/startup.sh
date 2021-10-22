#/bin/bash!

pm2 start mosquitto
pm2 start node-red
node /opt/meta/node_modules/@jac459/metadriver/meta.js
 