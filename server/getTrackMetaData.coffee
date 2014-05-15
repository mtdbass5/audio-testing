fs = require 'fs'
async = require 'async'
path = require 'path'
_ = require 'lodash'

require '../public/js/aurora.js'
require '../public/js/flac.js'
require '../public/js/mp3.js'
require '../public/js/aac.js'

toBuffer = (ab) ->
  buffer = new Buffer ab.byteLength
  view = new Uint8Array ab
  for val, i in buffer
    buffer[i] = view[i]
  buffer

processCoverArt = (track, data) ->
  folderPath = path.dirname(track) + '/coverArt'
  filePath = folderPath + '/' + data.artist + ' - ' + data.album + '.jpg'
  unless fs.existsSync filePath
    unless fs.existsSync folderPath
      fs.mkdirSync folderPath
    fs.writeFileSync filePath, toBuffer data.coverArt.data.buffer
  filePath.slice 2

processData = (track, data, callback) ->
  player = AV.Player.fromBuffer new Uint8Array data
  player.preload()
  player.on 'metadata', (data) ->
    data.trackNumber = data.trackNumber or data.tracknumber
    data.year = data.year or data.date or data.releaseDate
    if data.trackNumber
      data.trackNumber = parseInt data.trackNumber, 10
    if data.coverArt
      data.coverArtURL = processCoverArt track, data
    callback null, _.pick data, [
      'title'
      'artist'
      'album'
      'genre'
      'trackNumber'
      'year'
      'coverArtURL'
    ]

processDataOnce = _.once processData

readEntireFile = (track, callback) ->
  fs.readFile track, (err, data) ->
    throw err if err
    processData track, data, callback

readStream = (track, callback) ->
  stream = fs.createReadStream track,
    start: 0, end: 9999
  stream.on 'data', (data) ->
    processDataOnce track, data, callback

getTrackMetaData = (track, callback) ->
  if path.extname(track) is '.m4a'
    readEntireFile track, callback
  else
    readStream track, callback

async.map process.argv.slice(2), getTrackMetaData,
  (err, result) ->
    process.stdout.write JSON.stringify result
