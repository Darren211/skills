//go:build ignore
// 私钥安全处理示例（合规参考）。复制到项目中时请删除本 build tag。
// 安全审计要求：私钥不通过配置文件路径传入，优先从环境变量或 Secrets Manager 读取，用毕清零。
package templates

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"os"
)

// LoadPrivateKeyPEMFromEnv 从环境变量读取 PEM 私钥，返回原始字节（调用方用毕应调用 ClearBytes）。
// 禁止在 config.toml / application.yml 中配置私钥路径或内容。
func LoadPrivateKeyPEMFromEnv(envKey string) ([]byte, error) {
	raw := os.Getenv(envKey)
	if raw == "" {
		return nil, fmt.Errorf("private key not set (env %s)", envKey)
	}
	block, _ := pem.Decode([]byte(raw))
	if block == nil {
		return nil, fmt.Errorf("invalid PEM block")
	}
	key := make([]byte, len(block.Bytes))
	copy(key, block.Bytes)
	return key, nil
}

// ParseRSAPrivateKey 解析 PKCS#1 或 PKCS#8 私钥；der 用毕应 ClearBytes(der)。
func ParseRSAPrivateKey(der []byte) (*rsa.PrivateKey, error) {
	key, err := x509.ParsePKCS1PrivateKey(der)
	if err == nil {
		return key, nil
	}
	k, err := x509.ParsePKCS8PrivateKey(der)
	if err != nil {
		return nil, err
	}
	pk, ok := k.(*rsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("not RSA private key")
	}
	return pk, nil
}

// ClearBytes 将切片清零，用于敏感字节用毕后减少内存残留。
func ClearBytes(b []byte) {
	for i := range b {
		b[i] = 0
	}
}

// LoadRSAPrivateKeyFromEnv 从环境变量加载 RSA 私钥并解析；rawDer 用毕会清零。
// 使用示例：
//
//	key, rawDer, err := LoadRSAPrivateKeyFromEnv("SIGNING_PRIVATE_KEY")
//	if err != nil { return err }
//	defer ClearBytes(rawDer)
//	// 使用 key 进行签名等操作
func LoadRSAPrivateKeyFromEnv(envKey string) (key *rsa.PrivateKey, rawDer []byte, err error) {
	rawDer, err = LoadPrivateKeyPEMFromEnv(envKey)
	if err != nil {
		return nil, nil, err
	}
	key, err = ParseRSAPrivateKey(rawDer)
	if err != nil {
		ClearBytes(rawDer)
		return nil, nil, err
	}
	return key, rawDer, nil
}
