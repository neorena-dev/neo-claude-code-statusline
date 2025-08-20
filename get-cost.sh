#!/bin/bash
# 获取每日使用费用，返回格式化的价格字符串
# 格式：<当日费用> / <当月总费用>

# 尝试获取 ccusage 数据
if ! command -v ccusage &> /dev/null; then
    echo "N/A"
    exit 0
fi

# 获取当日费用数据
daily_cost=$(ccusage daily -j 2>/dev/null | jq -r '.daily[-1].totalCost // empty' 2>/dev/null)

# 获取当月总费用数据
monthly_cost=$(ccusage monthly -j 2>/dev/null | jq -r '.monthly[-1].totalCost // empty' 2>/dev/null)

# 检查是否成功获取到数据
if [[ -z "$daily_cost" || "$daily_cost" == "null" ]]; then
    daily_cost="N/A"
else
    # 只取整数部分（去掉小数）
    daily_cost="${daily_cost%.*}"
fi

if [[ -z "$monthly_cost" || "$monthly_cost" == "null" ]]; then
    monthly_cost="N/A"
else
    # 只取整数部分（去掉小数）
    monthly_cost="${monthly_cost%.*}"
fi

# 输出格式：当日费用 / 当月总费用
echo "${daily_cost}/${monthly_cost}"