---
name: smart-router
description: 智能模型路由器 - 根据用户请求自动选择最合适的模型
metadata:
  {
    "openclaw": { 
      "emoji": "🔀",
      "priority": 100
    }
  }
---

# 智能模型路由器 (Smart Router)

这个 Skill 实现智能模型路由：根据用户请求的类型，自动选择最合适的模型。

## 路由规则

当收到用户请求时，**首先**根据以下规则判断并切换到合适的模型：

### 1. 代码相关 → Coder 模型
**触发词:** 代码、编程、调试、bug、函数、API、重构、实现、开发、写代码、code、debug、implement、refactor

**推荐模型:** `ollama/qwen3-coder:480b-cloud` 或 `ollama/qwen2.5-coder:32b`

```
/model ollama/qwen3-coder:480b-cloud
```

### 2. 图片/视觉相关 → VL 模型
**触发词:** 图片、图像、看图、分析图、截图、照片、image、picture、screenshot、看一下这个、这张图

**推荐模型:** `ollama/qwen3-vl:235b-cloud` 或 `ollama/qwen3-vl:30b`

```
/model ollama/qwen3-vl:235b-cloud
```

### 3. 复杂推理/数学/逻辑 → Reasoner 模型
**触发词:** 推理、分析、为什么、证明、逻辑、数学、计算、reasoning、prove、analyze、think step by step

**推荐模型:** `ollama/deepseek-v3.1:671b-cloud` (reasoning=true)

```
/model ollama/deepseek-v3.1:671b-cloud
```

### 4. 快速简单问题 → 轻量模型
**触发词:** 简单问题、翻译、定义、是什么、快速回答

**推荐模型:** `ollama/qwen3:8b` 或 `qwen/qwen-turbo`

```
/model ollama/qwen3:8b
```

### 5. 通用对话 → 默认强模型
**其他情况**

**推荐模型:** `ollama/deepseek-v3.1:671b-cloud`

```
/model ollama/deepseek-v3.1:671b-cloud
```

## 自动路由流程

每次收到用户消息时：

1. **快速分类** - 扫描关键词判断请求类型
2. **检查当前模型** - 如果已在合适模型上，继续；否则切换
3. **执行切换** - 使用 `/model <model-id>` 切换
4. **处理请求** - 用新模型回答用户

## 模型速查表

| 场景 | 主模型 | 备用 | 理由 |
|------|--------|------|------|
| 代码 | `qwen3-coder:480b-cloud` | `qwen2.5-coder:32b` | 专业代码模型 |
| 图片 | `qwen3-vl:235b-cloud` | `qwen3-vl:30b` | 专业视觉模型 |
| 推理 | `deepseek-v3.1:671b-cloud` | `deepseek-reasoner` | 671B推理最强 |
| 快速 | `qwen3:8b` (本地) | `gemini-2.5-flash` | 本地零延迟 |
| 通用 | `deepseek-v3.1:671b-cloud` | `gemini-2.5-pro` | 671B通用最强 |

## 手动切换命令

用户可以随时手动切换模型：

```
/model ollama/qwen3-coder:480b-cloud   # 代码专用
/model ollama/qwen3-vl:235b-cloud      # 图片专用
/model ollama/deepseek-v3.1:671b-cloud # 推理/通用 (主力)
/model ollama/qwen3:8b                 # 本地快速
/model google/gemini-2.5-pro           # Gemini (备用)
```

## 注意事项

1. **本地模型优先** - 如果请求不需要云端能力，优先使用本地模型减少延迟
2. **图片必须用 VL** - 只有 VL 模型支持图片输入
3. **长对话用强模型** - 上下文复杂时使用 671B 模型
4. **简单问题用轻量** - 节省资源，响应更快

## 示例对话

**用户:** 帮我写一个 Python 排序函数
**路由:** 检测到"代码"关键词 → 切换到 `qwen3-coder:480b-cloud`

**用户:** 看看这张图片是什么
**路由:** 检测到"图片"关键词 → 切换到 `qwen3-vl:235b-cloud`

**用户:** 为什么天空是蓝色的？详细解释一下
**路由:** 检测到"为什么"+"详细" → 切换到 `deepseek-v3.1:671b-cloud`

**用户:** 你好
**路由:** 简单问候 → 使用 `qwen3:8b` 快速响应
