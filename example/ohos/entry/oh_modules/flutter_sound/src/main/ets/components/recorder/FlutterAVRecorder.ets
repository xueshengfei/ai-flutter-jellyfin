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
import { IRecorder } from './IRecorder';
import { media } from '@kit.MediaKit';
import fs from '@ohos.file.fs';
import { Log } from '@ohos/flutter_ohos';
import { BusinessError } from '@kit.BasicServicesKit';
import { t_CODEC, t_RECORDER_STATE } from '../plugin/FlutterSoundTypes';
import { FlutterSoundRecorderCallback } from '../plugin/FlutterSoundRecorderCallback';

const TAG = 'FlutterAVRecorder'
export class FlutterAVRecorder implements IRecorder {
  private avRecorder: media.AVRecorder | null = null
  private audioFile: fs.File | null = null
  private avProfile: media.AVRecorderProfile | null = null
  private avConfig: media.AVRecorderConfig | null = null
  private callback: FlutterSoundRecorderCallback | null = null;

  constructor(cb: FlutterSoundRecorderCallback) {
    this.callback = cb;
  }

  get state(): t_RECORDER_STATE {
    switch (this.avRecorder?.state) {
      case "idle":
      case "prepared":
      case "released":
      case "error":
      case "stopped":
        return t_RECORDER_STATE.RECORDER_IS_STOPPED
      case "paused":
        return t_RECORDER_STATE.RECORDER_IS_PAUSED
      case "started":
        return t_RECORDER_STATE.RECORDER_IS_RECORDING
      default :
        return t_RECORDER_STATE.RECORDER_IS_STOPPED
    }
  }

  async startRecord(numChannels: number, sampleRate: number, bitRate: number,
    codec: t_CODEC, path: string, audioSource: number): Promise<void> {

    let audioCodec = media.CodecMimeType.AUDIO_AAC;
    let fileFormat = media.ContainerFormatType.CFT_MPEG_4A;
    if (codec === t_CODEC.mp3) {
      audioCodec = media.CodecMimeType.AUDIO_MP3;
      fileFormat = media.ContainerFormatType.CFT_MP3;
    } else if (codec === t_CODEC.aacMP4) {
      audioCodec = media.CodecMimeType.AUDIO_AAC;
      fileFormat = media.ContainerFormatType.CFT_MPEG_4;
    } else if (codec === t_CODEC.amrNB) {
      audioCodec = media.CodecMimeType.AUDIO_AMR_NB;
      fileFormat = media.ContainerFormatType.CFT_AMR;
    } else if (codec === t_CODEC.amrWB) {
      audioCodec = media.CodecMimeType.AUDIO_AMR_WB;
      fileFormat = media.ContainerFormatType.CFT_AMR;
    }
    this.avProfile = {
      audioBitrate: bitRate,
      audioChannels: numChannels,
      audioSampleRate: sampleRate,
      audioCodec: audioCodec,
      fileFormat: fileFormat
    }
    try {
      this.audioFile = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      this.avConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC, //ohos only support MIC now
        profile: this.avProfile,
        url: "fd://" + this.audioFile.fd.toString()
      }
      if(this.avRecorder != null) {
        await this.avRecorder.release();
        this.avRecorder = null;
      }
      this.avRecorder = await media.createAVRecorder();
      this.setAVRecorderCallback();
      await this.avRecorder?.prepare(this.avConfig)
      await this.avRecorder?.start();
    }catch (e) {
      throw new Error(e);
    }
  }

  private setAVRecorderCallback(): void {
    this.avRecorder?.on('stateChange', async (state: media.AVRecorderState, reason: media.StateChangeReason) => {
      Log.i(TAG, "stateChange: " + state + " reason: " + reason)
      switch (state) {
        case "idle":
          break
        case "prepared":
          break
        case "released":
        case "error":
        case "stopped":
          break
        case "paused":
          break
        case "started":
          break
      }
    })
    this.avRecorder?.on("error", (err: BusinessError) => {
      Log.e(TAG, "Invoke avRecorder failed, code is:" + err.code + " error: " + err.message)
      this.avRecorder?.reset()
    })
  }

  async pauseRecord(): Promise<boolean> {
    if(this.avRecorder == null) {
      Log.w(TAG, "avRecorder is null");
      return false;
    }
    await this.avRecorder?.pause();
    return true;
  }

  async resumeRecord(): Promise<boolean> {
    if(this.avRecorder == null) {
      Log.w(TAG, "avRecorder is null");
      return false;
    }
    await this.avRecorder?.resume();
    return true;
  }

  async stopRecord(): Promise<void> {
    if(this.avRecorder == null) {
      Log.w(TAG, "avRecorder is null");
      return;
    }
    try {
      await this.avRecorder?.stop();
      this.avRecorder?.off("stateChange");
      this.avRecorder?.off("error");
      await this.avRecorder?.release();
      this.avRecorder = null;
      fs.closeSync(this.audioFile);
    } catch (err) {
      Log.e(TAG, "Error stop AVRecorder " + JSON.stringify(err));
    }
  }

  async getMaxAmplitude(): Promise<number> {
    if(this.avRecorder != null) {
      return await this.avRecorder.getAudioCapturerMaxAmplitude();
    } else {
      return 0;
    }
  }

}