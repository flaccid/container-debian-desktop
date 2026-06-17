/**
 * Audio plugin for NoVNC
 * A drop-in plugin for out-of-band audio playback
 *
 * Copyright (C) 2023 Mehrzad Asri
 * Copyright (C) 2026 flaccid/container-debian-desktop
 * Licensed under MPL 2.0
 *
 * Forked from https://github.com/me-asri/noVNC-audio-plugin
 * Modifications: defaults tuned for container-debian-desktop project
 * (auto-enabled, /audio/ path, disabled autoconnect guard).
 */

import NVUI from "./app/ui.js";

class MediaSourcePlayer {
    static #BUFFER_MIN_REMAIN = 30;
    static #DRIFT_CHECK_INTERVAL = 5000;
    static #DRIFT_MAX_TOLERANCE = 1.0;

    mediaSource;
    sourceBuffer;
    #directFeed = true;
    #dataQueue = [];
    #attachedEl;
    #driftCheckTimer;

    #onPlayCallback = (event) => {
        const elem = event.target;
        if (this.sourceBuffer.buffered.length > 0) {
            elem.currentTime = this.sourceBuffer.buffered.end(0);
        }
        elem.playbackRate = 1.003;
    };

    constructor(mime) {
        this.mediaSource = new MediaSource();
        this.mediaSource.addEventListener('sourceopen', () => {
            this.sourceBuffer = this.mediaSource.addSourceBuffer(mime);
            this.sourceBuffer.mode = 'sequence';
            this.sourceBuffer.addEventListener('updateend', () => {
                if (this.sourceBuffer.updating) return;
                if (this.#dataQueue.length == 0) {
                    this.#directFeed = true;
                    return;
                }
                const data = this.#dataQueue[0];
                try {
                    this.sourceBuffer.appendBuffer(data);
                    this.#dataQueue.shift();
                } catch (err) {
                    if (err.name == 'QuotaExceededError') {
                        console.log('SourceBuffer quota exceeded. Emptying buffer.');
                        this.#emptyBuffer();
                        if (!this.sourceBuffer.updating) {
                            this.sourceBuffer.appendBuffer(data);
                            this.#dataQueue.shift();
                        }
                        return;
                    }
                    throw err;
                }
            });
        }, { once: true });
    }

    async attach(element) {
        if (this.#attachedEl) throw new Error('Already attached to an element');
        element.src = URL.createObjectURL(this.mediaSource);
        this.#attachedEl = element;
        return new Promise((resolve) => {
            this.mediaSource.addEventListener('sourceopen', () => {
                element.addEventListener('play', this.#onPlayCallback);
                this.#driftCheckTimer = setInterval(() => this.#checkDrift(), MediaSourcePlayer.#DRIFT_CHECK_INTERVAL);
                resolve();
            }, { once: true });
        });
    }

    async detach() {
        if (this.#attachedEl) {
            this.#attachedEl.removeEventListener('play', this.#onPlayCallback);
            this.#attachedEl.playbackRate = 1;
            await this.#attachedEl.pause();
            this.#attachedEl.removeAttribute('src');
            this.#attachedEl.currentTime = 0;
            this.#attachedEl = null;
        }
        if (this.#driftCheckTimer) {
            clearInterval(this.#driftCheckTimer);
            this.#driftCheckTimer = null;
        }
    }

    feed(data) {
        if (!this.#attachedEl) throw new Error('Not attached to any elements');
        if (this.mediaSource.readyState != 'open') throw new Error(`Bad MediaSource state: ${this.mediaSource.readyState}`);
        if (this.#directFeed) {
            try {
                this.sourceBuffer.appendBuffer(data);
            } catch (err) {
                if (err.name == 'QuotaExceededError') {
                    this.#emptyBuffer();
                    if (this.sourceBuffer.updating) {
                        this.#directFeed = false;
                        this.#dataQueue.push(data);
                    } else {
                        this.sourceBuffer.appendBuffer(data);
                    }
                }
            }
            if (this.sourceBuffer.updating) this.#directFeed = false;
        } else {
            this.#dataQueue.push(data);
        }
    }

    #emptyBuffer() {
        const bufferEnd = this.sourceBuffer.buffered.end(0);
        const removeEnd = bufferEnd - MediaSourcePlayer.#BUFFER_MIN_REMAIN;
        this.sourceBuffer.remove(0, (removeEnd <= 0) ? 1 : removeEnd);
    }

    #checkDrift() {
        if (this.#attachedEl.paused) return;
        if (this.sourceBuffer.buffered.length == 0) return;
        const drift = this.sourceBuffer.buffered.end(0) - this.#attachedEl.currentTime;
        if (drift > MediaSourcePlayer.#DRIFT_MAX_TOLERANCE) {
            console.log(`${drift} drift exceeding tolerance, resyncing`);
            this.#attachedEl.currentTime = this.sourceBuffer.buffered.end(0);
        }
    }
}

const NV = {
    optionEls: [],
    getMainSettingsList() {
        return document.querySelector('#noVNC_settings ul');
    },
    addSubCategory(parent, label) {
        const settingsItem = document.createElement('li');
        const expanderDiv = document.createElement('div');
        expanderDiv.classList.add('noVNC_expander');
        expanderDiv.innerHTML = label;
        expanderDiv.addEventListener('click', NVUI.toggleExpander);
        const childDiv = document.createElement('div');
        const listDiv = document.createElement('ul');
        childDiv.appendChild(listDiv);
        settingsItem.appendChild(expanderDiv);
        settingsItem.appendChild(childDiv);
        parent.appendChild(settingsItem);
        return listDiv;
    },
    addInput(settingsList, label, name, defaultVal = null, type = 'text', title = null) {
        const settingItem = document.createElement('li');
        const settingLabel = document.createElement('label');
        const settingInput = document.createElement('input');
        settingInput.id = `noVNC_setting_${name}`;
        settingInput.type = type;
        if (title) { settingLabel.title = title; settingInput.title = title; }
        settingItem.appendChild(settingLabel);
        if (type == 'checkbox') {
            settingLabel.appendChild(settingInput);
        } else {
            settingLabel.htmlFor = settingInput.id;
            settingItem.appendChild(settingInput);
        }
        settingLabel.appendChild(document.createTextNode(label));
        settingInput.addEventListener('change', () => NVUI.saveSetting(name));
        settingsList.appendChild(settingItem);
        NVUI.initSetting(name, defaultVal);
        this.optionEls.push(settingInput);
        return settingInput;
    },
    addDropdown(settingsList, label, name, values, defaultVal = null, title = null) {
        const settingItem = document.createElement('li');
        const settingLabel = document.createElement('label');
        settingLabel.innerText = label;
        const settingSelect = document.createElement('select');
        settingSelect.id = `noVNC_setting_${name}`;
        settingLabel.htmlFor = settingSelect.id;
        if (title) { settingLabel.title = title; settingSelect.title = title; }
        settingItem.appendChild(settingLabel);
        settingItem.appendChild(settingSelect);
        settingSelect.addEventListener('change', () => NVUI.saveSetting(name));
        for (const [name, val] of Object.entries(values)) {
            const option = document.createElement('option');
            option.text = name;
            option.value = val;
            settingSelect.appendChild(option);
        }
        settingsList.appendChild(settingItem);
        NVUI.initSetting(name, defaultVal);
        this.optionEls.push(settingSelect);
        return settingSelect;
    },
    addLineBreak(settingsList) {
        const settingItem = document.createElement('li');
        const lineBreak = document.createElement('hr');
        settingItem.appendChild(lineBreak);
        settingsList.appendChild(settingItem);
        return lineBreak;
    },
    observeState(state, callback, once = false) {
        const doc = document.documentElement;
        const observer = new MutationObserver(async () => {
            if ((state == 'disconnected' && doc.classList.length == 0) || doc.classList.contains(`noVNC_${state}`)) {
                await callback(observer);
                if (once) observer.disconnect();
            }
        });
        observer.observe(doc, { attributes: true, attributeFilter: ['class'] });
    },
    disableOptions(disable = true) {
        for (const optionEl of this.optionEls) { optionEl.disabled = disable; }
    }
};

const AudioProxy = {
    handshake(socket, codec = 'opus', bitrate = 96000, sampleRate = 48000, secret = null) {
        const textEnc = new TextEncoder();
        const textDec = new TextDecoder();
        let handshakeMsg = `CD:${codec}\nBR:${bitrate}\nSR:${sampleRate}\n\n`;
        if (secret != null) handshakeMsg += `sec:${secret}`;
        handshakeMsg += `\n`;
        socket.send(textEnc.encode(handshakeMsg));
        return new Promise((resolve) => {
            socket.addEventListener('message', (msg) => {
                const resp = textDec.decode(msg.data).trim();
                if (resp == 'READY') resolve();
                else if (resp.startsWith('ERR:')) throw new Error(`Proxy error: ${resp.substring(4)}`);
                else throw new Error('Protocol error');
            }, { once: true });
        });
    }
};

const AudioPlugin = {
    msp: null,
    ws: null,
    audioEl: null,

    async onClickPlayHandler() {
        try {
            await this.audioEl.play();
        } catch (err) {
            if (err.name != 'AbortError') {
                NVUI.showStatus(`Audio playback failed: ${err.message}`, 'error');
            }
            await this.stopAudio();
        }
    },

    async startAudio() {
        if (this.msp) return;
        const codec = NVUI.getSetting('audio_codec');
        const bitrate = NVUI.getSetting('audio_bitrate');
        const samplerate = NVUI.getSetting('audio_samplerate');
        let mime;
        switch (codec) {
            case 'opus': mime = 'audio/webm; codecs="opus"'; break;
            case 'aac': mime = 'audio/mp4; codecs="mp4a.40.2"'; break;
            default: throw new Error(`Unsupported codec ${codec}`);
        }
        const wsEncrypt = NVUI.getSetting('audio_encrypt') ?? (window.location.protocol === 'https:');
        const wsSchema = wsEncrypt ? 'wss://' : 'ws://';
        const wsHost = NVUI.getSetting('audio_host') || window.location.hostname;
        const wsPort = NVUI.getSetting('audio_port') || window.location.port || (wsEncrypt ? '443' : '80');
        const wsPath = NVUI.getSetting('audio_path') || 'audio/';
        this.ws = new WebSocket(`${wsSchema}${wsHost}:${wsPort}/${wsPath}`);
        this.ws.binaryType = 'arraybuffer';
        this.ws.addEventListener('error', async () => {
            if (NVUI.connected) NVUI.showStatus('Audio WebSocket connection failed', 'error');
            await this.stopAudio();
        });
        this.ws.addEventListener('close', async () => {
            if (!this.msp) return;
            if (NVUI.connected) NVUI.showStatus('Audio WebSocket connection closed', 'error');
            await this.stopAudio();
        });
        this.ws.addEventListener('open', async () => {
            try {
                this.msp = new MediaSourcePlayer(mime);
                await this.msp.attach(this.audioEl);
            } catch (err) {
                NVUI.showStatus(`MediaSource initialization failed: ${err.message}`);
                await this.stopAudio();
                return;
            }
            try {
                await AudioProxy.handshake(this.ws, codec, bitrate, samplerate);
            } catch (err) {
                NVUI.showStatus(`Audio handshake failed: ${err.message}`, 'error');
                await this.stopAudio();
                return;
            }
            this.ws.addEventListener('message', async (msg) => {
                try {
                    this.msp.feed(msg.data);
                } catch (err) {
                    NVUI.showStatus(`Audio failure: ${err.message}`, 'error');
                    await this.stopAudio();
                }
            });
            document.body.addEventListener('click', async () => this.onClickPlayHandler(), { capture: true, once: true });
        });
    },

    async stopAudio() {
        if (this.msp) { await this.msp.detach(); this.msp = null; }
        if (this.ws) { this.ws.close(); this.ws = null; }
    },

    initUi() {
        this.audioEl = document.createElement('audio');
        this.audioEl.id = 'noVNC_audio';
        document.body.appendChild(this.audioEl);

        const settingsList = NV.getMainSettingsList();
        NV.addLineBreak(settingsList);

        const audioSettings = NV.addSubCategory(settingsList, 'Audio Plugin');
        NV.addInput(audioSettings, 'Enabled', 'audio_enabled', true, 'checkbox', 'Enable audio streaming from the remote desktop');

        NV.addLineBreak(audioSettings);

        NV.addDropdown(audioSettings, 'Codec:', 'audio_codec', {
            'WebM/Opus': 'opus',
            'MP4/AAC': 'aac'
        }, MediaSource.isTypeSupported('audio/webm; codecs="opus"') ? 'opus' : 'aac', 'Audio codec');
        NV.addDropdown(audioSettings, 'Bitrate:', 'audio_bitrate', {
            '64kbps': '64000',
            '96kbps': '96000',
            '128kbps': '128000',
            '192kbps': '192000'
        }, '96000', 'Audio bitrate');
        NV.addDropdown(audioSettings, 'Sample Rate:', 'audio_samplerate', {
            '44.1kHz': '44100',
            '48kHz': '48000',
        }, '48000', 'Audio sample rate');

        NV.addLineBreak(audioSettings);
        NV.addInput(audioSettings, 'Secret:', 'audio_secret', null, 'password', 'Optional connection secret (does NOT provide encryption)');

        const audioWsSettings = NV.addSubCategory(audioSettings, 'WebSocket');
        const pagePort = window.location.port || (window.location.protocol === 'https:' ? '443' : '80');
        NV.addInput(audioWsSettings, 'Encrypt', 'audio_encrypt', window.location.protocol === 'https:', 'checkbox', 'Use encrypted WebSocket connection');
        NV.addInput(audioWsSettings, 'Host:', 'audio_host', window.location.hostname, 'text', 'WebSocket host for audio proxy');
        NV.addInput(audioWsSettings, 'Port:', 'audio_port', pagePort, 'text', 'WebSocket port for audio proxy');
        NV.addInput(audioWsSettings, 'Path:', 'audio_path', 'audio/', 'text', 'WebSocket path for audio proxy');
    },

    load() {
        this.initUi();
        const doc = document.documentElement;
        const onConnected = async () => {
            if (!NVUI.getSetting('audio_enabled')) return;
            NV.disableOptions();
            try {
                await this.startAudio();
            } catch (err) {
                NVUI.showStatus(`Audio setup failed: ${err.message}`, 'error');
            }
        };
        const onDisconnected = async () => {
            await this.stopAudio();
            NV.disableOptions(false);
        };
        // Observe future connect/disconnect state changes
        NV.observeState('connected', onConnected);
        NV.observeState('disconnected', onDisconnected);
        // If already connected (noVNC loaded before this script), start immediately
        if (doc.classList.contains('noVNC_connected')) {
            onConnected();
        } else if (NVUI.rfb) {
            // RFB object exists but not yet marked connected — listen directly
            NVUI.rfb.addEventListener('connect', onConnected, { once: true });
        } else {
            // Retry in case noVNC is still initializing
            const retry = setInterval(() => {
                if (doc.classList.contains('noVNC_connected') || (NVUI.rfb && NVUI.rfb._rfbConnectionState === 'connected')) {
                    clearInterval(retry);
                    onConnected();
                }
            }, 200);
            setTimeout(() => clearInterval(retry), 10000);
        }
    }
};

window.addEventListener('load', () => AudioPlugin.load());
