app = angular.module 'app', ['ngGrid']

app.controller 'main', ['$scope', '$interval', ($scope, $interval) ->
  $scope.dataValues = []
  $scope.data = {}
  $scope.nowPlaying = false
  $scope.player = null
  $scope.progress = 0

  $scope.gridOptions =
    columnDefs: [
      {
        field: 'title'
        cellTemplate:
          '<div class="ngCellText {{col.colIndex()}}" ng-class="{\'now-playing-indicator\': row.entity.playing, \'now-paused-indicator\': row.entity.paused}" ng-dblclick="play(row.entity)">
            <span ng-cell-text>{{ COL_FIELD }}</span>
          </div>'
      }
      { field: 'artist' }
      { field: 'album' }
      { field: 'genre' }
    ]
    data: 'dataValues'
    enableColumnReordering: true
    enableColumnResize: true
    multiSelect: false
    headerRowHeight: 26
    rowHeight: 26
    rowTemplate:
      '<div ng-style="{ \'cursor\': row.cursor }" ng-repeat="col in renderedColumns" ng-class="col.colIndex()" class="ngCell {{col.cellClass}}">
        <div class="ngVerticalBar ngVerticalBarVisible" ng-style="{height: rowHeight}">&nbsp;</div>
        <div ng-cell></div>
      </div>'
    selectedItems: []
    showFilter: true

  #set cellTemplate default for all columns:
  _.each $scope.gridOptions.columnDefs, (col) ->
    _.defaults col,
      cellTemplate:
        '<div class="ngCellText" ng-class="col.colIndex()" ng-dblclick="play(row.entity)">
          <span ng-cell-text>{{ COL_FIELD }}</span>
        </div>'

  $scope.getSelectedTrack = ->
    if $scope.gridOptions.selectedItems.length
      return $scope.gridOptions.selectedItems[0]
    else
      return $scope.dataValues[0]

  $scope.togglePlayback = ->
    unless $scope.nowPlaying
      $scope.play()
    else
      $scope.player.togglePlayback()
      if $scope.nowPlaying.playing
        $scope.nowPlaying.playing = false
        $scope.nowPlaying.paused = true
        $interval.cancel $scope.player.timer
      else
        $scope.nowPlaying.playing = true
        $scope.nowPlaying.paused = false
        $scope.player.timer = $interval calculateProgress, 100

  $scope.getAdjacent = (direction) ->
    return $scope.dataValues[$scope.dataValues.indexOf($scope.nowPlaying) + direction]

  $scope.previous = ->
    if $scope.player.currentTime > 1000
      $scope.player.seek 0
    else
      $scope.play $scope.getAdjacent -1

  $scope.next = ->
    $scope.play $scope.getAdjacent 1

  $scope.stop = ->
    $scope.nowPlaying.playing = false
    $scope.nowPlaying.paused = false
    $scope.player.stop()

  calculateProgress = ->
    $scope.progress = ($scope.player.currentTime / $scope.player.duration) * 100

  $scope.play = (track) ->
    if $scope.player
      $scope.stop()
    unless track
      track = $scope.getSelectedTrack()
    $scope.player = AV.Player.fromURL 'target/' + track.filePath
    track.playing = true
    $scope.nowPlaying = track
    $scope.player.play()
    $scope.player.timer = $interval calculateProgress, 100
    $scope.player.on 'end', ->
      $scope.next()

  socket = io.connect 'http://localhost'

  socket.on 'metadata', (data) ->
    _.extend $scope.data.tracks[data.filePath], _.omit data, 'filePath'
    $scope.$apply()

  socket.on 'json', (data) ->
    $scope.data = data
    $scope.dataValues = _.values data.tracks
    $scope.$apply()
]

app.filter 'convertTimestamp', ->
  padTime = (n) ->
    if n < 10
      n = '0' + n
    return n

  (s = 0) ->
    ms = s % 1000
    s = (s - ms) / 1000
    secs = s % 60
    s = (s - secs) / 60
    mins = s % 60
    hrs = (s - mins) / 60
    if hrs
      return hrs + ':' + padTime mins + ':' + padTime secs
    else
      return mins + ':' + padTime secs

