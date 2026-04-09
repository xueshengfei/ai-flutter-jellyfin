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
 
import { MethodCall, MethodChannel } from '@ohos/flutter_ohos'
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterSoundSession } from './FlutterSoundSession';

export class FlutterSoundManager {
  public channel: MethodChannel | null = null;
  public slots: Map<number, FlutterSoundSession | undefined> = new Map();

  init(aChannel: MethodChannel): void {
    this.channel = aChannel;
  }

  invokeMethod(methodName: string, dic: Map<string, ESObject>): void {
    this.channel?.invokeMethod(methodName, dic);
  }

  freeSlot(slotNo: number): void {
    this.slots.set(slotNo, undefined);
  }

  public getSession(call: MethodCall): FlutterSoundSession | undefined {
    let slotNo: number = call.argument("slotNo");
    if(slotNo < 0 || slotNo > this.slots.size) {
      throw new Error("Invalid slot number");
    }
    if (slotNo == this.slots.size) {
      this.slots.set(slotNo, undefined);
    }
    return this.slots.get(slotNo);
  }

  public initSession(call: MethodCall, aPlayer: FlutterSoundSession): void {
    let slot: number = call.argument("slotNo");
    this.slots.set(slot, aPlayer);
    aPlayer.init(slot);
  }

  public resetPlugin(call: MethodCall, result: MethodResult) {
    for(let i = 0; i < this.slots.size; ++i) {
      if(this.slots.get(i) != undefined) {
        this.slots.get(i)?.reset(call, result);
      }
      this.slots = new Map();
    }
    result.success(0);
  }
}
