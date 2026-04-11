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
import { Log } from '@ohos/flutter_ohos';
import { FlutterSoundRecorderCallback } from '../plugin/FlutterSoundRecorderCallback';
import { t_AUDIO_SOURCE, t_CODEC, t_RECORDER_STATE } from '../plugin/FlutterSoundTypes';
import { FlutterAudioCaptureRecorder } from './FlutterAudioCaptureRecorder';
import { FlutterAVRecorder } from './FlutterAVRecorder';
import { IRecorder } from './IRecorder'
import { systemDateTime, deviceInfo } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';

const TAG = "FlutterRecorder"

export class FlutterRecorder {
  private recorder: IRecorder | null = null;
  public m_callback: FlutterSoundRecorderCallback | null = null;
  private m_path: string = "";
  private subsDurationMillis: number = 0;
  private intervalID: number = -1;
  private mPauseTime = 0;
  private mStartPauseTime = -1;
  private mStartTime = 0;
  private status: t_RECORDER_STATE = t_RECORDER_STATE.RECORDER_IS_STOPPED;
  private sdkApiVersion = deviceInfo.sdkApiVersion;

  constructor(callback: FlutterSoundRecorderCallback) {
    this.m_callback = callback;
  }

  public async openRecorder(): Promise<boolean> {
    this.m_callback?.openRecorderCompleted(true);
    return true;
  }

  public async closeRecorder(): Promise<void> {
    await this.stop();
    this.status = t_RECORDER_STATE.RECORDER_IS_STOPPED;
    this.m_callback?.closeRecorderCompleted(true);
  }

  public isEncoderSupported(codec: t_CODEC): boolean {
    if (codec === t_CODEC.pcm16 || codec === t_CODEC.pcm16WAV || codec === t_CODEC.mp3 || codec === t_CODEC.aacMP4 ||
      codec === t_CODEC.pcmFloat32 || codec === t_CODEC.aacADTS) {
      return true;
    }
    if (this.sdkApiVersion >= 18 && (codec === t_CODEC.amrNB || codec === t_CODEC.amrWB)) {
      return true;
    }
    return false;
  }

  public getRecorderState(): t_RECORDER_STATE {
    return this.status;
  }

  public async deleteRecord(radical: string): Promise<boolean> {
    let filePath = this.temporayFile(radical);
    if (fs.accessSync(filePath)) {
      fs.unlinkSync(filePath);
      return true;
    } else {
      return false;
    }
  }

  private clearTimer(): void {
    if (this.intervalID != -1) {
      clearInterval(this.intervalID);
    }
  }

  private setTimer(duration: number): void {
    this.clearTimer();
    this.subsDurationMillis = duration;
    if (this.recorder == null || duration == 0) {
      return;
    }
    this.intervalID = setInterval(async () => {
      let time = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false) - this.mStartTime - this.mPauseTime;
      let db = 0;
      if (this.recorder != null) {
        let maxAmplitude = await this.recorder.getMaxAmplitude();
        //calculating the pascal pressure based on the idea that the max amplitude (between 0 and 32767) is  relative to the pressure
        //the value 51805.5336 can be derived from asuming that x=32767=0.6325 Pa and x=1 = 0.00002 Pa (the reference value)
        let ref_pressure = 51805.5336;
        let p = maxAmplitude / ref_pressure;
        let p0 = 0.0002;
        db = 20 * Math.log10(p / p0);
        if (!Number.isFinite(db)) {
          db = 0;
        }
      }
      this.m_callback?.updateRecorderProgressDbPeakLevel(db, time);
    }, duration);
  }

  public async startRecorder(codec: t_CODEC, sampleRate: number, numChannels: number, bitRate: number,
    path: string, audioSource: t_AUDIO_SOURCE, isStream: boolean): Promise<boolean> {
    this.mPauseTime = 0;
    this.mStartPauseTime = -1;
    await this.stop();
    if (codec === t_CODEC.pcm16 || codec === t_CODEC.pcm16WAV || codec === t_CODEC.pcmFloat32) {
      this.recorder = new FlutterAudioCaptureRecorder(this.m_callback!, isStream);
    } else {
      this.recorder = new FlutterAVRecorder(this.m_callback!);
    }
    this.m_path = this.getPath(path);
    try {
      await this.recorder.startRecord(numChannels, sampleRate, bitRate, codec, this.m_path, audioSource);
      this.mStartTime = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false);
      if (this.subsDurationMillis > 0) {
        this.setTimer(this.subsDurationMillis);
      }
    } catch (err) {
      Log.e(TAG, "Error starting recorder " + JSON.stringify(err));
      return false;
    }
    this.status = t_RECORDER_STATE.RECORDER_IS_RECORDING;
    this.m_callback?.startRecorderCompleted(true);
    return true;
  }

  public async stopRecorder(): Promise<void> {
    await this.stop();
    this.m_callback?.stopRecorderCompleted(true, this.m_path);
  }

  public async pauseRecorder(): Promise<void> {
    this.clearTimer();
    await this.recorder?.pauseRecord();
    this.mStartPauseTime = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false);
    this.status = t_RECORDER_STATE.RECORDER_IS_PAUSED;
    this.m_callback?.pauseRecorderCompleted(true);
  }

  public async resumeRecorder(): Promise<void> {
    this.setTimer(this.subsDurationMillis);
    await this.recorder?.resumeRecord();
    if (this.mStartPauseTime >= 0) {
      this.mPauseTime += systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false) - this.mStartPauseTime;
    }
    this.mStartPauseTime = -1;
    this.status = t_RECORDER_STATE.RECORDER_IS_RECORDING;
    this.m_callback?.resumeRecorderCompleted(true);
  }

  public setSubsDurationMillis(durationMillis: number): void {
    this.subsDurationMillis = durationMillis;
    if (this.recorder != null) {
      this.setTimer(this.subsDurationMillis);
    }
  }

  public temporayFile(radical: string): string {
    return getContext(this).cacheDir + "/" + radical;
  }

  private getPath(path: string): string {
    if (path == null) {
      return "";
    } else {
      let isFound = path.includes("/");
      if (!isFound) {
        path = this.temporayFile(path);
      }
      return path;
    }
  }

  private async stop(): Promise<void> {
    try {
      this.clearTimer();
      if (this.recorder != null) {
        await this.recorder.stopRecord();
      }
    } catch (err) {
      Log.e(TAG, "stop error: " + JSON.stringify(err));
    }
    this.recorder = null;
    this.status = t_RECORDER_STATE.RECORDER_IS_STOPPED;
  }
}