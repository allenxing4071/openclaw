#!/usr/bin/env python3
"""
智能模型路由器
根据用户输入快速判断应该使用哪个模型

用法:
  python route.py "用户的问题"
  python route.py --json "用户的问题"
"""

import sys
import json
import re

# 模型定义 - 各模型发挥专长
MODELS = {
    "code": {
        "id": "deepseek/deepseek-coder",
        "name": "DeepSeek Coder",
        "fallback": "qwen/qwen-turbo",
        "description": "代码生成、调试、重构 (DeepSeek Coder)"
    },
    "vision": {
        "id": "qwen/qwen-plus",
        "name": "Qwen Plus",
        "fallback": "deepseek/deepseek-chat",
        "description": "图片理解、视觉分析 (Qwen Plus)"
    },
    "reasoning": {
        "id": "deepseek/deepseek-reasoner",
        "name": "DeepSeek R1 (Reasoning)",
        "fallback": "deepseek/deepseek-chat",
        "description": "复杂推理、深度分析 (DeepSeek R1)"
    },
    "fast": {
        "id": "qwen/qwen-turbo",
        "name": "Qwen Turbo",
        "fallback": "deepseek/deepseek-chat",
        "description": "快速响应、简单问题 (Qwen Turbo)"
    },
    "general": {
        "id": "deepseek/deepseek-chat",
        "name": "DeepSeek Chat",
        "fallback": "qwen/qwen-plus",
        "description": "通用对话、综合任务 (DeepSeek Chat)"
    }
}

# 关键词规则
RULES = [
    {
        "category": "code",
        "keywords": [
            r"代码", r"编程", r"调试", r"debug", r"bug", r"函数", r"api",
            r"重构", r"refactor", r"实现", r"implement", r"开发", r"写代码",
            r"code", r"程序", r"脚本", r"script", r"算法", r"algorithm",
            r"python", r"javascript", r"typescript", r"java", r"golang",
            r"rust", r"c\+\+", r"sql", r"html", r"css", r"react", r"vue",
            r"node", r"npm", r"git", r"commit", r"pr", r"pull request",
            r"修复", r"fix", r"错误", r"error", r"异常", r"exception"
        ],
        "weight": 10
    },
    {
        "category": "vision",
        "keywords": [
            r"图片", r"图像", r"看图", r"分析图", r"截图", r"照片",
            r"image", r"picture", r"screenshot", r"photo", r"看一下这个",
            r"这张图", r"图中", r"画面", r"视觉", r"visual", r"ocr",
            r"识别图", r"图表", r"chart", r"diagram"
        ],
        "weight": 15  # 视觉模型优先级更高
    },
    {
        "category": "reasoning",
        "keywords": [
            r"推理", r"分析", r"为什么", r"证明", r"逻辑", r"数学",
            r"计算", r"reasoning", r"prove", r"analyze", r"think step",
            r"详细解释", r"深入分析", r"原理", r"机制", r"复杂",
            r"比较.*优缺点", r"评估", r"evaluate", r"思考"
        ],
        "weight": 8
    },
    {
        "category": "fast",
        "keywords": [
            r"^你好$", r"^hi$", r"^hello$", r"翻译", r"translate",
            r"是什么意思", r"定义", r"简单", r"快速", r"简短"
        ],
        "weight": 5
    }
]


def classify_input(text: str) -> dict:
    """分类用户输入"""
    text_lower = text.lower()
    scores = {"code": 0, "vision": 0, "reasoning": 0, "fast": 0, "general": 0}
    matched_keywords = []
    
    for rule in RULES:
        category = rule["category"]
        weight = rule["weight"]
        for keyword in rule["keywords"]:
            if re.search(keyword, text_lower):
                scores[category] += weight
                matched_keywords.append(keyword)
    
    # 如果没有明确匹配，使用通用模型
    if max(scores.values()) == 0:
        # 检查文本长度决定用快速还是通用
        if len(text) < 20:
            scores["fast"] = 1
        else:
            scores["general"] = 1
    
    # 找到得分最高的类别
    best_category = max(scores, key=scores.get)
    
    return {
        "category": best_category,
        "model": MODELS[best_category],
        "scores": scores,
        "matched_keywords": list(set(matched_keywords)),
        "confidence": "high" if max(scores.values()) >= 10 else "medium" if max(scores.values()) >= 5 else "low"
    }


def main():
    # 解析参数
    json_output = "--json" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    
    if not args:
        print("用法: python route.py [--json] \"用户的问题\"")
        sys.exit(1)
    
    user_input = " ".join(args)
    result = classify_input(user_input)
    
    if json_output:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        model = result["model"]
        print(f"📍 场景: {result['category']}")
        print(f"🎯 推荐模型: {model['id']}")
        print(f"📝 说明: {model['description']}")
        print(f"🔄 备用: {model['fallback']}")
        print(f"📊 置信度: {result['confidence']}")
        if result['matched_keywords']:
            print(f"🔑 匹配词: {', '.join(result['matched_keywords'][:5])}")
        print(f"\n执行命令: /model {model['id']}")


if __name__ == "__main__":
    main()
