set mongo_disk=d:\data

@echo off
SETLOCAL EnableDelayedExpansion

if not exist "bin\mongod.exe" (
@echo *** MongoDB not found
exit
)

@rem create all db dirs
if exist %mongo_disk%\db\nul goto begin
  set /p cnfr=Create DB folders here %mongo_disk% (y/N)?
  if %cnfr%==y goto mdr
echo %cnfr%
  if NOT %cnfr%==Y exit
:mdr
  for /L %%A IN (0,1,3) DO (
    for /L %%B IN (1,1,3) DO (
      md %mongo_disk%\db\%%A%%B
    ))
  md %mongo_disk%\temp
  md %mongo_disk%\config_a
  md %mongo_disk%\config_b
  md %mongo_disk%\config_c
:begin

cd bin

@echo *** Start server nodes
@echo *** Replica A port 10001
start mongod.exe --shardsvr --replSet A --dbpath %mongo_disk%\db\01 --port 10001 --oplogSize=64 --logpath %mongo_disk%\temp\shard_01.log
start mongod.exe --shardsvr --replSet A --dbpath %mongo_disk%\db\02 --port 10002 --oplogSize=64 --logpath %mongo_disk%\temp\shard_02.log
start mongod.exe --shardsvr --replSet A --dbpath %mongo_disk%\db\03 --port 10003 --oplogSize=64 --logpath %mongo_disk%\temp\shard_03.log
@echo *** Replica B port 10011
start mongod.exe --shardsvr --replSet B --dbpath %mongo_disk%\db\11 --port 10011 --oplogSize=64 --logpath %mongo_disk%\temp\shard_11.log
start mongod.exe --shardsvr --replSet B --dbpath %mongo_disk%\db\12 --port 10012 --oplogSize=64 --logpath %mongo_disk%\temp\shard_12.log
start mongod.exe --shardsvr --replSet B --dbpath %mongo_disk%\db\13 --port 10013 --oplogSize=64 --logpath %mongo_disk%\temp\shard_13.log
@echo *** Replica C port 10021
start mongod.exe --shardsvr --replSet C --dbpath %mongo_disk%\db\21 --port 10021 --oplogSize=64 --logpath %mongo_disk%\temp\shard_21.log
start mongod.exe --shardsvr --replSet C --dbpath %mongo_disk%\db\22 --port 10022 --oplogSize=64 --logpath %mongo_disk%\temp\shard_22.log
start mongod.exe --shardsvr --replSet C --dbpath %mongo_disk%\db\23 --port 10023 --oplogSize=64 --logpath %mongo_disk%\temp\shard_23.log
@echo *** Replica D port 10031
start mongod.exe --shardsvr --replSet D --dbpath %mongo_disk%\db\31 --port 10031 --oplogSize=64 --logpath %mongo_disk%\temp\shard_31.log
start mongod.exe --shardsvr --replSet D --dbpath %mongo_disk%\db\32 --port 10032 --oplogSize=64 --logpath %mongo_disk%\temp\shard_32.log
start mongod.exe --shardsvr --replSet D --dbpath %mongo_disk%\db\33 --port 10033 --oplogSize=64 --logpath %mongo_disk%\temp\shard_33.log
@echo *** wait till all nodes ready
pause

@echo *** Join nodes into replicaset
mongo localhost:10001/admin --eval=printjson(db.runCommand({'replSetInitiate':{'_id':'A','members':[{'_id':0,'host':'localhost:10001'},{'_id':1,'host':'localhost:10002'},{'_id':2,'host':'localhost:10003'}]}}))
mongo localhost:10011/admin --eval=printjson(db.runCommand({'replSetInitiate':{'_id':'B','members':[{'_id':0,'host':'localhost:10011'},{'_id':1,'host':'localhost:10012'},{'_id':2,'host':'localhost:10013'}]}}))
mongo localhost:10021/admin --eval=printjson(db.runCommand({'replSetInitiate':{'_id':'C','members':[{'_id':0,'host':'localhost:10021'},{'_id':1,'host':'localhost:10022'},{'_id':2,'host':'localhost:10023'}]}}))
mongo localhost:10031/admin --eval=printjson(db.runCommand({'replSetInitiate':{'_id':'D','members':[{'_id':0,'host':'localhost:10031'},{'_id':1,'host':'localhost:10032'},{'_id':2,'host':'localhost:10033'}]}}))

@echo *** Start config server
start mongod.exe --configsvr --dbpath %mongo_disk%\config_a --port 20000 --logpath %mongo_disk%\temp\configdb_a.log
start mongod.exe --configsvr --dbpath %mongo_disk%\config_b --port 20001 --logpath %mongo_disk%\temp\configdb_b.log
start mongod.exe --configsvr --dbpath %mongo_disk%\config_c --port 20002 --logpath %mongo_disk%\temp\configdb_c.log
@echo *** wait till all config nodes ready
pause

@echo *** Start head server on 27017
start mongos.exe --configdb localhost:20000,localhost:20001,localhost:20002 --logpath %mongo_disk%\temp\mongos.log
@echo *** wait till head node ready
pause

@echo *** Join replicas into sharded server
mongo localhost:27017/admin --eval=^
printjson(db.runCommand({'addshard':'A/localhost:10001,localhost:10002,localhost:10003'}));^
printjson(db.runCommand({'addshard':'B/localhost:10011,localhost:10012,localhost:10013'}));^
printjson(db.runCommand({'addshard':'C/localhost:10021,localhost:10022,localhost:10023'}));^
printjson(db.runCommand({'addshard':'D/localhost:10031,localhost:10032,localhost:10033'}));
pause

@echo *** Crate collection & index
mongo localhost:27017/mydb --eval=db.mytable.ensureIndex({field_1:1,field_2:-1});printjson(db.mytable.getIndexes())

@echo *** Crate sharded collection as admin
mongo localhost:27017/admin --eval=^
printjson(db.adminCommand({enableSharding:'mydb'}));^
printjson(db.adminCommand({'shardcollection':'mydb.mytable','key':{'field_1':1,'field_2':1}}))

