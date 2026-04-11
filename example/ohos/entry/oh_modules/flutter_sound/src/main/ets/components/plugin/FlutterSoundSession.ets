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
 
import { MethodCall } from '@ohos/flutter_ohos';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterSoundManager } from './FlutterSoundManager';
import { t_LOG_LEVEL } from './FlutterSoundTypes';

export abstract class FlutterSoundSession {
  public slotNo: number = 0;

  constructor(call: MethodCall) {
  }

  public init(slot: number): void {
    this.slotNo = slot;
  }

  abstract getPlugin() : FlutterSoundManager;

  releaseSession(): void {
    this.getPlugin().freeSlot(this.slotNo);
  }

  abstract getStatus(): number;

  abstract reset(call: MethodCall, result: MethodResult): void;

  invokeMethodWithString(methodName: string, success: boolean, arg: string): void {
    let dic: Map<string, ESObject> = new Map();
    dic.set("slotNo", this.slotNo);
    dic.set("state", this.getStatus());
    dic.set("arg", arg);
    dic.set("success", success);
    this.getPlugin().invokeMethod(methodName, dic);
  }

  invokeMethodWithInteger(methodName: string, success: boolean, arg: number): void {
    let dic: Map<string, ESObject> = new Map();
    dic.set("slotNo", this.slotNo);
    dic.set("state", this.getStatus());
    dic.set("arg", arg);
    dic.set("success", success);
    this.getPlugin().invokeMethod(methodName, dic);
  }

  invokeMethodWithBoolean(methodName: string, success: boolean, arg: boolean): void {
    let dic: Map<string, ESObject> = new Map();
    dic.set("slotNo", this.slotNo);
    dic.set("state", this.getStatus());
    dic.set("arg", arg);
    dic.set("success", success);
    this.getPlugin().invokeMethod(methodName, dic);
  }

  invokeMethodWithMap(methodName: string, success: boolean, dic: Map<string, ESObject>): void {
    dic.set("slotNo", this.slotNo);
    dic.set("state", this.getStatus());
    dic.set("success", success);
    this.getPlugin().invokeMethod(methodName, dic);
  }

  log(level: t_LOG_LEVEL, msg: string): void {
    let dic: Map<string, ESObject> = new Map();
    dic.set("slotNo", this.slotNo);
    dic.set("state", this.getStatus());
    dic.set("level", level.valueOf());
    dic.set("msg", msg);
    dic.set("success", true);
    this.getPlugin().invokeMethod("log", dic);
  }

}
