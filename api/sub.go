// api/subcription.go

package api

import (
	// 导入 json 包，用于解析 config 字符串

	"log"
	"strconv"
	"strings"
	"sublink/models" // 导入 models 包

	"github.com/gin-gonic/gin"
)

func SubTotal(c *gin.Context) {
	var Sub models.Subcription
	subs, err := Sub.List()
	count := len(subs)
	if err != nil {
		c.JSON(500, gin.H{
			"msg": "取得订阅总数失败",
		})
		return
	}
	c.JSON(200, gin.H{
		"code": "00000",
		"data": count,
		"msg":  "取得订阅总数",
	})
}

// 获取订阅列表
func SubGet(c *gin.Context) {
	var Sub models.Subcription
	Subs, err := Sub.List()
	if err != nil {
		c.JSON(500, gin.H{
			"msg": "node list error",
		})
		return
	}
	c.JSON(200, gin.H{
		"code": "00000",
		"data": Subs,
		"msg":  "node get",
	})
}

// 添加订阅
func SubAdd(c *gin.Context) {
	name := c.PostForm("name")
	configs := c.PostForm("config") // 这里的 configString 是前端传来的 JSON 字符串
	nodes := c.PostForm("nodes")

	if name == "" || nodes == "" {
		c.JSON(400, gin.H{
			"msg": "订阅名称或节点不能为空",
		})
		return
	}

	// 1. 根据 nodesString 字符串，构建 models.Node 数组
	var NodesData []models.Node

	for _, nodeName := range strings.Split(nodes, ",") {
		if strings.TrimSpace(nodeName) == "" {
			continue
		}
		FirstNode := models.Node{
			Name: nodeName,
		}

		// 查出node的数据
		result := models.DB.Model(models.Node{}).Where("name = ?", FirstNode.Name).First(&FirstNode)
		if result.Error != nil {
			log.Println(result.Error)
			c.JSON(400, gin.H{
				"msg": result.Error,
			})
			return
		}
		// 插入nodes
		NodesData = append(NodesData, FirstNode)
	}
	sub := models.Subcription{
		Name:      name,
		Config:    configs,   // 这里直接赋值字符串
		NodeOrder: nodes,     // 这里直接赋值字符串
		Nodes:     NodesData, // 这里直接赋值 nodes 数组

	}
	err := sub.Add()
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "添加订阅失败: " + err.Error(),
		})
		return
	}

	c.JSON(200, gin.H{
		"code": "00000",
		"msg":  "添加订阅成功",
	})
}

// 更新订阅
func SubUpdate(c *gin.Context) {
	NewName := c.PostForm("name")
	OldName := c.PostForm("oldname")
	configs := c.PostForm("config") // 这里的 configString 是前端传来的 JSON 字符串
	nodes := c.PostForm("nodes")

	if NewName == "" || nodes == "" {
		c.JSON(400, gin.H{
			"msg": "订阅名称或节点不能为空",
		})
		return
	}

	// 1. 根据 nodesString 字符串，构建 models.Node 数组
	var NodesData []models.Node

	for _, nodeName := range strings.Split(nodes, ",") {
		if strings.TrimSpace(nodeName) == "" {
			continue
		}
		FirstNode := models.Node{
			Name: nodeName,
		}

		// 查出node的数据
		result := models.DB.Model(models.Node{}).Where("name = ?", FirstNode.Name).First(&FirstNode)
		if result.Error != nil {
			log.Println(result.Error)
			c.JSON(400, gin.H{
				"msg": result.Error,
			})
			return
		}
		// 插入nodes
		NodesData = append(NodesData, FirstNode)
	}
	OldSub := models.Subcription{
		Name: OldName,
	}
	NewSub := models.Subcription{
		Name:      NewName,
		Config:    configs,   // 这里直接赋值字符串
		NodeOrder: nodes,     // 这里直接赋值字符串
		Nodes:     NodesData, // 这里直接赋值 nodes 数组

	}

	err := OldSub.Update(&NewSub)
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "更新订阅失败: " + err.Error(),
		})
		return
	}

	c.JSON(200, gin.H{
		"code": "00000",
		"msg":  "更新订阅成功",
	})
}

// 删除订阅 (无需修改)
func SubDel(c *gin.Context) {
	var sub models.Subcription
	id := c.Query("id")
	if id == "" {
		c.JSON(400, gin.H{
			"msg": "id 不能为空",
		})
		return
	}
	x, err := strconv.Atoi(id) // 增加错误检查
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "无效的 ID: " + err.Error(),
		})
		return
	}
	sub.ID = x
	err = sub.Find()
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "查找订阅失败: " + err.Error(),
		})
		return
	}
	err = sub.Del()
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "删除订阅失败: " + err.Error(),
		})
		return
	}
	c.JSON(200, gin.H{
		"code": "00000",
		"msg":  "删除订阅成功",
	})
}

// 创建代理链
func CreateRelayChain(c *gin.Context) {
	frontNode := c.PostForm("front_node")    // 前置节点
	backendNode := c.PostForm("backend_node") // 落地节点
	chainName := c.PostForm("chain_name")     // 代理链名称

	if frontNode == "" || backendNode == "" || chainName == "" {
		c.JSON(400, gin.H{
			"msg": "前置节点、落地节点和代理链名称不能为空",
		})
		return
	}

	// 检查前置节点是否存在
	var frontNodeData models.Node
	err := models.DB.Where("name = ?", frontNode).First(&frontNodeData).Error
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "前置节点不存在: " + frontNode,
		})
		return
	}

	// 检查落地节点是否存在
	var backendNodeData models.Node
	err = models.DB.Where("name = ?", backendNode).First(&backendNodeData).Error
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "落地节点不存在: " + backendNode,
		})
		return
	}

	// 创建代理链节点
	relayNode := models.Node{
		Name: chainName,
		Link: generateRelayLink(frontNode, backendNode),
	}

	// 保存到数据库
	err = models.DB.Create(&relayNode).Error
	if err != nil {
		c.JSON(400, gin.H{
			"msg": "创建代理链失败: " + err.Error(),
		})
		return
	}

	// 代理链节点创建完成，作为普通节点存储即可

	c.JSON(200, gin.H{
		"code": "00000",
		"msg":  "代理链创建成功",
		"data": gin.H{
			"chain_name":   chainName,
			"front_node":   frontNode,
			"backend_node": backendNode,
		},
	})
}

// 生成Relay代理链的配置字符串
func generateRelayLink(frontNode, backendNode string) string {
	// 这里生成一个特殊的标识符，表示这是一个relay代理链
	// 格式: relay://front_node|backend_node
	return "relay://" + frontNode + "|" + backendNode
}