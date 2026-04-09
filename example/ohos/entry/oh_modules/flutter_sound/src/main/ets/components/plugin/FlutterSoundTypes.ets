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
 
export enum t_PLAYER_STATE {
  PLAYER_IS_STOPPED,
  PLAYER_IS_PLAYING,
  PLAYER_IS_PAUSED,
}

export enum t_LOG_LEVEL {
  VERBOSE,
  DBG,
  INFO,
  WARNING,
  ERROR,
  WTF,
  NOTHING,
}

export enum t_CODEC {
  defaultCodec,
  aacADTS,
  opusOGG,
  opusCAF,
  mp3,
  vorbisOGG,
  pcm16,
  pcm16WAV,
  pcm16AIFF,
  pcm16CAF,
  flac,
  aacMP4,
  amrNB,
  amrWB,
  pcm8,
  pcmFloat32,
  pcmWebM,
  opusWebM,
  vorbisWebM
}

export enum t_RECORDER_STATE {
  RECORDER_IS_STOPPED,
  RECORDER_IS_PAUSED,
  RECORDER_IS_RECORDING,
}

export enum t_AUDIO_SOURCE {
  defaultSource,
  microphone,
  voiceDownlink,
  camCorder,
  remote_submix,
  unprocessed,
  voice_call,
  voice_communication,
  voice_performance,
  voice_recognition,
  voiceUpLink,
  bluetoothHFP,
  headsetMic,
  lineIn
}

export enum t_PLAY_BACK_SPEED {
  SPEED_0_125_X = 0.125,
  SPEED_0_25_X = 0.25,
  SPEED_0_5_X = 0.5,
  SPEED_0_75_X = 0.75,
  SPEED_1_0_X = 1.0,
  SPEED_1_25_X = 1.25,
  SPEED_1_5_X = 1.5,
  SPEED_1_75_X = 1.75,
  SPEED_2_0_X = 2
}