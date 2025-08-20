#!/bin/bash
# 获取每日使用费用，返回格式化的价格字符串
# 格式：<当日费用> / <当月总费用> [+/-X%]
# 百分比表示相对于历史平均水平的差异

# 格式化费用显示（添加k和m进位）
format_cost() {
    local cost="$1"
    
    # 如果是N/A，直接返回
    if [[ "$cost" == "N/A" ]]; then
        echo "$cost"
        return
    fi
    
    # 确保是数字
    if [[ ! "$cost" =~ ^[0-9]+$ ]]; then
        echo "$cost"
        return
    fi
    
    # 格式化规则：
    # < 1000: 显示原数字
    # 1000-9999: 显示x.xk
    # 10000-999999: 显示xxk  
    # >= 1000000: 显示x.xm或xxm
    
    if [[ $cost -lt 1000 ]]; then
        echo "$cost"
    elif [[ $cost -lt 10000 ]]; then
        # 1000-9999: x.xk
        local k_value=$(echo "scale=1; $cost / 1000" | bc)
        echo "${k_value}k"
    elif [[ $cost -lt 1000000 ]]; then
        # 10000-999999: xxk
        local k_value=$(echo "scale=0; $cost / 1000" | bc)
        echo "${k_value}k"
    else
        # >= 1000000: x.xm或xxm
        if [[ $cost -lt 10000000 ]]; then
            # 1m-9.9m: x.xm
            local m_value=$(echo "scale=1; $cost / 1000000" | bc)
            echo "${m_value}m"
        else
            # >= 10m: xxm
            local m_value=$(echo "scale=0; $cost / 1000000" | bc)
            echo "${m_value}m"
        fi
    fi
}

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

# 保存原始数值用于百分比计算
daily_cost_raw="$daily_cost"
monthly_cost_raw="$monthly_cost"

# 计算百分比差异
percentage_diff=""
if [[ "$daily_cost_raw" != "N/A" && "$monthly_cost_raw" != "N/A" ]]; then
    # 获取当前日期
    current_day=$(date +%d)
    current_month=$(date +%Y-%m)
    
    # 计算平均值基准
    average_cost=""
    if [[ $current_day -eq 1 ]]; then
        # 月初第一天，使用上个月的日均值
        last_month_data=$(ccusage monthly -j 2>/dev/null | jq -r '.monthly[-2] // empty' 2>/dev/null)
        if [[ -n "$last_month_data" && "$last_month_data" != "null" ]]; then
            last_month_cost=$(echo "$last_month_data" | jq -r '.totalCost // empty')
            last_month_str=$(echo "$last_month_data" | jq -r '.month // empty')
            if [[ -n "$last_month_cost" && "$last_month_cost" != "null" && -n "$last_month_str" ]]; then
                # 计算上个月的天数
                year_month=$(echo "$last_month_str" | cut -d'-' -f1,2)
                year=$(echo "$year_month" | cut -d'-' -f1)
                month=$(echo "$year_month" | cut -d'-' -f2)
                # 使用cal命令获取该月天数，去掉前导零
                days_in_month=$(cal $((10#$month)) $year | awk 'NF {DAYS = $NF} END {print DAYS}')
                average_cost=$(echo "scale=2; $last_month_cost / $days_in_month" | bc 2>/dev/null)
            fi
        fi
    else
        # 其他日期，使用本月过去日均值
        past_total=$(echo "scale=2; $monthly_cost_raw - $daily_cost_raw" | bc 2>/dev/null)
        past_days=$((current_day - 1))
        if [[ $past_days -gt 0 ]] && [[ -n "$past_total" ]]; then
            average_cost=$(echo "scale=2; $past_total / $past_days" | bc 2>/dev/null)
        fi
    fi
    
    # 计算百分比差异
    if [[ -n "$average_cost" ]] && [[ $(echo "$average_cost > 0" | bc 2>/dev/null) -eq 1 ]]; then
        diff=$(echo "scale=2; $daily_cost_raw - $average_cost" | bc 2>/dev/null)
        percentage=$(printf "%.0f" $(echo "scale=2; ($diff / $average_cost) * 100" | bc 2>/dev/null))
        
        # 只有差异大于1%才显示
        if [[ -n "$percentage" ]] && [[ ${percentage#-} -gt 1 ]]; then
            if [[ $percentage -gt 0 ]]; then
                # 高于平均值，绿色
                percentage_diff=" \033[0;32m+${percentage}%\033[0m"
            else
                # 低于平均值，红色
                percentage_diff=" \033[0;31m${percentage}%\033[0m"
            fi
        fi
    fi
fi

# 格式化显示费用
daily_cost_formatted=$(format_cost "$daily_cost")
monthly_cost_formatted=$(format_cost "$monthly_cost")

# 输出格式：当日费用 / 当月总费用 [+/-X%]
echo -e "${daily_cost_formatted}/${monthly_cost_formatted}${percentage_diff}"