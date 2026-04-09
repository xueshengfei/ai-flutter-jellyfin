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
import { t_CODEC, t_PLAYER_STATE, t_PLAY_BACK_SPEED } from '../plugin/FlutterSoundTypes';
import { IPlayer } from './IPlayer';
import { media } from '@kit.MediaKit';
import { FlutterSoundPlayerCallback } from '../plugin/FlutterSoundPlayerCallback';
import { Log } from '@ohos/flutter_ohos';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';

const TAG = "FlutterAVPlayer";
export class FlutterAVPlayer implements IPlayer {
  private avPlayer: media.AVPlayer | null = null;
  private callback: FlutterSoundPlayerCallback | null = null;
  private audioFile: fs.File | null = null;
  private speedMode: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  private volume: number = -1;
  private seekPos: number = -1;
  private lastSeekMilliseconds: number | null = null;

  constructor(cb: FlutterSoundPlayerCallback) {
    this.callback = cb;
  }

  get state(): t_PLAYER_STATE {
    switch (this.avPlayer?.state) {
      case "idle":
      case "initialized":
      case "prepared":
      case "completed":
      case "stopped":
      case "released":
      case "error":
        return t_PLAYER_STATE.PLAYER_IS_STOPPED;
      case "playing":
        return t_PLAYER_STATE.PLAYER_IS_PLAYING;
      case "paused":
        return t_PLAYER_STATE.PLAYER_IS_PAUSED;
      default:
        return t_PLAYER_STATE.PLAYER_IS_STOPPED;
    }
  }

  async startPlayer(codec: t_CODEC, path: string, dataBuffer: Uint8Array, numChannels: number, sampleRate: number): Promise<boolean> {
    if(this.avPlayer == null) {
      this.avPlayer = await media.createAVPlayer();
    }
    if(path == null) {
      throw new Error("path is null");
    }
    this.setAVPlayerCallback();
    if(path.startsWith("http")) {
      this.avPlayer.url = path;
    } else {
      this.audioFile = fs.openSync(path, fs.OpenMode.READ_ONLY);
      this.avPlayer.url = "fd://" + this.audioFile?.fd;
    }
    return true
  }

  async stopPlayer(): Promise<void> {
    if(this.avPlayer == null) {
      return;
    }
    try {
      await this.avPlayer.stop();
      await this.avPlayer.reset();
      await this.avPlayer.release();
    } catch (err) {
      Log.e(TAG, "avplayer stop failed, error:" + JSON.stringify(err));
    }
    this.avPlayer = null;
  }

  async pausePlayer(): Promise<void> {
    await this.avPlayer?.pause();
  }

  async resumePlayer(): Promise<void> {
    await this.avPlayer?.play();
  }

  seekTo(milliseconds: number): void {
    if(this.avPlayer?.state === "playing") {
      this.lastSeekMilliseconds = milliseconds
      this.avPlayer?.seek(milliseconds);
      this.seekPos = -1;
    } else {
      this.seekPos = milliseconds;
    }
  }

  setVolume(volume: number): void {
    this.volume = volume;
    if(this.avPlayer?.state === "playing") {
      this.avPlayer?.setVolume(this.volume);
    }
  }

  setSpeed(speed: number): void {
    this.speedMode = this.speedConvert(speed);
    if(this.avPlayer?.state === "playing") {
      this.avPlayer.setSpeed(this.speedMode);
    }
  }

  get duration(): number {
    if(this.avPlayer != null) {
      return this.avPlayer.duration;
    } else {
      return 0;
    }
  }

  get position(): number {
    if(this.avPlayer != null) {
      if (this.lastSeekMilliseconds != null) {
        return this.lastSeekMilliseconds
      } else {
        return this.avPlayer.currentTime;
      }
    } else {
      return 0;
    }
  }

  feed(data: Uint8Array): number {
    Log.w(TAG, "Cannot feed a AVPlayer");
    return -1;
  }

  isPlaying(): boolean {
    return this.avPlayer?.state === "playing";
  }

  private setAVPlayerCallback(): void {
    this.avPlayer?.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case "idle":
          break;
        case "initialized":
          this.avPlayer?.prepare();
          break;
        case "prepared":
          this.setAvplayerConfig();
          await this.avPlayer?.play();
          break;
        case "completed":
          this.setAvplayerConfig();
          this.callback?.updateProgress(this.avPlayer!.currentTime, this.avPlayer!.duration);
          this.callback?.audioPlayerDidFinishPlaying(true);
          break;
        case "stopped":
          break;
        case "released":
          break;
        case "error":
          this.callback?.startPlayerCompleted(false, 0);
          break;
        case "playing":
          this.setAvplayerConfig();
          this.callback?.startPlayerCompleted(true, this.avPlayer!.duration);
          break;
        case "paused":
          this.setAvplayerConfig();
          break;
      }
    })
    this.avPlayer?.on("error",(err: BusinessError) => {
      Log.e(TAG, "Invoke avPlayer failed, code is:" + err.code +" error: " + err.message);
      this.avPlayer?.reset();
    })
    this.avPlayer?.on("seekDone",(_: number) => {
      this.lastSeekMilliseconds = null
    })
  }

  private speedConvert(input: number): media.PlaybackSpeed {
    let closeSpeed : t_PLAY_BACK_SPEED = t_PLAY_BACK_SPEED.SPEED_1_0_X;
    const enumValues = Object.values(t_PLAY_BACK_SPEED) as Array<t_PLAY_BACK_SPEED>;
    for(const speed of enumValues) {
      if(speed >= input) {
        closeSpeed = speed;
        break;
      }
    }
    switch (closeSpeed) {
      case t_PLAY_BACK_SPEED.SPEED_0_125_X:
        return media.PlaybackSpeed.SPEED_FORWARD_0_125_X;
      case t_PLAY_BACK_SPEED.SPEED_0_25_X:
        return media.PlaybackSpeed.SPEED_FORWARD_0_25_X;
      case t_PLAY_BACK_SPEED.SPEED_0_5_X:
        return media.PlaybackSpeed.SPEED_FORWARD_0_50_X;
      case t_PLAY_BACK_SPEED.SPEED_0_75_X:
        return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
      case t_PLAY_BACK_SPEED.SPEED_1_0_X:
        return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
      case t_PLAY_BACK_SPEED.SPEED_1_25_X:
        return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
      case t_PLAY_BACK_SPEED.SPEED_1_5_X:
        return media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
      case t_PLAY_BACK_SPEED.SPEED_1_75_X:
        return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
      case t_PLAY_BACK_SPEED.SPEED_2_0_X:
        return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
      default:
        return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    }
  }

  private async setAvplayerConfig(): Promise<void> {
    if(this.volume >= 0) {
      this.avPlayer?.setVolume(this.volume);
    }
    this.avPlayer?.setSpeed(this.speedMode);
    if(this.seekPos >= 0) {
      this.avPlayer?.seek(this.seekPos);
      this.seekPos = -1;
    }
  }
}