"""
雨落TTS (RainfallTTS) Python SDK
=================================
单文件 SDK，封装雨落AI语音 Gradio v5 服务端 API。
支持 TTS 合成、批量生成、多角色对话、音色列表查询等功能。

依赖: requests (标准库无需额外安装即可使用基础功能)

用法示例:
    from rainfall_tts_sdk import RainfallTTS

    client = RainfallTTS("http://127.0.0.1:7861")
    if client.is_server_alive():
        result = client.generate("你好，这是测试")
        client.download_audio(result, "output.wav")
"""

from __future__ import annotations

import json
import os
import time
import urllib.parse
from dataclasses import dataclass, field
from typing import Optional

import requests

# ---------------------------------------------------------------------------
# 数据模型
# ---------------------------------------------------------------------------

@dataclass
class TTSResult:
    """TTS 合成结果"""
    audio_path: str            # 服务端生成的音频文件相对路径
    audio_url: str = ""        # 可下载的完整 URL
    local_path: str = ""       # download_audio 后的本地路径


@dataclass
class VoiceInfo:
    """可用音色信息"""
    name: str


@dataclass
class RoleAssignment:
    """多角色对话中的角色分配"""
    role_name: str             # 角色名称
    voice: str = ""            # 音色文件名（如 demo_boy.wav）或全路径


# ---------------------------------------------------------------------------
# 异常体系
# ---------------------------------------------------------------------------

class RainfallTTSError(Exception):
    """SDK 基础异常"""
    pass


class ConnectionError(RainfallTTSError):
    """连接服务端失败"""
    pass


class TTSError(RainfallTTSError):
    """TTS 合成过程中的错误"""
    pass


class TimeoutError(RainfallTTSError):
    """请求超时"""
    pass


class ServerError(RainfallTTSError):
    """服务端返回错误"""
    pass


# ---------------------------------------------------------------------------
# 核心 Transport 层 — Gradio v5 两步协议 (POST 提交 → SSE 轮询结果)
# ---------------------------------------------------------------------------

_GRADIO_API_PREFIX = "/gradio_api"


def _parse_sse_stream(response: requests.Response) -> object:
    """解析 Gradio SSE 事件流，返回最终 payload。

    Gradio v5 SSE 格式示例:
        event: complete
        data: [payload]
    """
    last_data = None
    for line in response.iter_lines(decode_unicode=True):
        if not line:
            continue
        if line.startswith("event:"):
            evt = line.split(":", 1)[1].strip()
            if evt == "error":
                # 下一行 data 包含错误信息
                continue
        if line.startswith("data:"):
            payload_str = line.split(":", 1)[1].strip()
            try:
                last_data = json.loads(payload_str)
            except json.JSONDecodeError:
                last_data = payload_str
    return last_data


def _call_gradio(
    base_url: str,
    endpoint: str,
    data: list,
    timeout: float = 300.0,
) -> object:
    """调用 Gradio v5 API（两步协议）。

    第一步: POST /gradio_api/call/<endpoint>  提交任务，获取 event_id
    第二步: GET  /gradio_api/call/<endpoint>/<event_id>  轮询 SSE 结果

    Args:
        base_url: 服务地址，如 http://127.0.0.1:7861
        endpoint: API 名称，如 rainfall_gen_single
        data:     参数列表，顺序与 Gradio 组件 ID 一致
        timeout:  总超时秒数

    Returns:
        解析后的返回值（通常为列表）
    """
    call_url = f"{base_url}{_GRADIO_API_PREFIX}/call/{endpoint}"

    # 第一步: 提交任务
    try:
        resp = requests.post(call_url, json={"data": data}, timeout=30)
    except requests.exceptions.ConnectionError as e:
        raise ConnectionError(f"无法连接到 {base_url}: {e}") from e
    except requests.exceptions.Timeout as e:
        raise TimeoutError(f"提交任务超时: {e}") from e

    if resp.status_code != 200:
        raise ServerError(f"提交任务失败，HTTP {resp.status_code}: {resp.text[:500]}")

    try:
        result = resp.json()
        event_id = result.get("event_id")
    except (json.JSONDecodeError, AttributeError) as e:
        raise ServerError(f"解析提交响应失败: {e}, body={resp.text[:500]}") from e

    if not event_id:
        raise ServerError(f"未获取到 event_id, body={resp.text[:500]}")

    # 第二步: SSE 轮询结果
    sse_url = f"{call_url}/{event_id}"
    try:
        resp = requests.get(sse_url, stream=True, timeout=timeout)
    except requests.exceptions.ConnectionError as e:
        raise ConnectionError(f"获取结果时连接失败: {e}") from e
    except requests.exceptions.Timeout as e:
        raise TimeoutError(f"获取结果超时 ({timeout}s): {e}") from e

    if resp.status_code != 200:
        raise ServerError(f"获取结果失败，HTTP {resp.status_code}: {resp.text[:500]}")

    payload = _parse_sse_stream(resp)

    if isinstance(payload, dict) and "error" in payload:
        raise TTSError(f"服务端合成错误: {payload['error']}")

    return payload


# ---------------------------------------------------------------------------
# 布尔参数 ↔ 中文枚举转换
# ---------------------------------------------------------------------------

def _bool_to_cn(value: bool, true_str: str, false_str: str) -> str:
    return true_str if value else false_str


# ---------------------------------------------------------------------------
# 公开 API: RainfallTTS
# ---------------------------------------------------------------------------

class RainfallTTS:
    """雨落TTS SDK 客户端

    Args:
        base_url: Gradio 服务地址，默认 http://127.0.0.1:7861
        timeout:  API 请求超时秒数，默认 300 (合成较长文本时需要足够时间)
    """

    def __init__(self, base_url: str = "http://127.0.0.1:7861", timeout: float = 300.0):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        # 默认输出目录：服务端的 outputs（相对路径，由服务端解析）
        self.default_output_dir = "outputs"

    # ---- 健康检查 ----

    def is_server_alive(self) -> bool:
        """检查服务是否在线"""
        try:
            resp = requests.get(f"{self.base_url}/config", timeout=5)
            return resp.status_code == 200
        except requests.exceptions.RequestException:
            return False

    # ---- 单条语音合成 ----

    def generate(
        self,
        text: str,
        voice: str = "demo_boy.wav",
        # 情感向量 (0.0 ~ 1.0)
        emo_happy: float = 0.0,
        emo_angry: float = 0.0,
        emo_sad: float = 0.0,
        emo_afraid: float = 0.0,
        emo_disgusted: float = 0.0,
        emo_melancholic: float = 0.0,
        emo_surprised: float = 0.0,
        emo_calm: float = 0.0,
        # 情感配置
        emo_text: str = "",
        emo_alpha: float = 0.65,
        use_emo_text: bool = False,
        emo_audio: Optional[str] = None,
        use_random: bool = False,
        # 生成参数
        max_tokens_per_segment: int = 120,
        interval_silence: int = 200,
        verbose: bool = False,
        generate_subtitle: bool = False,
        speed: float = 1.0,
        volume_db: float = 0,
        # 输出
        output_dir: str = "",
        output_filename: str = "",
        output_format: str = "wav",
        # 高级参数
        do_sample: bool = True,
        temperature: float = 0.8,
        top_k: int = 30,
        top_p: float = 0.8,
        length_penalty: float = 0.0,
        num_beams: int = 3,
        repetition_penalty: float = 10.0,
        max_mel_tokens: int = 1500,
    ) -> TTSResult:
        """单条文本语音合成 (IndexTTS 2.0, Gradio v5, 32 参数)

        Args:
            text: 待合成文本
            voice: 参考音色文件名或 wav 全路径
            emo_happy: 高兴情感强度 (0.0~1.0)
            emo_angry: 愤怒情感强度 (0.0~1.0)
            emo_sad: 悲伤情感强度 (0.0~1.0)
            emo_afraid: 害怕情感强度 (0.0~1.0)
            emo_disgusted: 厌恶情感强度 (0.0~1.0)
            emo_melancholic: 忧郁情感强度 (0.0~1.0)
            emo_surprised: 惊讶情感强度 (0.0~1.0)
            emo_calm: 平静情感强度 (0.0~1.0)
            emo_text: 情感参考文本（为空则使用主文本）
            emo_alpha: 情感强度系数 (0.0~1.0)
            use_emo_text: 是否使用文本控制情感
            emo_audio: 情感参考音频路径
            use_random: 是否使用随机情感
            max_tokens_per_segment: 每段最大 token 数 (10-300)
            interval_silence: 段内静音间隔，单位毫秒 (0~)
            verbose: 是否在控制台显示详细信息
            generate_subtitle: 是否生成字幕文件
            speed: 语速调节，1.0 = 原速 (0.2-3.0)
            volume_db: 音量调节，单位分贝 (-20 ~ 20)
            output_dir: 保存路径，为空则使用服务端默认 outputs
            output_filename: 保存文件名（不含后缀），为空则自动生成
            output_format: 文件格式，"wav" 或 "mp3"
            do_sample: 是否采样
            temperature: 温度参数 (0.1-2.0)
            top_k: top-k 采样参数 (0-100)
            top_p: top-p 采样参数 (0.0-1.0)
            length_penalty: 长度惩罚 (-2.0 ~ 2.0)
            num_beams: beam search 宽度 (1-10)
            repetition_penalty: 重复惩罚 (0.1-20.0)
            max_mel_tokens: 最大 mel token 数 (50-1500)

        Returns:
            TTSResult 包含音频路径和下载 URL
        """
        # IndexTTS 2.0 服务端 Gradio v5 32 参数，严格按顺序
        params = [
            voice,                                                    # [1]  prompt 参考音色
            text,                                                     # [2]  text 待处理文本
            emo_happy,                                                # [3]  emo_vector1 高兴
            emo_angry,                                                # [4]  emo_vector2 愤怒
            emo_sad,                                                  # [5]  emo_vector3 悲伤
            emo_afraid,                                               # [6]  emo_vector4 害怕
            emo_disgusted,                                            # [7]  emo_vector5 厌恶
            emo_melancholic,                                          # [8]  emo_vector6 忧郁
            emo_surprised,                                            # [9]  emo_vector7 惊讶
            emo_calm,                                                 # [10] emo_vector8 平静
            emo_text,                                                 # [11] single_emo_text
            emo_alpha,                                                # [12] single_emo_alpha
            _bool_to_cn(use_emo_text, "使用", "不使用"),              # [13] single_use_emo_text
            emo_audio,                                                # [14] single_emo_audio
            _bool_to_cn(use_random, "使用", "不使用"),                # [15] single_use_random
            max_tokens_per_segment,                                   # [16] max_text_tokens_per_segment
            interval_silence,                                         # [17] interval_silence
            _bool_to_cn(verbose, "显示", "不显示"),                   # [18] single_verbose
            _bool_to_cn(generate_subtitle, "生成", "不生成"),         # [19] single_need_srt
            speed,                                                    # [20] single_speed
            volume_db,                                                # [21] single_volume
            output_dir or self.default_output_dir,                    # [22] output_dir
            output_filename,                                          # [23] output_file_name
            output_format,                                            # [24] single_file_suffix
            do_sample,                                                # [25] do_sample
            temperature,                                              # [26] temperature
            top_k,                                                    # [27] top_k
            top_p,                                                    # [28] top_p
            length_penalty,                                           # [29] length_penalty
            num_beams,                                                # [30] num_beams
            repetition_penalty,                                       # [31] repetition_penalty
            max_mel_tokens,                                           # [32] max_mel_tokens
        ]

        payload = _call_gradio(self.base_url, "rainfall_gen_single", params, self.timeout)
        return self._parse_audio_result(payload)

    # ---- 音色列表 ----

    def list_voices(self) -> list[VoiceInfo]:
        """获取可用音色列表

        Returns:
            VoiceInfo 列表
        """
        payload = _call_gradio(self.base_url, "refresh_single_prompt_audio", [], self.timeout)

        # Gradio v5 返回: [{"choices": [["a","a"],["b","b"]], "value": "a", "__type__": "update"}]
        voices = []
        if isinstance(payload, list):
            for item in payload:
                if isinstance(item, dict):
                    choices = item.get("choices", [])
                    for c in choices:
                        if isinstance(c, (list, tuple)) and len(c) >= 1:
                            voices.append(VoiceInfo(name=str(c[0])))
                        else:
                            voices.append(VoiceInfo(name=str(c)))
        elif isinstance(payload, dict):
            choices = payload.get("choices", [])
            for c in choices:
                if isinstance(c, (list, tuple)) and len(c) >= 1:
                    voices.append(VoiceInfo(name=str(c[0])))
                else:
                    voices.append(VoiceInfo(name=str(c)))
        return voices

    # ---- 批量文本合成 ----

    def batch_generate(
        self,
        input_dir: str,
        voice: str = "demo_boy.wav",
        output_dir: str = "",
        line_interval: float = 0.1,
        use_emo: bool = False,
        merge_lines: bool = True,
        generate_subtitle: bool = False,
        max_tokens_per_segment: int = 120,
    ) -> str:
        """批量文本语音合成 (从 txt 文件目录)

        Args:
            input_dir: txt 文件所在目录
            voice: 参考音色文件名或 wav 全路径
            output_dir: 保存路径，为空使用服务端默认
            line_interval: 单文件内每行对话间隔（秒）
            use_emo: 是否使用文本情感
            merge_lines: 连续多行是否合并
            generate_subtitle: 是否生成字幕文件
            max_tokens_per_segment: 每段最大 token 数 (10-300)

        Returns:
            服务端返回的消息字符串
        """
        params = [
            voice,                                                    # [1] 参考音色
            output_dir or self.default_output_dir,                    # [2] 保存路径
            input_dir,                                                # [3] txt目录
            line_interval,                                            # [4] 行间隔
            _bool_to_cn(use_emo, "使用", "不使用"),                   # [5] 是否使用情感
            _bool_to_cn(merge_lines, "合并", "不合并"),               # [6] 是否合并
            _bool_to_cn(generate_subtitle, "生成", "不生成"),         # [7] 是否生成字幕
            max_tokens_per_segment,                                   # [8] 每段最大token
        ]

        payload = _call_gradio(self.base_url, "single_batch_txt_generate", params, self.timeout)
        # 批量生成返回的是 markdown 文本
        if isinstance(payload, list):
            for item in payload:
                if isinstance(item, str):
                    return item
                if isinstance(item, dict):
                    val = item.get("value")
                    if isinstance(val, str):
                        return val
        return str(payload) if payload else ""

    # ---- 多角色合成 ----

    def multi_role_generate(
        self,
        text: str,
        roles: Optional[list[RoleAssignment]] = None,
        output_dir: str = "",
        output_filename: str = "",
        output_format: str = "wav",
        dialogue_interval: float = 0.1,
    ) -> TTSResult:
        """多角色对话语音合成

        文本格式示例: "小帅：你好啊！ 小美：你好，很高兴认识你。"

        Args:
            text: 对话文本，格式为 "角色名：台词"
            roles: 角色音色分配列表 (最多 10 个角色)
            output_dir: 保存路径
            output_filename: 保存文件名（不含后缀）
            output_format: 文件格式
            dialogue_interval: 对话间隔（秒）

        Returns:
            TTSResult 包含音频路径和下载 URL
        """
        if roles is None:
            roles = []

        # 多角色 API: 10 个 (角色名, 参考音频) 对 + 用户输入 + 保存路径 + 文件名 + 格式 + 间隔
        # 组件 ID 顺序: 79,80, 83,84, 87,88, 91,92, 96,97, 100,101, 104,105, 108,109, 112,113, 116,117,
        #               123, 125, 128, 129, 132
        params: list = []

        for i in range(10):
            if i < len(roles):
                role = roles[i]
                params.append(role.role_name)   # 角色名称
                params.append(role.voice)        # 参考音频
            else:
                params.append("")                # 空角色名
                params.append("")                # 空音频

        params.extend([
            text,                    # id=123 用户输入
            output_dir,              # id=125 保存路径
            output_filename,         # id=128 文件名
            output_format,           # id=129 格式
            dialogue_interval,       # id=132 对话间隔
        ])

        payload = _call_gradio(self.base_url, "rainfall_quick_multi_role_text_generate", params, self.timeout)
        return self._parse_audio_result(payload)

    # ---- 下载音频 ----

    def download_audio(self, result: TTSResult, local_path: str) -> str:
        """从服务端下载音频文件到本地

        Args:
            result: generate 或 multi_role_generate 的返回结果
            local_path: 本地保存路径

        Returns:
            本地文件绝对路径
        """
        if not result.audio_url:
            raise TTSError("没有可下载的音频 URL，请先调用 generate()")

        try:
            resp = requests.get(result.audio_url, timeout=60, stream=True)
            resp.raise_for_status()
        except requests.exceptions.RequestException as e:
            raise ConnectionError(f"下载音频失败: {e}") from e

        local_path = os.path.abspath(local_path)
        parent = os.path.dirname(local_path)
        if parent:
            os.makedirs(parent, exist_ok=True)

        with open(local_path, "wb") as f:
            for chunk in resp.iter_content(chunk_size=8192):
                f.write(chunk)

        result.local_path = local_path
        return local_path

    # ---- 内部工具 ----

    def _parse_audio_result(self, payload: object) -> TTSResult:
        """解析 Gradio v5 返回的音频结果

        已知返回格式:
          - dict: {"visible": True, "value": "/path/to/file.wav", "__type__": "update"}
          - dict: {"visible": True, "value": {"path": "...", "url": "..."}, "__type__": "update"}
          - list: [以上 dict]
          - str: 直接文件路径
        """
        audio_path = ""
        audio_url = ""

        if payload is None:
            raise TTSError("服务端返回空结果")

        if isinstance(payload, list):
            for item in payload:
                result = self._extract_audio_from_item(item)
                if result:
                    return result
        elif isinstance(payload, dict):
            result = self._extract_audio_from_item(payload)
            if result:
                return result
        elif isinstance(payload, str):
            audio_path = payload

        if not audio_path and not audio_url:
            raise TTSError(f"无法解析音频结果: {payload}")

        if not audio_url and audio_path:
            encoded = urllib.parse.quote(audio_path, safe="/")
            audio_url = f"{self.base_url}/gradio_api/file={encoded}"

        return TTSResult(audio_path=audio_path, audio_url=audio_url)

    def _extract_audio_from_item(self, item: object) -> Optional[TTSResult]:
        """从单个 Gradio 返回项中提取音频信息"""
        if not isinstance(item, dict):
            if isinstance(item, str) and (item.endswith(".wav") or item.endswith(".mp3")):
                audio_path = item
                encoded = urllib.parse.quote(audio_path, safe="/")
                audio_url = f"{self.base_url}/gradio_api/file={encoded}"
                return TTSResult(audio_path=audio_path, audio_url=audio_url)
            return None

        # Gradio v5: {"visible": True, "value": <path_or_dict>, "__type__": "update"}
        val = item.get("value")

        if isinstance(val, str) and (val.endswith(".wav") or val.endswith(".mp3")):
            audio_path = val
            encoded = urllib.parse.quote(audio_path, safe="/")
            audio_url = f"{self.base_url}/gradio_api/file={encoded}"
            return TTSResult(audio_path=audio_path, audio_url=audio_url)

        if isinstance(val, dict):
            audio_path = val.get("path", "")
            audio_url = val.get("url", "")
            if audio_path or audio_url:
                if not audio_url and audio_path:
                    encoded = urllib.parse.quote(audio_path, safe="/")
                    audio_url = f"{self.base_url}/gradio_api/file={encoded}"
                return TTSResult(audio_path=audio_path, audio_url=audio_url)

        # 兜底：item 本身包含 path/url
        if "path" in item or "url" in item:
            audio_path = item.get("path", "")
            audio_url = item.get("url", "")
            if audio_path or audio_url:
                if not audio_url and audio_path:
                    encoded = urllib.parse.quote(audio_path, safe="/")
                    audio_url = f"{self.base_url}/gradio_api/file={encoded}"
                return TTSResult(audio_path=audio_path, audio_url=audio_url)

        return None


# ---------------------------------------------------------------------------
# 异步支持 (可选)
# ---------------------------------------------------------------------------

try:
    import aiohttp

    class AsyncRainfallTTS:
        """雨落TTS 异步 SDK 客户端

        接口与 RainfallTTS 一致，所有方法均为 async。
        需要安装 aiohttp: pip install aiohttp
        """

        def __init__(self, base_url: str = "http://127.0.0.1:7861", timeout: float = 300.0):
            self.base_url = base_url.rstrip("/")
            self.timeout = timeout

        async def is_server_alive(self) -> bool:
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(f"{self.base_url}/config", timeout=aiohttp.ClientTimeout(total=5)) as resp:
                        return resp.status == 200
            except Exception:
                return False

        async def _call(self, endpoint: str, data: list) -> object:
            call_url = f"{self.base_url}{_GRADIO_API_PREFIX}/call/{endpoint}"
            async with aiohttp.ClientSession() as session:
                async with session.post(call_url, json={"data": data}, timeout=aiohttp.ClientTimeout(total=30)) as resp:
                    if resp.status != 200:
                        text = await resp.text()
                        raise ServerError(f"提交任务失败，HTTP {resp.status}: {text[:500]}")
                    result = await resp.json()

                event_id = result.get("event_id")
                if not event_id:
                    raise ServerError(f"未获取到 event_id: {result}")

                sse_url = f"{call_url}/{event_id}"
                async with session.get(sse_url, timeout=aiohttp.ClientTimeout(total=self.timeout)) as resp:
                    if resp.status != 200:
                        text = await resp.text()
                        raise ServerError(f"获取结果失败，HTTP {resp.status}: {text[:500]}")

                    last_data = None
                    async for line in resp.content:
                        line = line.decode("utf-8").strip()
                        if not line:
                            continue
                        if line.startswith("data:"):
                            payload_str = line.split(":", 1)[1].strip()
                            try:
                                last_data = json.loads(payload_str)
                            except json.JSONDecodeError:
                                last_data = payload_str
                    return last_data

        async def generate(self, text: str, voice: str = "demo_boy.wav", **kwargs) -> TTSResult:
            sync_client = RainfallTTS(self.base_url, self.timeout)

            params = [
                voice,
                text,
                kwargs.get("emo_happy", 0.0),
                kwargs.get("emo_angry", 0.0),
                kwargs.get("emo_sad", 0.0),
                kwargs.get("emo_afraid", 0.0),
                kwargs.get("emo_disgusted", 0.0),
                kwargs.get("emo_melancholic", 0.0),
                kwargs.get("emo_surprised", 0.0),
                kwargs.get("emo_calm", 0.0),
                kwargs.get("emo_text", ""),
                kwargs.get("emo_alpha", 0.65),
                _bool_to_cn(kwargs.get("use_emo_text", False), "使用", "不使用"),
                kwargs.get("emo_audio", None),
                _bool_to_cn(kwargs.get("use_random", False), "使用", "不使用"),
                kwargs.get("max_tokens_per_segment", 120),
                kwargs.get("interval_silence", 200),
                _bool_to_cn(kwargs.get("verbose", False), "显示", "不显示"),
                _bool_to_cn(kwargs.get("generate_subtitle", False), "生成", "不生成"),
                kwargs.get("speed", 1.0),
                kwargs.get("volume_db", 0),
                kwargs.get("output_dir", "outputs"),
                kwargs.get("output_filename", ""),
                kwargs.get("output_format", "wav"),
                kwargs.get("do_sample", True),
                kwargs.get("temperature", 0.8),
                kwargs.get("top_k", 30),
                kwargs.get("top_p", 0.8),
                kwargs.get("length_penalty", 0.0),
                kwargs.get("num_beams", 3),
                kwargs.get("repetition_penalty", 10.0),
                kwargs.get("max_mel_tokens", 1500),
            ]
            payload = await self._call("rainfall_gen_single", params)
            return sync_client._parse_audio_result(payload)

        async def list_voices(self) -> list[VoiceInfo]:
            payload = await self._call("refresh_single_prompt_audio", [])
            voices = []
            if isinstance(payload, list):
                for item in payload:
                    if isinstance(item, list) and len(item) == 2:
                        voices.append(VoiceInfo(name=str(item[0])))
            return voices

        async def download_audio(self, result: TTSResult, local_path: str) -> str:
            if not result.audio_url:
                raise TTSError("没有可下载的音频 URL")
            async with aiohttp.ClientSession() as session:
                async with session.get(result.audio_url, timeout=aiohttp.ClientTimeout(total=60)) as resp:
                    resp.raise_for_status()
                    local_path = os.path.abspath(local_path)
                    parent = os.path.dirname(local_path)
                    if parent:
                        os.makedirs(parent, exist_ok=True)
                    with open(local_path, "wb") as f:
                        async for chunk in resp.content.iter_chunked(8192):
                            f.write(chunk)
            result.local_path = local_path
            return local_path

except ImportError:
    # aiohttp 未安装时，AsyncRainfallTTS 不可用
    AsyncRainfallTTS = None  # type: ignore[assignment, misc]


# ---------------------------------------------------------------------------
# 便捷函数 — 模块级一行调用
# ---------------------------------------------------------------------------

_default_client: Optional[RainfallTTS] = None


def _get_default_client() -> RainfallTTS:
    global _default_client
    if _default_client is None:
        _default_client = RainfallTTS()
    return _default_client


def generate(text: str, voice: str = "demo_boy.wav", **kwargs) -> TTSResult:
    """便捷函数：使用默认客户端合成语音

    Args:
        text: 待合成文本
        voice: 参考音色文件名
        **kwargs: 传递给 RainfallTTS.generate() 的其他参数

    Returns:
        TTSResult
    """
    return _get_default_client().generate(text, voice=voice, **kwargs)


def list_voices() -> list[VoiceInfo]:
    """便捷函数：获取可用音色列表"""
    return _get_default_client().list_voices()


# ---------------------------------------------------------------------------
# __main__ 测试
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    sys.stdout.reconfigure(encoding="utf-8")

    BASE_URL = "http://127.0.0.1:7861"
    client = RainfallTTS(BASE_URL)

    print(f"=== 雨落TTS SDK 测试 ===")
    print(f"服务地址: {BASE_URL}")

    # 1. 健康检查
    print("\n--- 1. 健康检查 ---")
    alive = client.is_server_alive()
    print(f"服务在线: {alive}")
    if not alive:
        print("服务未启动，测试终止。请先启动雨落AI语音服务。")
        sys.exit(1)

    # 2. 音色列表
    print("\n--- 2. 获取音色列表 ---")
    try:
        voices = client.list_voices()
        print(f"可用音色 ({len(voices)} 个):")
        for v in voices:
            print(f"  - {v.name}")
    except Exception as e:
        print(f"获取音色失败: {e}")

    # 3. 单条合成
    print("\n--- 3. 单条语音合成测试 ---")
    try:
        result = client.generate("你好，这是雨落TTS SDK的测试语音。")
        print(f"合成成功!")
        print(f"  audio_path: {result.audio_path}")
        print(f"  audio_url:  {result.audio_url}")

        # 4. 下载音频
        output_file = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "outputs",
            "sdk_test_output.wav",
        )
        print(f"\n--- 4. 下载音频到 {output_file} ---")
        local = client.download_audio(result, output_file)
        print(f"下载成功: {local}")
    except Exception as e:
        print(f"合成/下载失败: {e}")

    print("\n=== 测试完成 ===")
