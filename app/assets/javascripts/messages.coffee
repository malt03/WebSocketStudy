$ ->
  getParameters = ->
    paramsArray = []
    url = location.href
    parameters = url.split("?")
    if parameters.length > 1
      params = parameters[1].split("&")
      for param in params
        paramItem = param.split("=")
        paramsArray[paramItem[0]] = paramItem[1]
    return paramsArray

  getParameter = (label) ->
    getParameters()[label]

  myId = getParameter('id')
  remoteId = null

  ws_rails = new WebSocketRails(location.host + "/websocket?id=" + myId)
  ws_rails.bind("receive"
    (data) ->
      evt = JSON.parse(data)
      switch evt['type']
        when 'call'
          remoteId = evt['remoteId']
        when 'offer'
          onOffer(evt)
          console.log('offer')
        when 'answer'
          console.log('answer')
          if peerStarted
            console.log('answer2')
            onAnswer(evt)
        when 'candidate'
          console.log('candidate')
          if peerStarted
            console.log('candidate2')
            onCandidate(evt)
        when 'user disconnected'
          console.log('disconnected')
          if peerStarted
            console.log('disconnected2')
            stop()
  )

  sendMessage = (message) ->
    $.ajax
      type: 'POST'
      url: 'messages'
      data:
        id: remoteId || $('#id').val()
        message: message

  localVideo = document.getElementById('local-video')
  remoteVideo = document.getElementById('remote-video')
  localStream = null
  peerConnection = null
  peerStarted = false
  mediaConstraints = 'mandatory':
    'OfferToReceiveAudio': true
    'OfferToReceiveVideo': true

  onOffer = (evt) ->
    console.log 'Received offer...'
    console.log evt
    setOffer evt
    sendAnswer evt
    peerStarted = true

  onAnswer = (evt) ->
    console.log 'Received Answer...'
    console.log evt
    setAnswer evt
    return

  onCandidate = (evt) ->
    candidate = new RTCIceCandidate(
      sdpMLineIndex: evt.sdpMLineIndex
      sdpMid: evt.sdpMid
      candidate: evt.candidate)
    console.log 'Received Candidate...'
    console.log candidate
    peerConnection.addIceCandidate candidate

  sendSDP = (sdp) ->
    text = JSON.stringify(sdp)
    console.log '---sending sdp text ---'
    console.log text
    sendMessage(text)

  sendCandidate = (candidate) ->
    text = JSON.stringify(candidate)
    console.log '---sending candidate text ---'
    console.log text
    sendMessage(text)

  # ---------------------- video handling -----------------------
  # start local video

  startVideo = ->
    navigator.webkitGetUserMedia {
      video: true
      audio: false
    }, ((stream) ->
      # success
      localStream = stream
      localVideo.src = window.webkitURL.createObjectURL(stream)
      localVideo.play()
      localVideo.volume = 0
      return
    ), (error) ->
      # error
      console.error 'An error occurred: [CODE ' + error.code + ']'
      return
    return

  startVideo()
  # stop local video

  @stopVideo = ->
    localVideo.src = ''
    localStream.stop()
    return

  # ---------------------- connection handling -----------------------

  prepareNewConnection = ->
    pc_config = 'iceServers': [ "url": "stun:stun.l.google.com:19302" ]
    peer = null
    # when remote adds a stream, hand it on to the local video element

    onRemoteStreamAdded = (event) ->
      console.log 'Added remote stream'
      remoteVideo.src = window.webkitURL.createObjectURL(event.stream)
      return

    # when remote removes a stream, remove it from the local video element

    onRemoteStreamRemoved = (event) ->
      console.log 'Remove remote stream'
      remoteVideo.src = ''
      return

    try
      peer = new webkitRTCPeerConnection(pc_config)
    catch e
      console.log 'Failed to create peerConnection, exception: ' + e.message
    # send any ice candidates to the other peer

    peer.onicecandidate = (evt) ->
      if evt.candidate
        console.log evt.candidate
        sendCandidate
          type: 'candidate'
          sdpMLineIndex: evt.candidate.sdpMLineIndex
          sdpMid: evt.candidate.sdpMid
          candidate: evt.candidate.candidate
      else
        console.log 'End of candidates. ------------------- phase=' + evt.eventPhase
      return

    console.log 'Adding local stream...'
    peer.addStream localStream
    peer.addEventListener 'addstream', onRemoteStreamAdded, false
    peer.addEventListener 'removestream', onRemoteStreamRemoved, false
    peer

  sendOffer = ->
    peerConnection = prepareNewConnection()
    peerConnection.createOffer ((sessionDescription) ->
      # in case of success
      peerConnection.setLocalDescription sessionDescription
      console.log 'Sending: SDP'
      console.log sessionDescription
      sendSDP sessionDescription
      return
    ), (->
      # in case of error
      console.log 'Create Offer failed'
      return
    ), mediaConstraints
    return

  setOffer = (evt) ->
    if peerConnection
      console.error 'peerConnection alreay exist!'
    peerConnection = prepareNewConnection()
    peerConnection.setRemoteDescription new RTCSessionDescription(evt)
    return

  sendAnswer = (evt) ->
    console.log 'sending Answer. Creating remote session description...'
    if !peerConnection
      console.error 'peerConnection NOT exist!'
      return
    peerConnection.createAnswer ((sessionDescription) ->
      # in case of success
      peerConnection.setLocalDescription sessionDescription
      console.log 'Sending: SDP'
      console.log sessionDescription
      sendSDP sessionDescription
      return
    ), (->
      # in case of error
      console.log 'Create Answer failed'
      return
    ), mediaConstraints
    return

  setAnswer = (evt) ->
    if !peerConnection
      console.error 'peerConnection NOT exist!'
      return
    peerConnection.setRemoteDescription new RTCSessionDescription(evt)
    return

  # -------- handling user UI event -----
  # start the connection upon user request

  @connect = ->
    #if (!peerStarted && localStream && channelReady) {
    if !peerStarted and localStream
      sendMessage(JSON.stringify(
        type: 'call'
        remoteId: myId
      ))
      sendOffer()
      peerStarted = true
    else
      alert 'Local stream not running yet - try again.'
    return

  # stop the connection upon user request

  @hangUp = ->
    console.log 'Hang up.'
    stop()
    return

  stop = ->
    peerConnection.close()
    peerConnection = null
    peerStarted = false
    peerStarted = false
    return
