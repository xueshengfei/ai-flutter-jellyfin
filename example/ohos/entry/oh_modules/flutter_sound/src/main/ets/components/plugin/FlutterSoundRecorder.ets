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

import { Any, MethodCall } from '@ohos/flutter_ohos';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterSoundManager } from './FlutterSoundManager';
import { FlutterSoundRecorderManager } from './FlutterSoundRecorderManager';
import { FlutterSoundSession } from './FlutterSoundSession';
import { t_AUDIO_SOURCE, t_CODEC, t_RECORDER_STATE } from './FlutterSoundTypes';
import { common } from '@kit.AbilityKit';
import { FlutterSoundRecorderCallback } from './FlutterSoundRecorderCallback';
import { FlutterRecorder } from '../recorder/FlutterRecorder';

const TAG = "FlutterSoundRecorder";

export class FlutterSoundRecorder extends FlutterSoundSession implements FlutterSoundRecorderCallback {
  static ERR_UNKNOWN = "ERR_UNKNOWN";
  static ERR_RECORDER_IS_NULL = "ERR_RECORDER_IS_NULL";
  static ERR_RECORDER_IS_RECORDING = "ERR_RECORDER_IS_RECORDING";
  static context: common.UIAbilityContext | undefined;
  private mRecorder: FlutterRecorder | null = null;

  //====================================================================================================================
  public openRecorderCompleted(success: boolean): void {
    this.invokeMethodWithBoolean("openRecorderCompleted", success, success);
  }

  public closeRecorderCompleted(success: boolean): void {
    this.invokeMethodWithBoolean("closeRecorderCompleted", success, success);
  }

  public stopRecorderCompleted(success: boolean, url: string): void {
    this.invokeMethodWithString("stopRecorderCompleted", success, url);
  }

  public pauseRecorderCompleted(success: boolean): void {
    this.invokeMethodWithBoolean("pauseRecorderCompleted", success, success);
  }

  public resumeRecorderCompleted(success: boolean): void {
    this.invokeMethodWithBoolean("resumeRecorderCompleted", success, success);
  }

  public startRecorderCompleted(success: boolean): void {
    this.invokeMethodWithBoolean("startRecorderCompleted", success, success);
  }

  public updateRecorderProgressDbPeakLevel(dbPeakLevel: number, duration: number) {
    let dic: Map<string, Any> = new Map();
    dic.set("dbPeakLevel", dbPeakLevel);
    dic.set("duration", duration);
    this.invokeMethodWithMap("updateRecorderProgress", true, dic);
  }

  public recordingData(data: ArrayBuffer) {
    let dic: Map<string, Any> = new Map();
    dic.set("recordingData", new Uint8Array(data));
    this.invokeMethodWithMap("recordingData", true, dic);
  }

  //====================================================================================================================

  constructor(call: MethodCall) {
    super(call);
    this.mRecorder = new FlutterRecorder(this);
  }

  getPlugin(): FlutterSoundManager {
    return FlutterSoundRecorderManager.flutterSoundRecorderPlugin;
  }

  getStatus(): number {
    if (this.mRecorder == null) {
      return t_RECORDER_STATE.RECORDER_IS_STOPPED;
    } else {
      return this.mRecorder.getRecorderState();
    }
  }

  async reset(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mRecorder?.closeRecorder();
    result.success(0);
  }

  async openRecorder(call: MethodCall, result: MethodResult): Promise<void> {
    let ret = await this.mRecorder?.openRecorder();
    if (ret) {
      result.success("openRecorder");
    } else {
      result.error(FlutterSoundRecorder.ERR_UNKNOWN, FlutterSoundRecorder.ERR_UNKNOWN, "Failure to open session");
    }
  }

  async closeRecorder(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mRecorder?.closeRecorder();
    result.success("closeRecorder");
  }

  isEncoderSupported(call: MethodCall, result: MethodResult): void {
    let codec = call.argument("codec") as t_CODEC;
    let isSupported: boolean = false;
    if (this.mRecorder != null) {
      isSupported = this.mRecorder.isEncoderSupported(codec);
    }
    result.success(isSupported);
  }

  invokeMethodString(methodName: string, arg: string): void {
    let dic: Map<string, Any> = new Map();
    dic.set("slotNo", this.slotNo);
    dic.set("state", this.getStatus());
    dic.set("arg", arg);
    this.getPlugin().invokeMethod(methodName, dic);
  }

  async startRecorder(call: MethodCall, result: MethodResult): Promise<void> {
    let sampleRate: number = call.argument("sampleRate");
    let numChannels: number = call.argument("numChannels");
    let bitRate: number = call.argument("bitRate");
    let codec: t_CODEC = call.argument("codec") as t_CODEC;
    let path: string = call.argument("path");
    let audioSource: t_AUDIO_SOURCE = call.argument("audioSource");
    let toStream: number = call.argument("toStream");
    let ret: boolean = false;
    if (this.mRecorder != null) {
      ret = await this.mRecorder!.startRecorder(codec, sampleRate, numChannels, bitRate,
        path, audioSource, toStream != 0);
    }
    if (ret) {
      result.success("Media Recorder is started");
    } else {
      result.error("startRecorder", "startRecorder", "Failure to start recorder");
    }
  }

  public async stopRecorder(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mRecorder?.stopRecorder();
    result.success("Media Recorder is closed");
  }

  public async pauseRecorder(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mRecorder?.pauseRecorder();
    result.success("Recorder is paused");
  }

  public async resumeRecorder(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mRecorder?.resumeRecorder();
    result.success("Recorder is resumed");
  }

  public setSubscriptionDuration(call: MethodCall, result: MethodResult): void {
    if (call.argument("duration") == null) {
      return
    }
    let duration: number = call.argument("duration");
    this.mRecorder?.setSubsDurationMillis(duration);
    result.success("setSubscriptionDuration: " + duration);
  }


  public getRecordURL(call: MethodCall, result: MethodResult): void {
    let path: string = call.argument("path");
    let ret = this.mRecorder?.temporayFile(path);
    result.success(ret);
  }

  public async deleteRecord(call: MethodCall, result: MethodResult): Promise<void> {
    let path: string = call.argument("path");
    let ret = await this.mRecorder?.deleteRecord(path);
    result.success(ret);
  }

  public setLogLevel(call: MethodCall, result: MethodResult): void {
  }
}