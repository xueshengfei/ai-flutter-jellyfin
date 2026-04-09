/*
 * Copyright (C) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import audio from '@ohos.multimedia.audio';
import { BusinessError } from '@ohos.base';
import fs, { WriteOptions } from '@ohos.file.fs';

import { IPlayer } from './IPlayer';
import { Log } from '@ohos/flutter_ohos';
import { t_CODEC, t_PLAYER_STATE, t_PLAY_BACK_SPEED } from '../plugin/FlutterSoundTypes';
import { FlutterSoundPlayerCallback } from '../plugin/FlutterSoundPlayerCallback';

import {asset} from '@kit.AssetStoreKit';
import { FlutterPlayer } from './FlutterPlayer';
import { DynamicUint8Buffer } from '../utils/DynamicUint8Buffer';
import { systemDateTime } from '@kit.BasicServicesKit';

const TAG = 'FlutterAudioRenderer';

export class FlutterAudioRenderer implements IPlayer {

    static readonly AUDIO_SAMPLING_RATE: Record<number, audio.AudioSamplingRate> = {
        8000: audio.AudioSamplingRate.SAMPLE_RATE_8000,
        11025: audio.AudioSamplingRate.SAMPLE_RATE_11025,
        12000: audio.AudioSamplingRate.SAMPLE_RATE_12000,
        16000: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        22050: audio.AudioSamplingRate.SAMPLE_RATE_22050,
        24000: audio.AudioSamplingRate.SAMPLE_RATE_24000,
        32000: audio.AudioSamplingRate.SAMPLE_RATE_32000,
        44100: audio.AudioSamplingRate.SAMPLE_RATE_44100,
        48000: audio.AudioSamplingRate.SAMPLE_RATE_48000,
        64000: audio.AudioSamplingRate.SAMPLE_RATE_64000,
        88200: audio.AudioSamplingRate.SAMPLE_RATE_88200,
        96000: audio.AudioSamplingRate.SAMPLE_RATE_96000,
        176400: audio.AudioSamplingRate.SAMPLE_RATE_176400,
        192000: audio.AudioSamplingRate.SAMPLE_RATE_192000,
    }

    static readonly AUDIO_CHANNEL: Record<number, audio.AudioChannel> = {
        1: audio.AudioChannel.CHANNEL_1,
        2: audio.AudioChannel.CHANNEL_2,
        3: audio.AudioChannel.CHANNEL_3,
        4: audio.AudioChannel.CHANNEL_4,
        5: audio.AudioChannel.CHANNEL_5,
        6: audio.AudioChannel.CHANNEL_6,
        7: audio.AudioChannel.CHANNEL_7,
        8: audio.AudioChannel.CHANNEL_8,
        9: audio.AudioChannel.CHANNEL_9,
        10: audio.AudioChannel.CHANNEL_10,
        12: audio.AudioChannel.CHANNEL_12,
        14: audio.AudioChannel.CHANNEL_14,
        16: audio.AudioChannel.CHANNEL_16,
    }

    static readonly FEED_BUFFER_SIZE = 10240;
    static readonly BLOCK_SIZE = 4096;

    private renderModel: audio.AudioRenderer | null = null;
    private callback: FlutterSoundPlayerCallback | null = null;

    private rendererVolume: number = -1;
    private rendererSpeed: number = -1;

    private bufferSize: number = 0;
    private options: number = 0;
    private dataBuffer: Uint8Array | null = null;
    private sourceArray: DynamicUint8Buffer | null = null;
    private file: fs.File | null = null;
    private playCompleted : boolean = false;

    private pauseTime = 0;
    private startPauseTime = -1;
    private systemTime = 0;

    private writeDataCallback = (buffer: ArrayBuffer) => {
        if (this.playCompleted) {
            return audio.AudioDataCallbackResult.INVALID;
        }
        this.bufferSize = buffer.byteLength;
        let writeDataBuffer = new Uint8Array(buffer);
        if (this.file) {
            let options: WriteOptions = {
                offset: this.options,
                length: this.bufferSize
            };
            try {
                let bufferLength = fs.readSync(this.file?.fd , buffer, options);
                this.options += this.bufferSize;
                if (bufferLength < this.bufferSize) {
                    writeDataBuffer.fill(0, bufferLength);
                    this.playCompleted = true;
                }
                return audio.AudioDataCallbackResult.VALID;
            } catch (error) {
                Log.e(TAG, 'Reading file error: ' + error);
                return audio.AudioDataCallbackResult.INVALID;
            }
        }
        if (this.dataBuffer) {
            if (this.options + this.bufferSize > this.dataBuffer.length) {
                writeDataBuffer.fill(0);
                writeDataBuffer.set(this.dataBuffer.subarray(this.options,this.dataBuffer.length));
                this.playCompleted = true;
            } else {
                writeDataBuffer.set(this.dataBuffer.subarray(this.options, this.options + this.bufferSize))
            }
            return audio.AudioDataCallbackResult.VALID;
        }
        if (this.sourceArray && this.sourceArray.dataLength > 0) {
            if (this.sourceArray.dataLength < this.bufferSize) {
                writeDataBuffer.fill(0);
            }
            let uint8buffer = this.sourceArray.read(this.bufferSize);
            writeDataBuffer.set(uint8buffer);
            if (this.sourceArray.dataLength < this.bufferSize) {
                this.callback?.needSomeFood(FlutterAudioRenderer.BLOCK_SIZE);
            }
            return audio.AudioDataCallbackResult.VALID;
        }
        return audio.AudioDataCallbackResult.INVALID;
    }

    constructor(cb: FlutterSoundPlayerCallback) {
        this.callback = cb;
    }

    async startPlayer(codec: t_CODEC, path: string, dataBuffer: Uint8Array, numChannels: number,
        sampleRate: number): Promise<boolean> {
        let audioSamplingRate = FlutterAudioRenderer.AUDIO_SAMPLING_RATE[sampleRate];
        let audioChannel = FlutterAudioRenderer.AUDIO_CHANNEL[numChannels];
        if (!audioSamplingRate || !audioChannel) {
            return false;
        }

        let audioSampleFormat = audio.AudioSampleFormat.SAMPLE_FORMAT_INVALID
        if (codec === t_CODEC.pcm16) {
            audioSampleFormat = audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE
        } else if (codec === t_CODEC.pcmFloat32) {
            audioSampleFormat = audio.AudioSampleFormat.SAMPLE_FORMAT_F32LE
        } else {
            return false;
        }

        let audioStreamInfo: audio.AudioStreamInfo = {
            samplingRate: audioSamplingRate, // 采样率
            channels: audioChannel, // 通道数
            sampleFormat: audioSampleFormat, // 采样格式
            encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW // 编码样式
        };

        let audioRendererInfo: audio.AudioRendererInfo = {
            usage: audio.StreamUsage.STREAM_USAGE_MUSIC, // 音频流使用类型
            rendererFlags: 0 // 音频渲染器标志
        };

        let audioRenderOptions: audio.AudioRendererOptions = {
            streamInfo: audioStreamInfo,
            rendererInfo: audioRendererInfo
        };

        this.renderModel = await audio.createAudioRenderer(audioRenderOptions);

        if (this.renderModel) {
            this.playCompleted = false;
            this.options = 0;
            if (path.length !== 0) {
                this.file = fs.openSync(path, fs.OpenMode.READ_ONLY);
            } else if (dataBuffer) {
                this.dataBuffer = dataBuffer;
            } else {
                this.sourceArray = new DynamicUint8Buffer(FlutterAudioRenderer.FEED_BUFFER_SIZE);
            }
            (this.renderModel as audio.AudioRenderer).on('writeData', this.writeDataCallback);
            this.setPlayerCallback();
        }

        this.pauseTime = 0;
        this.startPauseTime = -1;
        this.systemTime = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false);
        return true;
    }

    async stopPlayer(): Promise<void> {
        if (!this.renderModel) {
            return;
        }

        try {
            await this.renderModel.stop();
            await this.renderModel.release();
        } catch (err) {
            Log.e(TAG, "AudioRenderer stop failed, error:" + JSON.stringify(err));
        }
        this.renderModel = null;
    }

    async pausePlayer(): Promise<void> {
        this.startPauseTime = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false);
        await this.renderModel?.pause();
    }

    async resumePlayer(): Promise<void> {
        if (this.startPauseTime >= 0) {
            this.pauseTime += systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false) - this.startPauseTime;
        }
        this.startPauseTime = -1;
        await this.renderModel?.start();
    }

    seekTo(milliseconds: number): void {}

    setVolume(volume: number): void {
        this.rendererVolume = volume;
        if (this.rendererVolume >= 0) {
            this.renderModel?.setVolume(this.rendererVolume);
        }
    }

    setSpeed(speed: number): void {
        this.rendererSpeed = speed;
        if (this.rendererSpeed >= 0.25 && this.rendererSpeed <= 4.0) {
            this.renderModel?.setSpeed(this.rendererSpeed);
        }
        return;
    }

    get duration(): number {
        return this.position;
    }

    get position(): number {
        let time = 0;
        if (this.startPauseTime >= 0)
            time = this.startPauseTime - this.systemTime - this.pauseTime ;
        else
            time = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false)
                - this.systemTime - this.pauseTime;
        return time;
    }

    get state(): t_PLAYER_STATE {
        switch (this.renderModel?.state) {
            case audio.AudioState.STATE_INVALID:
            case audio.AudioState.STATE_NEW:
            case audio.AudioState.STATE_PREPARED:
            case audio.AudioState.STATE_STOPPED:
            case audio.AudioState.STATE_RELEASED:
                return t_PLAYER_STATE.PLAYER_IS_STOPPED;
            case audio.AudioState.STATE_RUNNING:
                return t_PLAYER_STATE.PLAYER_IS_PLAYING;
            case audio.AudioState.STATE_PAUSED:
                return t_PLAYER_STATE.PLAYER_IS_PAUSED;
            default:
                return t_PLAYER_STATE.PLAYER_IS_STOPPED;
        }
    }

    feed(data: Uint8Array): number {
        if (this.sourceArray) {
            this.sourceArray.write(data);
            return this.sourceArray.dataLength > this.bufferSize ? 0 : data.byteLength;
        }
        return 0;
    }

    isPlaying(): boolean {
        return this.renderModel?.state === audio.AudioState.STATE_RUNNING;
    }

    private setPlayerCallback(): void {
        this.renderModel?.on('stateChange', async (state: audio.AudioState) => {
            switch (state) {
                case audio.AudioState.STATE_INVALID:
                    break;
                case audio.AudioState.STATE_NEW:
                    break;
                case audio.AudioState.STATE_PREPARED:
                    break;
                case audio.AudioState.STATE_RUNNING:
                    this.setPlayerConfig();
                    this.callback?.startPlayerCompleted(true, 0);
                    break;
                case audio.AudioState.STATE_STOPPED:
                    break;
                case audio.AudioState.STATE_RELEASED:
                    break;
                case audio.AudioState.STATE_PAUSED:
                    break;
                default:
                    break;
            }
        });
    }

    private async setPlayerConfig(): Promise<void> {
        if (this.rendererVolume >= 0) {
            this.renderModel?.setVolume(this.rendererVolume);
        }

        if (this.rendererSpeed >= 0.25 && this.rendererSpeed <= 4.0) {
            this.renderModel?.setSpeed(this.rendererSpeed);
        }
    }
}
