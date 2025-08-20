#!/bin/bash
# 获取当前session的context token使用量
# 支持 JSONL 格式的 transcript 文件

# 调试模式（设置 DEBUG_TOKENS=1 启用）
debug_log() {
    if [[ "$DEBUG_TOKENS" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# 生成进度条的函数
generate_progress_bar() {
    local used_percentage=$1
    local filled_boxes=$(echo "$used_percentage / 10" | bc)
    local empty_boxes=$(echo "10 - $filled_boxes" | bc)
    
    # 确保范围正确
    if [[ $filled_boxes -gt 10 ]]; then
        filled_boxes=10
        empty_boxes=0
    elif [[ $filled_boxes -lt 0 ]]; then
        filled_boxes=0
        empty_boxes=10
    fi
    
    # 生成进度条
    local bar=""
    for ((i=0; i<filled_boxes; i++)); do
        bar+="■"
    done
    for ((i=0; i<empty_boxes; i++)); do
        bar+="□"
    done
    
    echo "$bar"
}

# 格式化token数量的函数 - 返回使用百分比和进度条（基于160k限制）
format_tokens() {
    local tokens=$1
    # 基于160k（80% * 200k）计算使用百分比
    local used_percentage=$(echo "$tokens * 100 / 160000" | bc)
    
    # 确保使用百分比不超过100%
    if [[ $used_percentage -gt 100 ]]; then
        used_percentage=100
    fi
    
    # 生成进度条
    local progress_bar=$(generate_progress_bar "$used_percentage")
    
    echo "${progress_bar} ${used_percentage}%"
}

# 从stdin获取JSON输入
input=$(cat)
debug_log "收到输入数据长度: ${#input} 字符"

# 检查输入是否为空
if [[ -z "$input" ]]; then
    debug_log "错误: 输入为空"
    echo "N/A"
    exit 0
fi

# 提取transcript_path
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
debug_log "提取的 transcript_path: $transcript_path"

# 检查transcript文件是否存在
if [[ -z "$transcript_path" ]]; then
    debug_log "错误: transcript_path 为空"
    echo "N/A"
    exit 0
fi

if [[ ! -f "$transcript_path" ]]; then
    debug_log "错误: transcript 文件不存在: $transcript_path"
    echo "N/A"
    exit 0
fi

debug_log "成功找到 transcript 文件: $transcript_path"

# 使用jq处理JSONL文件，查找最后一个有效的assistant消息
result=$(jq -r --slurp '
    # 过滤有效的JSON行并反转数组以获得最新的记录
    [.[] | select(type == "object")] | reverse |
    # 查找第一个符合条件的assistant消息
    map(select(
        .type == "assistant" and
        .message.usage != null and
        (.message.usage | has("input_tokens") and has("cache_creation_input_tokens") and has("cache_read_input_tokens") and has("output_tokens"))
    )) |
    # 如果找到，计算总token数；否则返回null
    if length > 0 then
        first.message.usage | 
        (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)
    else
        null
    end
' "$transcript_path" 2>/dev/null)

debug_log "jq处理结果: $result"

# 输出结果
if [[ "$result" != "null" && "$result" =~ ^[0-9]+$ && "$result" -gt 0 ]]; then
    # 使用新的格式化函数
    formatted_tokens=$(format_tokens "$result")
    debug_log "最终输出: $formatted_tokens"
    echo "$formatted_tokens"
else
    debug_log "最终输出: N/A (未找到有效 token 数据)"
    echo "N/A"
fi