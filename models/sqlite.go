package models

import (
	"fmt"
	"log"
	"os"
	"sublink/utils"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB
var isInitialized bool

func InitSqlite() {
	// 检查目录是否创建
	_, err := os.Stat("./db")
	if err != nil {
		if os.IsNotExist(err) {
			os.Mkdir("./db", os.ModePerm)
		}
	}
	// 连接数据库
	db, err := gorm.Open(sqlite.Open("./db/sublink.db"), &gorm.Config{})
	if err != nil {
		log.Println("连接数据库失败")
	}
	DB = db
	// 检查是否已经初始化
	if isInitialized {
		log.Println("数据库已经初始化，无需重复初始化")
		return
	}
	err = db.AutoMigrate(&User{}, &Subcription{}, &SubLogs{}, &GroupNode{}, &Node{})
	if err != nil {
		log.Println("数据表迁移失败")
	}
	// 初始化用户数据
	err = db.First(&User{}).Error
	if err == gorm.ErrRecordNotFound {
		// 生成随机密码
		randomPassword := utils.RandPassword(12)
		admin := &User{
			Username: "admin",
			Password: randomPassword,
			Role:     "admin",
			Nickname: "管理员",
		}
		err = admin.Create()
		if err != nil {
			log.Println("初始化添加用户数据失败")
		} else {
			// 成功创建管理员账号后显示密码信息
			fmt.Println("==========================================")
			fmt.Println("✅ SublinkX 初始化完成！")
			fmt.Println("==========================================")
			fmt.Printf("🔐 管理员账号: admin\n")
			fmt.Printf("🔑 随机密码: %s\n", randomPassword)
			fmt.Println("==========================================")
			fmt.Println("⚠️  请妥善保存上述密码信息！")
			fmt.Println("🌐 访问地址: http://localhost:8000")
			fmt.Println("==========================================")
			
			// 将密码信息保存到文件
			passwordInfo := fmt.Sprintf("SublinkX 初始管理员信息\n生成时间: %s\n管理员账号: admin\n随机密码: %s\n\n注意：请妥善保存此信息！\n", 
				utils.GetCurrentTime(), randomPassword)
			err = os.WriteFile("./admin_password.txt", []byte(passwordInfo), 0600)
			if err != nil {
				log.Printf("保存密码信息到文件失败: %v", err)
			} else {
				fmt.Println("💾 密码信息已保存到 admin_password.txt 文件")
			}
		}
	}
	// 设置初始化标志为 true
	isInitialized = true
	log.Println("数据库初始化成功") // 只有在没有任何错误时才会打印这个日志
}
