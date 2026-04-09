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
import { FlutterSoundRecorder } from './FlutterSoundRecorder';
import { WantAgent, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { avSession as AVSessionManager } from '@kit.AVSessionKit';

const TAG = "FlutterSoundRecorderManager";
export class FlutterSoundRecorderManager extends FlutterSoundManager
  implements MethodCallHandler {

  static flutterSoundRecorderPlugin: FlutterSoundRecorderManager; //singleton
  static context: common.UIAbilityContext | undefined;
  private isStartContinuousTask = false;
  private session?: AVSessionManager.AVSession = undefined;

  public static attachFlautoRecorder(ctx: common.UIAbilityContext | undefined, messenger: BinaryMessenger | undefined): void {
    if(FlutterSoundRecorderManager.flutterSoundRecorderPlugin == null) {
      FlutterSoundRecorderManager.flutterSoundRecorderPlugin = new FlutterSoundRecorderManager();
    }
    if(messenger != undefined) {
      let channel: MethodChannel = new MethodChannel(messenger, "com.dooboolab.flutter_sound_recorder");
      FlutterSoundRecorderManager.flutterSoundRecorderPlugin.init(channel);
      channel.setMethodCallHandler(FlutterSoundRecorderManager.flutterSoundRecorderPlugin);
    }
    FlutterSoundRecorderManager.context = ctx;
  }

  getManager(): FlutterSoundRecorderManager {
    return FlutterSoundRecorderManager.flutterSoundRecorderPlugin;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "resetPlugin": {
        this.resetPlugin(call, result);
        break;
      }
    }

    let aRecorder: FlutterSoundRecorder = this.getSession(call) as FlutterSoundRecorder;

    switch (call.method) {
      case "openRecorder": {
        aRecorder = new FlutterSoundRecorder(call);
        this.initSession(call, aRecorder);
        aRecorder.openRecorder(call, result);
        break;
      }
      case "closeRecorder": {
        aRecorder.closeRecorder(call, result);
        break;
      }
      case "isEncoderSupported": {
        aRecorder.isEncoderSupported(call, result);
        break;
      }
      case "startRecorder": {
        aRecorder.startRecorder(call, result);
        this.startContinuousTask();
        break;
      }
      case "stopRecorder": {
        aRecorder.stopRecorder(call, result);
        this.stopContinuousTask();
        break;
      }
      case "setSubscriptionDuration": {
        aRecorder.setSubscriptionDuration(call, result);
        result.notImplemented();
        break;
      }
      case "pauseRecorder": {
        aRecorder.pauseRecorder(call, result);
        this.stopContinuousTask();
        break;
      }
      case "resumeRecorder": {
        aRecorder.resumeRecorder(call, result);
        this.startContinuousTask();
        break;
      }
      case "getRecordURL": {
        aRecorder.getRecordURL(call, result);
        break;
      }
      case "deleteRecord": {
        aRecorder.deleteRecord(call, result);
        break;
      }
      case "setLogLevel": {
        aRecorder.setLogLevel(call, result);
        break;
      }
      default : {
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

    let context = FlutterSoundRecorderManager.context;
    let type: AVSessionManager.AVSessionType = 'audio';
    await AVSessionManager.createAVSession(context, 'audioRecording', type).then(session =>{
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
      backgroundTaskManager.startBackgroundRunning(context, backgroundTaskManager.BackgroundMode.AUDIO_RECORDING, wantAgentObj).then(() => {
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
    backgroundTaskManager.stopBackgroundRunning(FlutterSoundRecorderManager.context).then(() => {
      Log.d(TAG, `Succeeded in operationing stopBackgroundRunning.`);
    }).catch((err: BusinessError) => {
      Log.e(TAG, `Failed to operation stopBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
    });
  }
}