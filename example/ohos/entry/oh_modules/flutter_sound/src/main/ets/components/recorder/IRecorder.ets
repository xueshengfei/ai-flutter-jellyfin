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
import { t_CODEC, t_RECORDER_STATE } from '../plugin/FlutterSoundTypes'

export interface IRecorder {
  get state(): t_RECORDER_STATE
  startRecord(numChannels: number, sampleRate: number, bitRate: number,
    codec: t_CODEC, path: string, audioSource: number): Promise<void>
  stopRecord(): Promise<void>
  pauseRecord(): Promise<boolean>
  resumeRecord(): Promise<boolean>
  getMaxAmplitude(): Promise<number>
}