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
 
import { Any, Log, MethodCall } from '@ohos/flutter_ohos';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterSoundManager } from './FlutterSoundManager';
import { FlutterSoundPlayerManager } from './FlutterSoundPlayerManager';
import { FlutterSoundSession } from './FlutterSoundSession';
import { t_CODEC, t_LOG_LEVEL, t_PLAYER_STATE, t_PLAY_BACK_SPEED } from './FlutterSoundTypes';
import media from '@ohos.multimedia.media';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { FlutterSoundPlayerCallback } from './FlutterSoundPlayerCallback';
import { FlutterPlayer } from '../player/FlutterPlayer';

const TAG = "FlutterSoundPlayer";
export class FlutterSoundPlayer extends FlutterSoundSession implements FlutterSoundPlayerCallback{
  static ERR_UNKNOWN           = "ERR_UNKNOWN";
  static ERR_PLAYER_IS_NULL    = "ERR_PLAYER_IS_NULL";
  static ERR_PLAYER_IS_PLAYING = "ERR_PLAYER_IS_PLAYING";
  static context: common.UIAbilityContext | undefined;
  private mPlayer: FlutterPlayer | null = null;


  openPlayerCompleted(success: boolean): void {
    this.invokeMethodWithBoolean( "openPlayerCompleted", success, success );
  }

  closePlayerCompleted(success: boolean): void {
    this.invokeMethodWithBoolean( "closePlayerCompleted", success, success );
  }

  stopPlayerCompleted(success: boolean): void {
    this.invokeMethodWithBoolean( "stopPlayerCompleted", success, success );
  }

  pausePlayerCompleted(success: boolean): void {
    this.invokeMethodWithBoolean( "pausePlayerCompleted", success, success );
  }

  resumePlayerCompleted(success: boolean): void {
    this.invokeMethodWithBoolean( "resumePlayerCompleted", success, success );
  }

  startPlayerCompleted(success: boolean, duration: number): void {
    let dic: Map<string, ESObject> = new Map();
    dic.set("duration", duration);
    dic.set("state", this.getPlayerState());
    this.invokeMethodWithMap("startPlayerCompleted", success, dic);
  }

  needSomeFood(ln: number): void {
    this.invokeMethodWithInteger("needSomeFood", true, ln);
  }

  updateProgress(position: number, duration: number): void {
    let dic: Map<string, ESObject> = new Map();
    dic.set("position", position);
    dic.set("duration", duration);
    dic.set("playerState", this.getPlayerState());
    this.invokeMethodWithMap("updateProgress", true, dic);
  }

  audioPlayerDidFinishPlaying(flag: boolean): void {
    this.invokeMethodWithInteger("audioPlayerFinishedPlaying", true, this.getPlayerState());
  }

  updatePlaybackState(newState: t_PLAYER_STATE): void {
    this.invokeMethodWithInteger("updatePlaybackState", true, newState);
  }

  //====================================================================================================================

  constructor(call: MethodCall) {
    super(call);
    this.mPlayer = new FlutterPlayer(this);
  }

  getPlugin(): FlutterSoundManager {
    return FlutterSoundPlayerManager.flutterSoundPlayerPlugin;
  }

  getStatus(): number {
    return this.getPlayerState();
  }

  getPlayerState(): t_PLAYER_STATE {
    return this.mPlayer!.getPlayerState();
  }

  async openPlayer(call: MethodCall, result: MethodResult): Promise<void> {
    let ret = this.mPlayer?.openPlayer();
    if(ret) {
      result.success(this.getPlayerState());
    } else {
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, "Failure to open session");
    }
  }

  async closePlayer(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mPlayer?.closePlayer();
    result.success(this.getPlayerState());
  }

  async reset(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mPlayer?.closePlayer();
    result.success(this.getPlayerState());
  }

  startPlayerFromMic(call: MethodCall, result: MethodResult): void {
    let _blockSize = 4096;
    if(call.argument("blockSize") != null) {
      _blockSize = call.argument("blockSize");
    }
    let _sampleRate = 48000;
    if(call.argument("sampleRate") != null) {
      _sampleRate = call.argument("sampleRate");
    }
    let _numChannels = 1;
    if(call.argument("numChannels") != null) {
      _numChannels = call.argument("numChannels");
    }
    try {
      let ret = this.mPlayer?.startPlayerFromMic(_numChannels, _sampleRate, _blockSize);
      if(ret) {
        result.success(this.getPlayerState());
      } else {
        result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, "startPlayerFromMic() error");
      }
    } catch (err) {
      this.log(t_LOG_LEVEL.ERROR, "startPlayerFromMic() exception");
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, JSON.stringify(err));
    }
  }

  public async startPlayer(call: MethodCall, result: MethodResult): Promise<void> {
    let _codec: number = call.argument("codec");
    let codec: t_CODEC = (_codec != null) ? _codec : 0;
    let dataBuffer = call.argument("fromDataBuffer") as Uint8Array;
    let _path: string = call.argument("fromURI");
    let _sampleRate: number = 16000;
    if(call.argument("sampleRate") != null) {
      _sampleRate = call.argument("sampleRate");
    }
    let _numChannels: number = 1;
    if(call.argument("numChannels") != null) {
      _numChannels = call.argument("numChannels");
    }
    try {
      let ret = await this.mPlayer?.startPlayer(codec, _path, dataBuffer, _numChannels, _sampleRate);
      if(ret) {
        result.success(this.getPlayerState());
      } else {
        result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, "startPlayer() error");
      }
    } catch (err) {
      this.log(t_LOG_LEVEL.ERROR, "startPlayer() exception");
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, JSON.stringify(err));
    }
}

  public feed(call: MethodCall, result: MethodResult): void {
    try {
      let data = call.argument("data") as Uint8Array;
      let ln: number = this.mPlayer!.feed(data);
      result.success(ln);
    } catch (err) {
      this.log(t_LOG_LEVEL.ERROR, "feed() exception");
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, JSON.stringify(err));
    }
  }

  public async stopPlayer(call: MethodCall, result: MethodResult): Promise<void> {
    await this.mPlayer?.stopPlayer();
    result.success(this.getPlayerState());
  }

  public isDecoderSupported(call: MethodCall, result: MethodResult): void {
    let codec = call.argument ( "codec" ) as number;
    result.success(this.mPlayer?.isDecoderSupported(codec));
  }

  public async pausePlayer(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if(await this.mPlayer?.pausePlayer()) {
        result.success(this.getPlayerState());
      } else {
        result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, "pausePlayer() error");
      }
    } catch (err) {
      this.log(t_LOG_LEVEL.ERROR, "pausePlayer() exception");
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, JSON.stringify(err));
    }
  }

  public async resumePlayer(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (await this.mPlayer?.resumePlayer())
        result.success(this.getPlayerState());
      else
        result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, "resumePlayer() error");
    } catch (err) {
      this.log(t_LOG_LEVEL.ERROR, "resumePlayer() exception");
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, JSON.stringify(err));
    }
  }

  public async seekToPlayer(call: MethodCall, result: MethodResult): Promise<void> {
    let millis = call.argument ( "duration" ) as number;
    this.mPlayer?.seekToPlayer(millis);
    result.success(this.getPlayerState());
  }

  public setVolume(call: MethodCall, result: MethodResult): void {
    try {
      let volume = call.argument ( "volume" ) as number;
      this.mPlayer?.setVolume(volume);
      result.success(this.getPlayerState());
    } catch (e) {
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, JSON.stringify(e));
    }
  }

  public setSpeed(call: MethodCall, result: MethodResult): void {
    try {
      let speed = call.argument ( "speed" ) as number;
      this.mPlayer?.setSpeed(speed);
      result.success(this.getPlayerState());
    } catch (e) {
      result.error(FlutterSoundPlayer.ERR_UNKNOWN, FlutterSoundPlayer.ERR_UNKNOWN, JSON.stringify(e));
    }

  }

  public setSubscriptionDuration(call: MethodCall, result: MethodResult): void {
    if(call.argument("duration") != null) {
      let duration = call.argument("duration") as number;
      this.mPlayer?.setSubscriptionDuration(duration);
    }
    result.success(this.getPlayerState());
  }

  public getProgress(call: MethodCall, result: MethodResult): void {
    if (this.mPlayer != null) {
      let dic: Map<string, Any> = this.mPlayer?.getProgress();
      dic.set("slotNo", this.slotNo);
      result.success(dic);
    }
  }

  public getResourcePath(call: MethodCall, result: MethodResult): void {
    //TODO:
    result.success("");
  }

  public getPlayerStateByChannel(call: MethodCall, result: MethodResult): void {
    result.success(this.getPlayerState());
  }

  public setLogLevel(call: MethodCall, result: MethodResult): void {
  }

}