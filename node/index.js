// Required modules
require('dotenv').config()
const net = require('net')
const { TextDecoder } = require('util')
const { WebSocket, createWebSocketStream } = require('ws')

// Constants
const serverID = process.env.ID
const serverPort = process.env.PORT

// Define logging and error callback function
const log = (type, ...args) => console[type](`[${new Date().toISOString()}] ${type.toUpperCase()}:`, ...args)

// Define WebSocket server
const wss = new WebSocket.Server({ port: serverPort }, () => log('info', 'listen:', serverPort))
wss.on('connection', (ws) => {
  ws.once('message', (msg) => handleMessage(msg, ws))
})

// Function to handle incoming messages
const handleMessage = (msg, ws) => {
  const id = msg.slice(1, 17).toString('hex')
  if (id !== serverID) return
  const [version] = msg
  let offset = msg.slice(17, 18).readUInt8() + 19
  const targetPort = msg.slice(offset, (offset += 2)).readUInt16BE(0)
  const addressType = msg.slice(offset, (offset += 1)).readUInt8()
  const hosts = {
    1: () => msg.slice(offset, (offset += 4)).join('.'), // IPV4
    2: () => new TextDecoder().decode(msg.slice(offset + 1, (offset += 1 + msg.slice(offset, offset + 1).readUInt8()))), // Domain
    3: () => msg.slice(offset, (offset += 16)).reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), []).map((b) => b.readUInt16BE(0).toString(16)).join(':') // IPV6
  }
  const targetHost = hosts[addressType] ? hosts[addressType]() : ''
  log('info', `Incoming connection from ${targetHost}:${targetPort}`)
  ws.send(new Uint8Array([version, 0]))
  const duplexStream = createWebSocketStream(ws)
  establishConnection(targetHost, targetPort, msg.slice(offset), duplexStream)
}

// Function to establish connection with the host
const establishConnection = (host, port, data, duplex) => {
  const clientSocket = net.connect({ host, port }, function () {
    log('info', `Connected to ${host}:${port}`)
    this.write(data)
    duplex.on('error', () => log('error', `Error in WebSocket stream to ${host}:${port}`)).pipe(this).on('error', () => log('error', `Error piping data to/from ${host}:${port}`)).pipe(duplex)
  }).on('error', () => log('error', `Error connecting to ${host}:${port}`))
}
