package utils

import (
	"math/rand"
	"time"
)

// RandString 生成随机字符串
func RandString(number int) string {
	str := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
	// 用 []byte 直接构造字符串
	n := rand.Intn(number) + 1 // 防止生成空字符串，范围是1到31
	randomString := make([]byte, n)
	for i := 0; i < n; i++ {
		randomIndex := rand.Intn(len(str))
		randomString[i] = str[randomIndex]
	}
	Secret := string(randomString)
	return Secret
}

// RandPassword 生成固定长度的随机密码（用于初始管理员密码）
func RandPassword(length int) string {
	// 设置随机种子
	rand.Seed(time.Now().UnixNano())
	
	// 密码字符集：包含大小写字母、数字和部分特殊字符，避免容易混淆的字符
	str := "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*"
	
	randomString := make([]byte, length)
	for i := 0; i < length; i++ {
		randomIndex := rand.Intn(len(str))
		randomString[i] = str[randomIndex]
	}
	return string(randomString)
}

// GetCurrentTime 获取当前时间的格式化字符串
func GetCurrentTime() string {
	return time.Now().Format("2006-01-02 15:04:05")
}
