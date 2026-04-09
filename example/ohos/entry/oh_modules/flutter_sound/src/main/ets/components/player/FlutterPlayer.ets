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
 
import fs from '@ohos.file.fs';
import { JSON } from '@kit.ArkTS';
import { Any, Log } from '@ohos/flutter_ohos';
import { FlutterSoundPlayerCallback } from '../plugin/FlutterSoundPlayerCallback';
import { t_CODEC, t_PLAYER_STATE } from '../plugin/FlutterSoundTypes';
import { IPlayer } from './IPlayer'
import { FlutterAVPlayer } from './FlutterAVPlayer';
import { FlutterAudioRenderer } from './FlutterAudioRenderer';

const TAG  = "FlutterPlayer"

export class FlutterPlayer {
  private player: IPlayer | null = null;
  private latentVolume: number = -1;
  private latentSpeed: number = -1;
  private latentSeek: number = -1;
  private myPlayerId: number = 0;
  private intervalID = -1;
  static currentPlayerID: number = 0;
  static ERR_UNKNOWN: string = "ERR_UNKNOWN";
  public m_callback: FlutterSoundPlayerCallback | null = null;
  private subsDurationMillis = 0;

  constructor(callback: FlutterSoundPlayerCallback) {
    this.m_callback = callback;
  }

  public openPlayer(): boolean {
    ++FlutterPlayer.currentPlayerID;
    this.latentVolume = -1;
    this.latentSpeed = -1;
    this.latentSeek = -1;
    this.m_callback?.openPlayerCompleted(true);
    return true;
  }

  public async closePlayer(): Promise<void> {
    await this.stop();
    this.m_callback?.closePlayerCompleted(true);
  }

  public getPlayerState(): t_PLAYER_STATE {
    if(this.player == null) {
      return t_PLAYER_STATE.PLAYER_IS_STOPPED;
    } else {
      return this.player.state;
    }
  }

  public async startPlayerFromMic(numChannels: number, sampleRate: number, blockSize: number): Promise<boolean> {
    //ohos not support mic player
    Log.e(TAG, "startPlayerFromMic do nothing.");
    await this.stop();
    return true;
  }

  public async startPlayer(codec: t_CODEC, fromURI: string, dataBuffer: Uint8Array, numChannels: number, sampleRate: number): Promise<boolean> {
    await this.stop();
    try {
      let path = this.getPath(fromURI);
      let isPcm = codec === t_CODEC.pcm16 || codec === t_CODEC.pcmFloat32;
      if (isPcm) {
          this.player = new FlutterAudioRenderer(this.m_callback!);
      } else {
          this.player = new FlutterAVPlayer(this.m_callback!);
      }

      if (!await this.player.startPlayer(codec, path, dataBuffer, numChannels, sampleRate)) {
        return false
      }
      await this.playerSettings();
      if (isPcm) {
        await this.player.resumePlayer();
      }
    } catch (err) {
      Log.e(TAG, "startPlayer() exception: " + JSON.stringify(err));
      return false;
    }
    return true;
  }

  public async stopPlayer(): Promise<void> {
    await this.stop();
    this.m_callback?.stopPlayerCompleted(true);
  }

  public async pausePlayer(): Promise<boolean> {
    try {
      clearInterval(this.intervalID);
      if(this.player == null) {
        this.m_callback?.resumePlayerCompleted(false);
        return false;
      }
      await this.player?.pausePlayer();
      this.m_callback?.pausePlayerCompleted(true);
      return true;
    } catch (e) {
      Log.e(TAG, "pausePlayer exception: " + JSON.stringify(e));
      return false;
    }
  }

  public async resumePlayer(): Promise<boolean> {
    try {
      if(this.player == null) {
        return false;
      }
      await this.player?.resumePlayer();
      this.setTimer(this.subsDurationMillis);
      this.m_callback?.resumePlayerCompleted(true);
      return true;
    } catch (e) {
      Log.e(TAG, "resumePlayer exception: " + JSON.stringify(e));
      return false;
    }
  }

  public seekToPlayer(millis: number): boolean {
    if(this.player == null) {
      this.latentSeek = millis;
      return false;
    }

    this.latentSeek = -1;
    this.player?.seekTo(millis);
    return true;
  }

  public setVolume(volume: number): boolean {
    try {
      this.latentVolume = volume;
      if(this.player == null) {
        return false;
      }
      this.player?.setVolume(volume);
      return true;
    } catch (err) {
      Log.e(TAG, "setVolume exception: " + JSON.stringify(err));
      return false;
    }
  }

  public setSpeed(speed: number): boolean {
    try {
      this.latentSpeed = speed;
      if(this.player == null) {
        return false;
      }
      this.player?.setSpeed(speed);
      return true;
    } catch (err) {
      Log.e(TAG, "setSpeed exception: " + JSON.stringify(err));
      return false;
    }
  }

  public setSubscriptionDuration(duration: number): void {
    this.subsDurationMillis = duration;
    if(this.player != null) {
      this.setTimer(this.subsDurationMillis);
    }
  }

  public getProgress(): Map<string, Any> {
    let position = 0;
    let duration = 0;
    if(this.player != null) {
      position = this.player.position;
      duration = this.player.duration;
    }
    if(position > duration) {
      position = duration;
    }
    let dic: Map<string, Any> = new Map();
    dic.set("position", position);
    dic.set("duration", duration);
    dic.set("playerStatus", this.getPlayerState());
    return dic;
  }

  public feed(data: Uint8Array): number {
    if(this.player == null) {
      throw new Error("feed() player is null");
    }

    try {
      let ln = this.player.feed(data);
      if(ln < 0) {
        throw new Error("player feed error");
      }
      return ln;
    } catch (err) {
      throw new Error(JSON.stringify(err));
    }
  }

  isDecoderSupported(codec: t_CODEC): boolean {
    switch (codec) {
      case t_CODEC.aacADTS:
      case t_CODEC.aacMP4:
      case t_CODEC.mp3:
      case t_CODEC.vorbisOGG:
      case t_CODEC.opusOGG:
      case t_CODEC.pcm16:
      case t_CODEC.pcm16WAV:
      case t_CODEC.pcmFloat32:
      case t_CODEC.flac:
        return true;
      default:
        return false; // other codec not supported
    }
  }



  private async stop() {
    this.deleteTempFile();
    clearInterval(this.intervalID);
    if(this.player) {
      await this.player.stopPlayer();
    }
    this.player = null;
  }

  private getTempFileName(): string {
    return getContext(this).cacheDir + "/flutter_sound_" + this.myPlayerId;
  }

  private async deleteTempFile(): Promise<void> {
    let fileName = this.getTempFileName();
    try {
      if(fs.accessSync(fileName)) {
        fs.unlinkSync(fileName);
        Log.d(TAG, "file Deleted:" + fileName);
      }
    } catch (err) {
    }
  }

  private temporayFile(radical: string): string {
    return getContext(this).cacheDir +  "/" + radical;
  }

  private getPath(path: string): string {
    if(path == null) {
      return "";
    } else {
      let isFound = path.includes("/");
      if(!isFound) {
        path = this.temporayFile(path);
      }
      return path;
    }
  }

  private setTimer(duration: number): void {
    clearInterval(this.intervalID);
    this.subsDurationMillis = duration;
    if(this.subsDurationMillis > 0) {
      this.intervalID = setInterval(() => {
        if(this.player != null && this.player.isPlaying()) {
          this.m_callback?.updateProgress(this.player.position, this.player.duration);
        }
      }, duration);
    }
  }

  private async playerSettings(): Promise<boolean> {
    if(this.player == null) {
      return false;
    }
    try {
      if (this.latentVolume >= 0) {
        this.setVolume(this.latentVolume);
      }
      if(this.latentSpeed >= 0) {
        this.setSpeed(this.latentSpeed);
      }
      if(this.subsDurationMillis > 0) {
        this.setTimer(this.subsDurationMillis);
      }
      if(this.latentSeek >= 0) {
        this.seekToPlayer(this.latentSeek);
      }
    } catch (err) {
      Log.e(TAG, "play() exception: " + JSON.stringify(err));
      return false;
    }
    return true;
  }
}