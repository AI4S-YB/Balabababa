# balabababa - 综合科研数据库检索

> AI助手请先阅读本文档

## 用途

本目录包含多个科研数据库的检索技能(skill)，AI根据用户需求选择对应数据库执行查询。

## 数据库列表

| 数据库 | Skill文件 | 用途 |
|--------|-----------|------|
| 🚀 PlantSRA API | `NCBI/PlantSRA_API.md` | **植物**SRA数据快速检索（API，<0.3s，686万条） |
| NCBI SRA | `NCBI/NCBIdb.md` | 全物种重测序/WGS原始测序数据检索（Entrez） |
| RiceGeneFunction | `RiceGeneFunction/ricegenefunction.md` | 水稻基因功能注释查询 |
| ArabidopsisGeneFunction | `ArabidopsisGeneFunction/arabidopsisgenefunction.md` | 拟南芥基因功能注释查询 |

> ⚠️ PlantSRA API 是植物物种的**优先路径**，NCBI SRA (Entrez) 作为非植物物种和 fallback。两路径输出格式统一。

## 使用方式

```
1. 阅读本文档了解可用数据库
2. 根据用户意图选择对应数据库
3. 加载对应 .md 文件执行查询
4. 重要的是遇到404访问不了还是要继续在本框架内继续尝试，不要轻易跳出框架
```

## AI选择逻辑

| 用户意图 | 选择数据库 | Skill文件 |
|---------|-----------|-----------|
| 想获取**植物**原始测序数据(SRR/reads) | 🚀 PlantSRA API | `NCBI/PlantSRA_API.md` |
| 想获取**非植物**原始测序数据 | NCBI SRA | `NCBI/NCBIdb.md` |
| PlantSRA API 不可达/结果不足 | NCBI SRA (fallback) | `NCBI/NCBIdb.md` |
| 查询水稻基因(Os格式)功能 | RiceGeneFunction | `RiceGeneFunction/ricegenefunction.md` |
| 查询拟南芥基因(AT格式)功能 | ArabidopsisGeneFunction | `ArabidopsisGeneFunction/arabidopsisgenefunction.md` |

### 快速判断

- **植物物种 + SRA/重测序/WGS** → 🚀 PlantSRA API (先 API 健康检查)
- **非植物物种 + SRA** → NCBI SRA (Entrez)
- **API 不可达** → NCBI SRA (fallback)
- **Os01g... ~ Os12g... / LOC_Os...** → RiceGeneFunction  
- **AT1G... ~ AT5G...** → ArabidopsisGeneFunction

## 详细文档

如需更多指导规则，查看 `Databaseinfo.md`
