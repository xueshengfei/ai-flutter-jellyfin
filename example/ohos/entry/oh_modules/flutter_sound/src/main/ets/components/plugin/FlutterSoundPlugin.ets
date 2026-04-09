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
 
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import { AbilityAware, AbilityPluginBinding, Log } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { FlutterSoundPlayerManager } from './FlutterSoundPlayerManager';
import { FlutterSoundRecorderManager } from './FlutterSoundRecorderManager';
import { FlutterSoundPlayer } from './FlutterSoundPlayer';
import { FlutterSoundRecorder } from './FlutterSoundRecorder';

/** FluttersoundPlugin **/
export default class FlutterSoundPlugin implements FlutterPlugin, AbilityAware {
  private pluginBinding: FlutterPluginBinding | null = null;
  private static context: common.Context | undefined = undefined;

  constructor() {
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    // Only register if activity exists (the application is not running in background)
    FlutterSoundPlugin.context = this.pluginBinding?.getApplicationContext();
    FlutterSoundPlayer.context = binding.getAbility().context;
    FlutterSoundRecorder.context = binding.getAbility().context;
    FlutterSoundPlayerManager.attachFlautoPlayer(binding.getAbility().context, this.pluginBinding?.getBinaryMessenger());
    FlutterSoundRecorderManager.attachFlautoRecorder(binding.getAbility().context, this.pluginBinding?.getBinaryMessenger());
  }

  onDetachedFromAbility(): void {
  }

  getUniqueClassName(): string {
    return "FlutterSoundPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.pluginBinding = binding;
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {

  }



}