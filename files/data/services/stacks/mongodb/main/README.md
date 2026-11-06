# MongoDB 初始化

## 修復既有資料權限

```bash
sudo chown -R 1000:1000 /data/databases/mongodb/main/data
sudo chmod -R u+rwX /data/databases/mongodb/main/data
```

## 啟動

```bash
docker compose up -d mongodb-main mongodb-main-init
```

啟動時會先設定 data、backups 與 config 目錄權限，再啟動 MongoDB。
`mongodb-main-init` 會在尚未初始化時建立單節點 replica set，並等待 PRIMARY；已有設定則保留。
接著會自動將 FCV 從 8.3 升至 9.0；已是 9.0 則跳過，其他版本僅警告並保持不變，升降級中的狀態仍會報錯停止初始化工作。
只啟動 `mongodb-main` 不會執行初始化工作；整個 Compose 專案一起啟動則會自動包含。

## 建立初始管理員

自行替換用戶名稱跟密碼

```bash
docker exec -it mongodb-main mongosh --eval '
db.getSiblingDB("admin").createUser({
  user: "admin",
  pwd: passwordPrompt(),
  roles: [{ role: "root", db: "admin" }]
})
'
```

## 驗證登入

```bash
docker exec -it mongodb-main mongosh \
  --username admin \
  --password \
  --authenticationDatabase admin
```

## 查看 replica set 狀態

```bash
docker exec -it mongodb-main mongosh \
  --username admin \
  --password \
  --authenticationDatabase admin \
  --eval 'rs.status()'
```

## MongoDB URI

宿主機：

```text
mongodb://admin:<URL_ENCODED_PASSWORD>@127.0.0.1:27017/?authSource=admin&directConnection=true
```

同一個 Compose network 內的容器：

```text
mongodb://admin:<URL_ENCODED_PASSWORD>@mongodb-main:27017/?authSource=admin&replicaSet=rs0
```
