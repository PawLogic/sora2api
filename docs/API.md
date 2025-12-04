# Sora2API 接口文档

本文档详细说明如何使用 Sora2API 创建角色和生成视频/图片。

## 基础信息

### 接口地址
```
POST /v1/chat/completions
```

### 认证方式
```
Authorization: Bearer <your-api-key>
```

### 请求格式
```json
{
    "model": "模型名称",
    "messages": [{"role": "user", "content": "..."}],
    "stream": true
}
```

> **重要**: 生成功能必须使用 `stream: true`，非流式模式仅用于检查 token 可用性。

---

## 可用模型

### 图片模型
| 模型名称 | 分辨率 | 说明 |
|---------|--------|------|
| `sora-image` | 360x360 | 正方形图片 |
| `sora-image-landscape` | 540x360 | 横版图片 |
| `sora-image-portrait` | 360x540 | 竖版图片 |

### 视频模型
| 模型名称 | 方向 | 时长 |
|---------|------|------|
| `sora-video-10s` / `sora-video-landscape-10s` | 横版 | 10秒 |
| `sora-video-portrait-10s` | 竖版 | 10秒 |
| `sora-video-15s` / `sora-video-landscape-15s` | 横版 | 15秒 |
| `sora-video-portrait-15s` | 竖版 | 15秒 |

---

## 功能一：创建角色

上传视频创建可复用的角色，角色会自动设置为公开。

### 请求示例

```bash
curl -X POST "http://your-server:8000/v1/chat/completions" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora-video-landscape-10s",
    "messages": [{
      "role": "user",
      "content": [
        {
          "type": "video_url",
          "video_url": {
            "url": "data:video/mp4;base64,AAAAIGZ0eXBpc29t..."
          }
        }
      ]
    }],
    "stream": true
  }'
```

### Python 示例

```python
import requests
import base64

# 读取视频文件
with open("character.mp4", "rb") as f:
    video_base64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://your-server:8000/v1/chat/completions",
    headers={
        "Authorization": "Bearer your-api-key",
        "Content-Type": "application/json"
    },
    json={
        "model": "sora-video-landscape-10s",
        "messages": [{
            "role": "user",
            "content": [
                {
                    "type": "video_url",
                    "video_url": {
                        "url": f"data:video/mp4;base64,{video_base64}"
                    }
                }
            ]
        }],
        "stream": True
    },
    stream=True
)

# 处理流式响应
for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))
```

### 响应示例

```
data: {"choices": [{"delta": {"reasoning_content": "**Character Creation Begins**\n\nInitializing..."}}]}
data: {"choices": [{"delta": {"reasoning_content": "Uploading video file..."}}]}
data: {"choices": [{"delta": {"reasoning_content": "Processing video to extract character..."}}]}
data: {"choices": [{"delta": {"reasoning_content": "✨ 角色已识别: Character Name (@username123)"}}]}
data: {"choices": [{"delta": {"content": "角色创建成功，角色名@username123"}}]}
data: [DONE]
```

### 关键点
- 只传入 `video_url`，不传入 `text` = 仅创建角色
- 返回的 `@username` 可用于后续视频生成
- 视频建议时长 3-10 秒，清晰展示角色

---

## 功能二：使用角色生成视频

使用已创建的角色（通过 `@username`）生成新视频。

### 请求示例

```bash
curl -X POST "http://your-server:8000/v1/chat/completions" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora-video-landscape-10s",
    "messages": [{
      "role": "user",
      "content": "@username123 在公园里奔跑，追逐蝴蝶"
    }],
    "stream": true
  }'
```

### Python 示例

```python
import requests

response = requests.post(
    "http://your-server:8000/v1/chat/completions",
    headers={
        "Authorization": "Bearer your-api-key",
        "Content-Type": "application/json"
    },
    json={
        "model": "sora-video-landscape-10s",
        "messages": [{
            "role": "user",
            "content": "@username123 在阳光明媚的公园里欢快地奔跑"
        }],
        "stream": True
    },
    stream=True
)

for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))
```

### 响应示例

```
data: {"choices": [{"delta": {"reasoning_content": "**Generation Process Begins**\n\nInitializing..."}}]}
data: {"choices": [{"delta": {"reasoning_content": "**Video Generation Progress**: 0% (queued)"}}]}
data: {"choices": [{"delta": {"reasoning_content": "**Video Generation Progress**: 50% (processing)"}}]}
data: {"choices": [{"delta": {"reasoning_content": "**Video Generation Completed**"}}]}
data: {"choices": [{"delta": {"content": "```html\n<video src='https://...mp4' controls></video>\n```"}}]}
data: [DONE]
```

---

## 功能三：创建角色并生成视频（一步完成）

同时上传角色视频和提供 prompt，一步完成角色创建和视频生成。

### 请求示例

```bash
curl -X POST "http://your-server:8000/v1/chat/completions" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora-video-landscape-10s",
    "messages": [{
      "role": "user",
      "content": [
        {
          "type": "video_url",
          "video_url": {
            "url": "data:video/mp4;base64,AAAAIGZ0eXBpc29t..."
          }
        },
        {
          "type": "text",
          "text": "角色在海边散步，夕阳西下"
        }
      ]
    }],
    "stream": true
  }'
```

### Python 示例

```python
import requests
import base64

with open("character.mp4", "rb") as f:
    video_base64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://your-server:8000/v1/chat/completions",
    headers={
        "Authorization": "Bearer your-api-key",
        "Content-Type": "application/json"
    },
    json={
        "model": "sora-video-landscape-10s",
        "messages": [{
            "role": "user",
            "content": [
                {
                    "type": "video_url",
                    "video_url": {
                        "url": f"data:video/mp4;base64,{video_base64}"
                    }
                },
                {
                    "type": "text",
                    "text": "角色在海边散步，夕阳西下"
                }
            ]
        }],
        "stream": True
    },
    stream=True
)

for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))
```

### 响应示例

```
data: {"choices": [{"delta": {"reasoning_content": "**Character Creation and Video Generation Begins**\n\nInitializing..."}}]}
data: {"choices": [{"delta": {"reasoning_content": "Uploading video file..."}}]}
data: {"choices": [{"delta": {"reasoning_content": "✨ 角色已识别: Character Name (@username123)"}}]}
data: {"choices": [{"delta": {"reasoning_content": "Setting character as public..."}}]}
data: {"choices": [{"delta": {"reasoning_content": "**Video Generation Progress**: 50% (processing)"}}]}
data: {"choices": [{"delta": {"reasoning_content": "**Video Generation Completed**"}}]}
data: {"choices": [{"delta": {"content": "```html\n<video src='https://...mp4' controls></video>\n```\n\n角色已保存: @username123"}}]}
data: [DONE]
```

### 关键点
- 同时传入 `video_url` 和 `text` = 创建角色 + 生成视频
- 角色创建后会立即用于视频生成
- **角色会被保留并设为公开**，可在后续使用 `@username` 继续生成
- 响应中同时包含**视频 URL** 和**角色用户名**

---

## 功能四：使用参考图生成视频

上传参考图作为视频的起始帧。

### 请求示例

```bash
curl -X POST "http://your-server:8000/v1/chat/completions" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora-video-landscape-10s",
    "messages": [{
      "role": "user",
      "content": [
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,iVBORw0KGgo..."
          }
        },
        {
          "type": "text",
          "text": "画面中的场景开始下雨，雨滴落在地面上"
        }
      ]
    }],
    "stream": true
  }'
```

### Python 示例

```python
import requests
import base64

# 读取图片
with open("reference.png", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://your-server:8000/v1/chat/completions",
    headers={
        "Authorization": "Bearer your-api-key",
        "Content-Type": "application/json"
    },
    json={
        "model": "sora-video-landscape-10s",
        "messages": [{
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/png;base64,{image_base64}"
                    }
                },
                {
                    "type": "text",
                    "text": "画面中的场景开始下雨"
                }
            ]
        }],
        "stream": True
    },
    stream=True
)
```

### 关键点
- 参考图作为视频的**起始帧**（inpaint_items）
- 不是风格迁移，视频会从这张图开始动起来
- 如需特定风格，请在 prompt 中详细描述

---

## 功能五：Remix 已有视频

基于 Sora 分享链接的视频进行二次创作。

### 请求示例

```bash
# 方式一：在 prompt 中包含链接
curl -X POST "http://your-server:8000/v1/chat/completions" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora-video-landscape-10s",
    "messages": [{
      "role": "user",
      "content": "https://sora.chatgpt.com/p/s_68e3a06dcd888191b150971da152c1f5 将场景改为夜晚"
    }],
    "stream": true
  }'

# 方式二：使用 remix_target_id 参数
curl -X POST "http://your-server:8000/v1/chat/completions" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora-video-landscape-10s",
    "messages": [{
      "role": "user",
      "content": "将场景改为夜晚，添加星空"
    }],
    "remix_target_id": "s_68e3a06dcd888191b150971da152c1f5",
    "stream": true
  }'
```

### Remix ID 格式
- 完整链接: `https://sora.chatgpt.com/p/s_68e3a06dcd888191b150971da152c1f5`
- 短 ID: `s_68e3a06dcd888191b150971da152c1f5`

---

## 功能六：生成图片

使用图片模型生成静态图片。

### 请求示例

```bash
curl -X POST "http://your-server:8000/v1/chat/completions" \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora-image-landscape",
    "messages": [{
      "role": "user",
      "content": "一只可爱的猫咪坐在窗台上，阳光洒在它身上"
    }],
    "stream": true
  }'
```

---

## 响应格式

### 流式响应 (SSE)

每个数据块格式：
```
data: {"id": "chatcmpl-xxx", "object": "chat.completion.chunk", "choices": [{"delta": {...}}]}
```

Delta 字段说明：
| 字段 | 说明 |
|------|------|
| `reasoning_content` | 处理进度信息（状态更新） |
| `content` | 最终结果（视频/图片 URL） |

### 结束标记
```
data: [DONE]
```

### 错误响应
```json
{
  "error": {
    "message": "错误信息",
    "type": "server_error",
    "param": null,
    "code": null
  }
}
```

---

## 完整 Python 客户端示例

```python
import requests
import base64
import json
import re

class SoraClient:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip('/')
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

    def _stream_request(self, payload: dict) -> tuple[str, str]:
        """发送流式请求，返回 (final_content, reasoning)"""
        response = requests.post(
            f"{self.base_url}/v1/chat/completions",
            headers=self.headers,
            json=payload,
            stream=True,
            timeout=600
        )

        content = ""
        reasoning = ""

        for line in response.iter_lines():
            if line:
                line_str = line.decode('utf-8')
                if line_str.startswith("data: "):
                    data = line_str[6:]
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                        if "error" in chunk:
                            raise Exception(chunk["error"]["message"])
                        if "choices" in chunk and chunk["choices"]:
                            delta = chunk["choices"][0].get("delta", {})
                            if delta.get("content"):
                                content += delta["content"]
                            if delta.get("reasoning_content"):
                                reasoning += delta["reasoning_content"]
                    except json.JSONDecodeError:
                        pass

        return content, reasoning

    def create_character(self, video_path: str) -> str:
        """创建角色，返回 @username"""
        with open(video_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode()

        payload = {
            "model": "sora-video-landscape-10s",
            "messages": [{
                "role": "user",
                "content": [{
                    "type": "video_url",
                    "video_url": {"url": f"data:video/mp4;base64,{video_base64}"}
                }]
            }],
            "stream": True
        }

        content, reasoning = self._stream_request(payload)

        # 提取 @username
        match = re.search(r'@\w+', content)
        return match.group(0) if match else content

    def generate_video(self, prompt: str, model: str = "sora-video-landscape-10s") -> str:
        """生成视频，返回视频 URL"""
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": True
        }

        content, _ = self._stream_request(payload)

        # 提取视频 URL
        match = re.search(r'https?://[^\s\'"]+\.mp4[^\s\'"]*', content)
        return match.group(0) if match else content

    def generate_video_with_image(self, prompt: str, image_path: str) -> str:
        """使用参考图生成视频"""
        with open(image_path, "rb") as f:
            image_base64 = base64.b64encode(f.read()).decode()

        # 根据文件扩展名确定 MIME 类型
        ext = image_path.lower().split('.')[-1]
        mime_type = f"image/{ext}" if ext in ['png', 'jpg', 'jpeg', 'gif', 'webp'] else "image/png"

        payload = {
            "model": "sora-video-landscape-10s",
            "messages": [{
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{image_base64}"}
                    },
                    {"type": "text", "text": prompt}
                ]
            }],
            "stream": True
        }

        content, _ = self._stream_request(payload)
        match = re.search(r'https?://[^\s\'"]+\.mp4[^\s\'"]*', content)
        return match.group(0) if match else content


# 使用示例
if __name__ == "__main__":
    client = SoraClient("http://your-server:8000", "your-api-key")

    # 1. 创建角色
    username = client.create_character("my_character.mp4")
    print(f"Created character: {username}")

    # 2. 使用角色生成视频
    video_url = client.generate_video(f"{username} 在公园里奔跑")
    print(f"Video URL: {video_url}")

    # 3. 使用参考图生成视频
    video_url = client.generate_video_with_image(
        "场景开始下雨",
        "reference.png"
    )
    print(f"Video with reference: {video_url}")
```

---

## 常见问题

### Q: 为什么必须使用 stream: true？
A: 视频/图片生成是长时间运行的任务，流式模式可以实时返回进度信息。非流式模式仅用于检查 token 可用性。

### Q: 角色创建后能永久使用吗？
A: 是的。无论是仅创建角色还是创建角色+生成视频，角色都会保留并设为公开，可以通过 `@username` 反复使用。

### Q: 参考图是用于风格迁移吗？
A: 不是。参考图作为视频的起始帧（inpaint_items），视频会从这张图开始动起来。如需特定风格，请在 prompt 中详细描述。

### Q: 支持哪些视频格式？
A: 推荐使用 MP4 格式，视频时长建议 3-10 秒。

### Q: 如何获取已创建角色的列表？
A: 当前 API 不支持列出角色。请在创建时记录返回的 @username。
