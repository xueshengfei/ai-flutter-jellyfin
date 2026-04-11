/*
 * Copyright (C) 2025 Huawei Device Co., Ltd.
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

export class DynamicUint8Buffer {
  private buffer: Uint8Array;     // 存储数据的缓冲区
  private readPointer: number;    // 读取位置指针
  private writePointer: number;   // 写入位置指针
  private capacity: number;       // 当前缓冲区容量
  private length: number;         // 当前有效数据长度

  constructor(initialCapacity = 1024) {
    this.capacity = initialCapacity;
    this.buffer = new Uint8Array(initialCapacity);
    this.readPointer = 0;
    this.writePointer = 0;
    this.length = 0;
  }

  /**
   * 向缓冲区写入数据
   * @param data 要写入的 Uint8Array 数据
   */
  write(data: Uint8Array): void {
    const required = this.length + data.length;

    // 检查是否需要扩容
    if (required > this.capacity) {
      this._expand(Math.max(2 * this.capacity, required));
    }

    // 分两种情况写入（连续写入或跨越结尾回绕）
    if (this.writePointer + data.length <= this.capacity) {
      // 正常写入（无回绕）
      this.buffer.set(data, this.writePointer);
      this.writePointer += data.length;
    } else {
      // 分段写入（跨越缓冲区结尾）
      const firstPart = this.capacity - this.writePointer;
      const secondPart = data.length - firstPart;

      this.buffer.set(data.subarray(0, firstPart), this.writePointer);
      this.buffer.set(data.subarray(firstPart), 0);
      this.writePointer = secondPart;
    }

    this.length += data.length;
  }

  /**
   * 从缓冲区读取数据（读取后逻辑删除）
   * @param bytes 要读取的字节数，默认为当前全部数据
   * @returns 读取的 Uint8Array 数据
   */
  read(bytes?: number): Uint8Array {
    bytes = bytes === undefined ? this.length : Math.min(bytes, this.length);
    if (bytes <= 0 || this.length === 0) {
      return new Uint8Array(0);
    }

    const result = new Uint8Array(bytes);

    // 分两种情况读取（连续读取或跨越结尾回绕）
    if (this.readPointer + bytes <= this.capacity) {
      // 正常读取（无回绕）
      result.set(this.buffer.subarray(this.readPointer, this.readPointer + bytes));
      this.readPointer += bytes;
    } else {
      // 分段读取（跨越缓冲区结尾）
      const firstPart = this.capacity - this.readPointer;
      const secondPart = bytes - firstPart;

      result.set(this.buffer.subarray(this.readPointer), 0);
      result.set(this.buffer.subarray(0, secondPart), firstPart);
      this.readPointer = secondPart;
    }

    this.length -= bytes;
    return result;
  }

  /**
   * 扩展缓冲区容量
   * @param newCapacity 新缓冲区容量
   */
  private _expand(newCapacity: number): void {
    const newBuffer = new Uint8Array(newCapacity);
    const currentData = this.read(this.length); // 取出当前所有数据

    // 重置状态
    this.capacity = newCapacity;
    this.buffer = newBuffer;
    this.readPointer = 0;
    this.writePointer = 0;
    this.length = 0;

    // 将原数据写回新缓冲区
    this.write(currentData);
  }

  /**
   * 当前有效数据长度
   */
  get dataLength(): number {
    return this.length;
  }
}