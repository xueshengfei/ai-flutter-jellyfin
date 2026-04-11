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
import { t_CODEC, t_PLAYER_STATE } from '../plugin/FlutterSoundTypes';

export interface IPlayer {
  startPlayer(codec: t_CODEC, path: string, dataBuffer: Uint8Array, numChannels: number, sampleRate: number): Promise<boolean>;
  stopPlayer(): Promise<void>;
  pausePlayer(): Promise<void>;
  resumePlayer(): Promise<void>;
  seekTo(milliseconds: number): void;
  setVolume(volume: number): void;
  setSpeed(speed: number): void;
  get duration(): number;
  get position(): number;
  get state(): t_PLAYER_STATE;
  feed(data: Uint8Array): number;
  isPlaying(): boolean;
}