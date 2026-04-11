/**
 * Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd.
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

import { audio } from '@kit.AudioKit';
import fs, { WriteOptions } from '@ohos.file.fs';
import { Log } from '@ohos/flutter_ohos';
import { t_CODEC, t_RECORDER_STATE } from '../plugin/FlutterSoundTypes';
import { FlutterSoundRecorderCallback } from '../plugin/FlutterSoundRecorderCallback';
import { IRecorder } from './IRecorder';

const TAG = "FlutterAudioCaptureRecorder"

export class FlutterAudioCaptureRecorder implements IRecorder {
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
  private capturer: audio.AudioCapturer | null = null
  private audioFile: fs.File | null = null
  private bufferSize: number = 0
  private callback: FlutterSoundRecorderCallback | null = null;
  private isStream: boolean = false;
  private isWav = false;
  private numChannels = 0;
  private sampleRate = 0;
  private maxAmplitude: number = 0;

  constructor(cb: FlutterSoundRecorderCallback, isStream: boolean) {
    this.callback = cb;
    this.isStream = isStream;
  }

  async startRecord(numChannels: number, sampleRate: number, bitRate: number, codec: t_CODEC, path: string,
    audioSource: number): Promise<void> {
    try{
      let audioSamplingRate = FlutterAudioCaptureRecorder.AUDIO_SAMPLING_RATE[sampleRate];
      let audioChannel = FlutterAudioCaptureRecorder.AUDIO_CHANNEL[numChannels];
      if (!audioSamplingRate || !audioChannel) {
        throw new Error("numChannels or sampleRate not supported");
      }
      this.isWav = false;
      this.numChannels = audioChannel;
      this.sampleRate = audioSamplingRate;
      this.bufferSize = 0;
      let audioSampleFormat = audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE;
      if (codec === t_CODEC.pcmFloat32) {
        audioSampleFormat = audio.AudioSampleFormat.SAMPLE_FORMAT_F32LE;
      }else if (codec === t_CODEC.pcm16WAV){
        this.isWav = true;
      }
      if (!this.isStream) {
        this.audioFile = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        if (this.isWav) {
          let headerBuffer = this.writeWavHeader(
            this.sampleRate,
            16,
            this.numChannels,
            0);                     //初始化为0
          fs.writeSync(this.audioFile?.fd, headerBuffer);
        }
      }
      let audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audioSamplingRate, // 采样率
        channels: audioChannel, // 通道
        sampleFormat: audioSampleFormat, // 采样格式
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW // 编码格式
      }
      let audioCapturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
      let audioCapturerOptions: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo
      }
      if (this.capturer != null) {
        Log.w(TAG, "capturer is not nullptr");
        await this.capturer.release();
        this.capturer = null;
      }
      this.capturer = await audio.createAudioCapturer(audioCapturerOptions);
      this.setAudioCapturerCallback();
    }catch (e) {
      throw new Error(e);
    }
  }

  async stopRecord(): Promise<void> {
    if (this.capturer == null) {
      return;
    }
    await this.capturer.stop();
    await this.capturer.release();
    this.capturer = null;
    if (this.audioFile) {
      if (this.isWav) {
        // 2. 更新文件头数据大小
        let headerBuffer = this.writeWavHeader(
          this.sampleRate,
          16,
          this.numChannels,
          this.bufferSize
        );

        // 覆盖写入更新后的文件头
        fs.lseek(this.audioFile.fd, 0, fs.WhenceType.SEEK_SET);  // 跳转到文件头
        fs.writeSync(this.audioFile.fd, headerBuffer);
      }
      fs.closeSync(this.audioFile);
    }
  }

  async pauseRecord(): Promise<boolean> {
    if (this.capturer == null) {
      return false;
    }
    await this.capturer.stop();
    return true;

  }

  async resumeRecord(): Promise<boolean> {
    if (this.capturer == null) {
      return false;
    }
    await this.capturer.start();
    return true;
  }

  get state(): t_RECORDER_STATE {
    switch (this.capturer?.state) {
      case audio.AudioState.STATE_NEW:
      case audio.AudioState.STATE_PREPARED:
      case audio.AudioState.STATE_RUNNING:
        return t_RECORDER_STATE.RECORDER_IS_RECORDING;
      case audio.AudioState.STATE_INVALID:
      case audio.AudioState.STATE_STOPPED:
      case audio.AudioState.STATE_RELEASED:
        return t_RECORDER_STATE.RECORDER_IS_STOPPED;
      case audio.AudioState.STATE_PAUSED:
        return t_RECORDER_STATE.RECORDER_IS_PAUSED;
      default:
        return t_RECORDER_STATE.RECORDER_IS_STOPPED;
    }
  }

  private setAudioCapturerCallback(): void {
    this.capturer?.on('stateChange', async (state: audio.AudioState) => {
      Log.i(TAG, "stateChange: " + state)
      switch (state) {
        case audio.AudioState.STATE_INVALID:
          break;
        case audio.AudioState.STATE_NEW:
          break;
        case audio.AudioState.STATE_PREPARED:
          await this.capturer?.start();
          break;
        case audio.AudioState.STATE_STOPPED:
        case audio.AudioState.STATE_RELEASED:
          break;
        case audio.AudioState.STATE_PAUSED:
          break;
        case audio.AudioState.STATE_RUNNING:
          break;
      }
    })
    this.capturer?.on('readData', (buffer: ArrayBuffer) => {
      if (this.isStream) {
        this.recordingData(buffer)
      } else {
        let options: WriteOptions = {
          offset: this.bufferSize,
          length: buffer.byteLength
        }
        fs.writeSync(this.audioFile?.fd, buffer, options)
        this.bufferSize += buffer.byteLength
      }

      const audioData = new Int16Array(buffer);
      for (let i = 0; i < audioData.length; i++) {
        const amplitude = Math.abs(audioData[i]);
        if (amplitude > this.maxAmplitude) {
          this.maxAmplitude = amplitude;
        }
      }
    })
  }

  public recordingData(data: ArrayBuffer): void {
    this.callback?.recordingData(data);
  }

  async getMaxAmplitude(): Promise<number> {
    let temp = this.maxAmplitude;
  	this.maxAmplitude = 0;
    return temp;
  }

  private writeWavHeader(sampleRate: number, bitDepth: number, channels: number, dataSize: number): ArrayBuffer {
    const buffer = new ArrayBuffer(44);
    const view = new DataView(buffer);

    // RIFF Chunk (12字节)
    this.writeString(view, 0, 'RIFF');
    view.setUint32(4, 36 + dataSize, true);  // 总文件大小-8
    this.writeString(view, 8, 'WAVE');

    // fmt Subchunk (24字节)
    this.writeString(view, 12, 'fmt ');
    view.setUint32(16, 16, true);             // fmt块大小
    view.setUint16(20, 1, true);              // PCM格式=1
    view.setUint16(22, channels, true);       // 声道数
    view.setUint32(24, sampleRate, true);     // 采样率
    view.setUint32(28, sampleRate * channels * (bitDepth/8), true);  // 字节率
    view.setUint16(32, channels * (bitDepth/8), true);  // 块对齐
    view.setUint16(34, bitDepth, true);       // 位深度

    // data Subchunk (8字节)
    this.writeString(view, 36, 'data');
    view.setUint32(40, dataSize, true);       // 音频数据大小

    return buffer;
  }

  writeString(view: DataView, offset: number, str: string) {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  }
}
