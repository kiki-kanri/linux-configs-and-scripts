# MongoDB 初始化

## 修復既有資料權限

```bash
sudo chown -R 1000:1000 /data/databases/mongodb/main/data
sudo chmod -R u+rwX /data/databases/mongodb/main/data
```

## 啟動

```bash
docker compose up -d mongodb-main
```

## 初始化 replica set

```bash
docker exec -it mongodb-main mongosh --eval 'rs.initiate()'
```

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
