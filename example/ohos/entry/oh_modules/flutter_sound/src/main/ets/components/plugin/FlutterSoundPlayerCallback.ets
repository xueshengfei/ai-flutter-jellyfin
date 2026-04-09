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
import { t_PLAYER_STATE } from './FlutterSoundTypes';

export interface FlutterSoundPlayerCallback {
  openPlayerCompleted(success: boolean): void;
  closePlayerCompleted(success: boolean): void;
  stopPlayerCompleted(success: boolean): void;
  pausePlayerCompleted(success: boolean): void;
  resumePlayerCompleted(success: boolean): void;
  startPlayerCompleted(success: boolean, duration: number): void;
  needSomeFood(ln: number): void;
  updateProgress(position: number, duration: number): void;
  audioPlayerDidFinishPlaying(flag: boolean): void;
  updatePlaybackState(newState: t_PLAYER_STATE): void;
}