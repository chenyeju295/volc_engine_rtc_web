/**
 * RTC Client implementation for browser using Volcano Engine RTC SDK
 */
class RtcClient {
  /**
   * Constructor for RTC client
   * @param {Object} config - Configuration object
   * @param {string} config.appId - Application ID
   * @param {string} config.roomId - Room ID
   * @param {string} config.userId - User ID
   * @param {string} config.token - Authentication token
   */
  constructor(config) {
    this.appId = config.appId;
    this.roomId = config.roomId;
    this.userId = config.userId;
    this.token = config.token;
    
    this.localAudioStream = null;
    this.localVideoStream = null;
    this.rtcEngine = null;
    
    // Check if Volcano Engine SDK is loaded
    if (window.VERTC === undefined) {
      console.error('[RtcClient] Volcano Engine RTC SDK not loaded');
      throw new Error('Volcano Engine RTC SDK not loaded');
    }
    
    // Initialize RTC engine
    this._initializeRtcEngine();
    
    console.log('[RtcClient] Initialized with config', {
      appId: this.appId,
      roomId: this.roomId,
      userId: this.userId
    });
  }
  
  /**
   * Initialize the RTC engine
   * @private
   */
  _initializeRtcEngine() {
    try {
      // Create RTC engine instance using the loaded SDK
      this.rtcEngine = new window.VERTC.createEngine(this.appId);
      
      // Set up event listeners
      this._setupEventListeners();
      
      console.log('[RtcClient] RTC engine initialized');
    } catch (error) {
      console.error('[RtcClient] Failed to initialize RTC engine', error);
      throw error;
    }
  }
  
  /**
   * Set up event listeners for the RTC engine
   * @private
   */
  _setupEventListeners() {
    if (!this.rtcEngine) return;
    
    // Set up event handlers for the RTC engine
    this.rtcEngine.on('onWarning', (warn) => {
      console.warn('[RtcClient] Warning:', warn);
    });
    
    this.rtcEngine.on('onError', (err) => {
      console.error('[RtcClient] Error:', err);
    });
    
    this.rtcEngine.on('onJoinRoomResult', (roomId, uid, result) => {
      console.log('[RtcClient] Join room result:', roomId, uid, result);
    });
    
    this.rtcEngine.on('onLeaveRoom', () => {
      console.log('[RtcClient] Left room');
    });
    
    this.rtcEngine.on('onUserJoined', (uid) => {
      console.log('[RtcClient] User joined:', uid);
    });
    
    this.rtcEngine.on('onUserLeave', (uid) => {
      console.log('[RtcClient] User left:', uid);
    });
  }
  
  /**
   * Connect to the RTC room
   * @param {Object} callbacks - Callback functions
   * @param {Function} callbacks.success - Success callback
   * @param {Function} callbacks.failure - Failure callback
   */
  connect(callbacks) {
    try {
      if (!this.rtcEngine) {
        throw new Error('RTC engine not initialized');
      }
      
      console.log('[RtcClient] Connecting to room', this.roomId);
      
      // Set room options
      const roomConfig = {
        room_id: this.roomId,
        user_id: this.userId,
        token: this.token
      };
      
      // Join the room
      this.rtcEngine.joinRoom(this.token, this.roomId, this.userId, {
        // Room join options
        is_auto_publish: true,
        is_auto_subscribe_audio: true,
        is_auto_subscribe_video: true
      });
      
      // Notify about device status
      this._checkDevices();
      
      if (callbacks && callbacks.success) {
        callbacks.success();
      }
    } catch (error) {
      console.error('[RtcClient] Error connecting to room', error);
      if (callbacks && callbacks.failure) {
        callbacks.failure(error);
      }
    }
  }
  
  /**
   * Check available devices and notify
   * @private
   */
  _checkDevices() {
    if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
      navigator.mediaDevices.enumerateDevices()
        .then(devices => {
          const hasAudioInput = devices.some(device => device.kind === 'audioinput');
          const hasVideoInput = devices.some(device => device.kind === 'videoinput');
          
          if (typeof window.onDeviceStatusChange === 'function') {
            window.onDeviceStatusChange(hasAudioInput);
          }
        })
        .catch(err => {
          console.error('[RtcClient] Error checking devices:', err);
          if (typeof window.onDeviceStatusChange === 'function') {
            window.onDeviceStatusChange(false);
          }
        });
    }
  }
  
  /**
   * Set local audio stream
   * @param {MediaStream} stream - Audio media stream
   */
  setLocalAudioStream(stream) {
    if (!this.rtcEngine) return;
    
    this.localAudioStream = stream;
    
    try {
      // Get audio track from stream
      const audioTrack = stream.getAudioTracks()[0];
      if (audioTrack) {
        // Create local audio track from MediaStreamTrack
        const localAudioTrack = this.rtcEngine.createCustomAudioTrack(audioTrack);
        
        // Publish the track
        this.rtcEngine.publishStream(localAudioTrack);
      }
      
      console.log('[RtcClient] Local audio stream set');
    } catch (error) {
      console.error('[RtcClient] Error setting local audio stream', error);
    }
  }
  
  /**
   * Set local video stream
   * @param {MediaStream} stream - Video media stream
   */
  setLocalVideoStream(stream) {
    if (!this.rtcEngine) return;
    
    this.localVideoStream = stream;
    
    try {
      // Get video track from stream
      const videoTrack = stream.getVideoTracks()[0];
      if (videoTrack) {
        // Create local video track from MediaStreamTrack
        const localVideoTrack = this.rtcEngine.createCustomVideoTrack(videoTrack);
        
        // Publish the track
        this.rtcEngine.publishStream(localVideoTrack);
      }
      
      console.log('[RtcClient] Local video stream set');
    } catch (error) {
      console.error('[RtcClient] Error setting local video stream', error);
    }
  }
  
  /**
   * Stop local audio stream
   */
  stopLocalAudio() {
    if (!this.rtcEngine) return;
    
    try {
      // Unpublish local audio
      this.rtcEngine.unpublishStream({ mediaType: 'audio' });
      
      // Stop tracks in the stream
      if (this.localAudioStream) {
        this.localAudioStream.getAudioTracks().forEach(track => track.stop());
        this.localAudioStream = null;
      }
      
      console.log('[RtcClient] Local audio stream stopped');
    } catch (error) {
      console.error('[RtcClient] Error stopping local audio', error);
    }
  }
  
  /**
   * Stop local video stream
   */
  stopLocalVideo() {
    if (!this.rtcEngine) return;
    
    try {
      // Unpublish local video
      this.rtcEngine.unpublishStream({ mediaType: 'video' });
      
      // Stop tracks in the stream
      if (this.localVideoStream) {
        this.localVideoStream.getVideoTracks().forEach(track => track.stop());
        this.localVideoStream = null;
      }
      
      console.log('[RtcClient] Local video stream stopped');
    } catch (error) {
      console.error('[RtcClient] Error stopping local video', error);
    }
  }
  
  /**
   * Disconnect from the RTC room
   */
  disconnect() {
    if (!this.rtcEngine) return;
    
    try {
      // Stop local streams
      this.stopLocalAudio();
      this.stopLocalVideo();
      
      // Leave the room
      this.rtcEngine.leaveRoom();
      
      console.log('[RtcClient] Disconnected from room', this.roomId);
    } catch (error) {
      console.error('[RtcClient] Error disconnecting from room', error);
    }
  }
}

/**
 * ASR Client implementation for browser
 */
class AsrClient {
  /**
   * Constructor for ASR client
   * @param {Object} config - Configuration object
   * @param {string} config.appId - Application ID
   * @param {string} config.serverUrl - Server URL
   */
  constructor(config) {
    this.appId = config.appId;
    this.serverUrl = config.serverUrl;
    this.isRecognizing = false;
    this.asrEngineUrl = `${this.serverUrl}/api/asr`;
    this.mediaRecorder = null;
    this.audioContext = null;
    this.ws = null;
    
    console.log('[AsrClient] Initialized with appId', this.appId);
  }
  
  /**
   * Start speech recognition
   * @param {Object} callbacks - Callback functions
   * @param {Function} callbacks.success - Success callback
   * @param {Function} callbacks.failure - Failure callback
   */
  startRecognition(callbacks) {
    try {
      if (this.isRecognizing) {
        if (callbacks && callbacks.success) {
          callbacks.success();
        }
        return;
      }
      
      // Request microphone access
      navigator.mediaDevices.getUserMedia({ audio: true })
        .then(stream => {
          console.log('[AsrClient] Microphone access granted');
          this._setupAudioProcessing(stream);
          this.isRecognizing = true;
          
          if (callbacks && callbacks.success) {
            callbacks.success();
          }
        })
        .catch(error => {
          console.error('[AsrClient] Microphone access denied', error);
          if (callbacks && callbacks.failure) {
            callbacks.failure(error);
          }
        });
    } catch (error) {
      console.error('[AsrClient] Error starting speech recognition', error);
      if (callbacks && callbacks.failure) {
        callbacks.failure(error);
      }
    }
  }
  
  /**
   * Set up audio processing for ASR
   * @private
   * @param {MediaStream} stream - Audio media stream
   */
  _setupAudioProcessing(stream) {
    try {
      // Create WebSocket connection to ASR service
      this.ws = new WebSocket(this.asrEngineUrl);
      
      this.ws.onopen = () => {
        console.log('[AsrClient] WebSocket connection established');
        
        // Send initialization message with appId
        const initMessage = {
          type: 'init',
          appId: this.appId
        };
        this.ws.send(JSON.stringify(initMessage));
        
        // Set up MediaRecorder for audio capture
        this.mediaRecorder = new MediaRecorder(stream);
        
        this.mediaRecorder.ondataavailable = event => {
          if (event.data.size > 0 && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(event.data);
          }
        };
        
        this.mediaRecorder.start(100); // Capture in 100ms chunks
      };
      
      this.ws.onmessage = event => {
        try {
          const response = JSON.parse(event.data);
          
          if (response.text) {
            const text = response.text;
            const isFinal = response.isFinal || false;
            
            // Call the callback function
            if (typeof window.onSpeechRecognized === 'function') {
              window.onSpeechRecognized(text, isFinal);
            }
          }
        } catch (error) {
          console.error('[AsrClient] Error parsing WebSocket message', error);
        }
      };
      
      this.ws.onerror = error => {
        console.error('[AsrClient] WebSocket error', error);
      };
      
      this.ws.onclose = () => {
        console.log('[AsrClient] WebSocket connection closed');
        this.stopRecognition();
      };
    } catch (error) {
      console.error('[AsrClient] Error setting up audio processing', error);
      this.stopRecognition();
    }
  }
  
  /**
   * Stop speech recognition
   */
  stopRecognition() {
    if (!this.isRecognizing) return;
    
    try {
      // Stop media recorder if it exists
      if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
        this.mediaRecorder.stop();
      }
      
      // Close WebSocket if it exists
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.close();
      }
      
      this.mediaRecorder = null;
      this.ws = null;
      this.isRecognizing = false;
      
      console.log('[AsrClient] Speech recognition stopped');
    } catch (error) {
      console.error('[AsrClient] Error stopping speech recognition', error);
    }
  }
  
  /**
   * Dispose ASR client
   */
  dispose() {
    this.stopRecognition();
    
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
    }
    
    console.log('[AsrClient] Disposed');
  }
}

/**
 * TTS Client implementation for browser
 */
class TtsClient {
  /**
   * Constructor for TTS client
   * @param {Object} config - Configuration object
   * @param {string} config.appId - Application ID
   * @param {string} config.serverUrl - Server URL
   */
  constructor(config) {
    this.appId = config.appId;
    this.serverUrl = config.serverUrl;
    this.ttsEngineUrl = `${this.serverUrl}/api/tts`;
    this.isSpeaking = false;
    this.audioContext = null;
    this.audioSource = null;
    this.audioQueue = [];
    
    // Initialize audio context
    this._initAudioContext();
    
    console.log('[TtsClient] Initialized with appId', this.appId);
  }
  
  /**
   * Initialize audio context
   * @private
   */
  _initAudioContext() {
    try {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      console.log('[TtsClient] Audio context initialized');
    } catch (error) {
      console.error('[TtsClient] Error initializing audio context', error);
    }
  }
  
  /**
   * Speak the given text
   * @param {string} text - Text to speak
   * @param {Object} callbacks - Callback functions
   * @param {Function} callbacks.success - Success callback
   * @param {Function} callbacks.failure - Failure callback
   */
  speak(text, callbacks) {
    if (!text || text.trim() === '') {
      if (callbacks && callbacks.failure) {
        callbacks.failure(new Error('Empty text'));
      }
      return;
    }
    
    try {
      // Stop current speech if any
      if (this.isSpeaking) {
        this.stop();
      }
      
      console.log('[TtsClient] Speaking text:', text);
      
      // Notify speech state change
      this.isSpeaking = true;
      if (typeof window.onSpeechStateChange === 'function') {
        window.onSpeechStateChange(true);
      }
      
      // Create TTS request
      const requestData = {
        text: text,
        appId: this.appId,
        // Additional TTS parameters can be added here
      };
      
      // Send TTS request
      fetch(this.ttsEngineUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestData)
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`TTS request failed with status ${response.status}`);
        }
        return response.arrayBuffer();
      })
      .then(arrayBuffer => {
        // Play the audio
        this._playAudioArrayBuffer(arrayBuffer);
        
        if (callbacks && callbacks.success) {
          callbacks.success();
        }
      })
      .catch(error => {
        console.error('[TtsClient] Error in TTS request', error);
        this.isSpeaking = false;
        
        if (typeof window.onSpeechStateChange === 'function') {
          window.onSpeechStateChange(false);
        }
        
        if (callbacks && callbacks.failure) {
          callbacks.failure(error);
        }
      });
    } catch (error) {
      console.error('[TtsClient] Error speaking text', error);
      this.isSpeaking = false;
      
      if (typeof window.onSpeechStateChange === 'function') {
        window.onSpeechStateChange(false);
      }
      
      if (callbacks && callbacks.failure) {
        callbacks.failure(error);
      }
    }
  }
  
  /**
   * Play audio from ArrayBuffer
   * @private
   * @param {ArrayBuffer} arrayBuffer - Audio data as ArrayBuffer
   */
  _playAudioArrayBuffer(arrayBuffer) {
    if (!this.audioContext) {
      this._initAudioContext();
    }
    
    try {
      // Decode audio data
      this.audioContext.decodeAudioData(arrayBuffer, (audioBuffer) => {
        // Create audio source
        const source = this.audioContext.createBufferSource();
        source.buffer = audioBuffer;
        source.connect(this.audioContext.destination);
        
        // Store current audio source
        this.audioSource = source;
        
        // Set up event handlers
        source.onended = () => {
          this.isSpeaking = false;
          this.audioSource = null;
          
          // Notify speech state change
          if (typeof window.onSpeechStateChange === 'function') {
            window.onSpeechStateChange(false);
          }
          
          console.log('[TtsClient] Speech completed');
        };
        
        // Start playback
        source.start(0);
      }, (error) => {
        console.error('[TtsClient] Error decoding audio data', error);
        this.isSpeaking = false;
        
        if (typeof window.onSpeechStateChange === 'function') {
          window.onSpeechStateChange(false);
        }
      });
    } catch (error) {
      console.error('[TtsClient] Error playing audio', error);
      this.isSpeaking = false;
      
      if (typeof window.onSpeechStateChange === 'function') {
        window.onSpeechStateChange(false);
      }
    }
  }
  
  /**
   * Stop the current speech
   */
  stop() {
    if (!this.isSpeaking) return;
    
    try {
      // Stop audio source if it exists
      if (this.audioSource) {
        this.audioSource.stop();
        this.audioSource.disconnect();
        this.audioSource = null;
      }
      
      this.isSpeaking = false;
      
      // Notify speech state change
      if (typeof window.onSpeechStateChange === 'function') {
        window.onSpeechStateChange(false);
      }
      
      console.log('[TtsClient] Speech stopped');
    } catch (error) {
      console.error('[TtsClient] Error stopping speech', error);
    }
  }
  
  /**
   * Dispose TTS client
   */
  dispose() {
    this.stop();
    
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
    }
    
    console.log('[TtsClient] Disposed');
  }
}

// Register classes in the global scope
window.RtcClient = RtcClient;
window.AsrClient = AsrClient;
window.TtsClient = TtsClient; 