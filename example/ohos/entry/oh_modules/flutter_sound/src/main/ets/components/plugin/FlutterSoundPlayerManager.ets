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
 
import { BinaryMessenger, Log, MethodCall } from '@ohos/flutter_ohos';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterSoundManager } from './FlutterSoundManager';
import { common } from '@kit.AbilityKit';
import { FlutterSoundPlayer } from './FlutterSoundPlayer';
import { WantAgent, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { avSession as AVSessionManager } from '@kit.AVSessionKit';

const TAG = "FlutterSoundPlayerManager";

export class FlutterSoundPlayerManager extends FlutterSoundManager
  implements MethodCallHandler {
  static context: common.UIAbilityContext | undefined;
  static flutterSoundPlayerPlugin: FlutterSoundPlayerManager; //singleton
  private isStartContinuousTask = false;
  private session?: AVSessionManager.AVSession = undefined;

  public static attachFlautoPlayer(ctx: common.UIAbilityContext | undefined, messager: BinaryMessenger | undefined): void {
    if(FlutterSoundPlayerManager.flutterSoundPlayerPlugin == null) {
      FlutterSoundPlayerManager.flutterSoundPlayerPlugin = new FlutterSoundPlayerManager();
    }
    if(messager != undefined) {
      let channel: MethodChannel = new MethodChannel(messager, "com.dooboolab.flutter_sound_player");
      FlutterSoundPlayerManager.flutterSoundPlayerPlugin.init(channel);
      channel.setMethodCallHandler(FlutterSoundPlayerManager.flutterSoundPlayerPlugin);
    }
    FlutterSoundPlayerManager.context = ctx;
  }

  getManager(): FlutterSoundPlayerManager {
    return FlutterSoundPlayerManager.flutterSoundPlayerPlugin;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "resetPlugin": {
        this.resetPlugin(call, result);
        return;
      }
    }
    let aPlayer: FlutterSoundPlayer = this.getSession(call) as FlutterSoundPlayer;
    switch (call.method) {
      case "openPlayer": {
        aPlayer = new FlutterSoundPlayer(call);
        this.initSession(call, aPlayer);
        aPlayer.openPlayer(call, result);
        break;
      }
      case "closePlayer": {
        aPlayer.closePlayer(call, result);
        break;
      }
      case "isDecoderSupported": {
        aPlayer.isDecoderSupported(call, result);
        break;
      }
      case "getPlayerState": {
        aPlayer.getPlayerStateByChannel(call, result);
        break;
      }
      case "getResourcePath": {
        aPlayer.getResourcePath(call, result);
        break;
      }
      case "getProgress": {
        aPlayer.getProgress(call, result);
        break;
      }
      case "startPlayer": {
        aPlayer.startPlayer(call, result);
        this.startContinuousTask();
        break;
      }
      case "startPlayerFromMic": {
        //aPlayer.startPlayerFromMic(call, result);
        result.notImplemented();
        break;
      }
      case "stopPlayer": {
        aPlayer.stopPlayer(call, result);
        this.stopContinuousTask();
        break;
      }
      case "pausePlayer": {
        aPlayer.pausePlayer(call, result);
        this.stopContinuousTask();
        break;
      }
      case "resumePlayer": {
        aPlayer.resumePlayer(call, result);
        this.startContinuousTask();
        break;
      }
      case "seekToPlayer": {
        aPlayer.seekToPlayer(call, result);
        break;
      }
      case "setVolume": {
        aPlayer.setVolume(call, result);
        break;
      }
      case "setSpeed": {
        aPlayer.setSpeed(call, result);
        break;
      }
      case "setSubscriptionDuration": {
        aPlayer.setSubscriptionDuration(call, result);
        result.notImplemented();
        break;
      }
      case "feed": {
        aPlayer.feed(call, result);
        break;
      }
      case "setLogLevel": {
        aPlayer.setLogLevel(call, result);
        break;
      }
      default: {
        result.notImplemented();
        break;
      }
    }
  }

  async startContinuousTask() {
    Log.d(TAG, `startContinuousTask`);
    if(this.isStartContinuousTask){
      return;
    }
    this.isStartContinuousTask = true;

    let context = FlutterSoundPlayerManager.context;
    let type: AVSessionManager.AVSessionType = 'audio';
    await AVSessionManager.createAVSession(context, 'audioplayers', type).then(session =>{
       this.session = session;
    });
    // 激活接口要在元数据、控制命令注册完成之后再执行
    await this.session?.activate();
    Log.d(TAG, `session create done : sessionId : ${this.session?.sessionId}`);

    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: context?.abilityInfo.bundleName,
          abilityName: context?.abilityInfo.name
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
      backgroundTaskManager.startBackgroundRunning(context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj).then(() => {
        Log.d(TAG, `Succeeded in operationing startBackgroundRunning.`);
      }).catch((err: BusinessError) => {
        Log.e(TAG, `Failed to operation startBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
      });
    });
  }

  async stopContinuousTask() {
    Log.d(TAG, `stopContinuousTask`);
    if(!this.isStartContinuousTask){
      return;
    }
    this.isStartContinuousTask = false;
    await this.session?.deactivate();
    await this.session?.destroy();
    backgroundTaskManager.stopBackgroundRunning(FlutterSoundPlayerManager.context).then(() => {
      Log.d(TAG, `Succeeded in operationing stopBackgroundRunning.`);
    }).catch((err: BusinessError) => {
      Log.e(TAG, `Failed to operation stopBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
    });
  }
}