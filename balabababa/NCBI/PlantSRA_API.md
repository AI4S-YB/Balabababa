# Plant SRA API v2.0 — 植物 SRA 数据快速检索

## 描述

通过阿里云部署的植物 SRA 元数据 API（686 万+ 记录，FTS5 全文索引，v2.0 **返回完整技术元数据**），在 **<0.3 秒内**完成从检索到下载就绪的全部流程。**已完全替代 Entrez 路径**（`NCBIdb.md` 保留仅用于非植物物种）。

**⚠️ 重要**：本 Skill 仅覆盖**植物界**（Plantae）物种。非植物物种请使用 `NCBIdb.md`。

## 触发条件

当用户请求检索**植物物种**的 SRA / 重测序 / WGS / RNA-Seq 数据时激活。

**示例请求**:
- "检索 O.meyeriana 的 WGS 数据"
- "找苹果果实色泽相关的转录组数据"
- "搜索拟南芥的重测序数据"
- "下载玉米的 PE150 WGS 数据"

---

## 前置检查

### 1. API 健康检查

```bash
curl -s http://47.95.117.10:8080/health
```

预期：`{"status":"ok"}`

### 2. API 不可达 → fallback `NCBIdb.md`

---

## 执行流程（2 Phase，零 Entrez 依赖）

```
Phase 0: LLM 多关键词展开
  → 3-5 个搜索变体

Phase 1: 项目概览 (dedup=true)
  → API 返回策略/平台/布局统计摘要 → AI 不需要再猜！

Phase 2: 精确获取 Accession (dedup=false + 过滤)
  → API 直接返回全部 12 个字段（含 Platform, Spots, Bases, Layout）
  → 无需 Entrez 补全！
```

---

### Phase 0: LLM 驱动多关键词展开

**⚠️ 不要只用用户原始输入**，AI 应生成 3-5 个搜索变体：

| 用户输入 | 展开的关键词变体 |
|----------|----------------|
| O.meyeriana | `Oryza meyeriana`, `Oryza granulata`, `O. meyeriana` |
| 水稻 | `Oryza sativa`, `rice`, `Oryza sativa Japonica Indica` |
| 苹果果实色泽 | `Malus domestica`, `apple fruit anthocyanin`, `Malus transcriptome` |
| 玉米 | `Zea mays`, `maize`, `corn Zea` |

每条变体之后加上 `WGS`（如果用户要的是 WGS 而非 RNA-Seq），如：`Oryza meyeriana WGS`

搜索示例：
```bash
curl -s "http://47.95.117.10:8080/search?q=Oryza%20meyeriana%20WGS&dedup=true&limit=50"
curl -s "http://47.95.117.10:8080/search?q=Oryza%20granulata%20genome&dedup=true&limit=50"
```

---

### Phase 1: 项目概览 (dedup=true, API v2.0)

**一步拿到分类依据 + 统计摘要，AI 不再靠标题猜。**

```bash
curl -s "http://47.95.117.10:8080/search?q={关键词}&dedup=true&limit=50"
```

**API v2.0 返回格式 (含策略/平台/布局摘要)**:
```json
{
  "bioproject": "PRJDB4627",
  "organism_name": "Oryza meyeriana",
  "project_title": "Genome sequencing of wild rice Oryza meyeriana accessions",
  "run_count": 8,
  "strategies": "WGS",
  "platforms": "ILLUMINA,PACBIO_SMRT",
  "instrument_models": "Illumina HiSeq 2000,PacBio Sequel II",
  "layouts": "PAIRED,SINGLE",
  "total_bases_sum": 120000000000,
  "sample_accession": "DRR056670"
}
```

**AI 自动分类（现在有 library_strategy 硬数据！）**：
- `strategies` 包含 **WGS** → 🧬 WGS
- `strategies` 包含 **RNA-Seq** → 📝 RNA-Seq/Transcriptome
- 其他 → 🔬 Other

> **之前**: 靠 project_title 文本猜（"genome" → WGS? "transcriptome" → RNA? 不靠谱）
> **现在**: `strategies: "WGS"` 直接判定，100% 准确

**优先展示 WGS 项目**，RNA-Seq 排行其后。

---

### Phase 2: 精确获取 Accession + 全部技术元数据 (dedup=false + 过滤)

**一步拿到输出表需要的全部字段，无需再调 Entrez。**

```bash
# 获取 WGS + Illumina PE 数据（例子）
curl -s "http://47.95.117.10:8080/search?q={关键词}&dedup=false&limit=200&strategy=WGS&platform=ILLUMINA&layout=PAIRED"
```

**过滤参数**（可选，留给 AI 按需要选择）：
| 参数 | 用途 | 常用值 |
|------|------|--------|
| `strategy` | 过滤测序策略 | WGS, RNA-Seq（省略 = 全返回） |
| `platform` | 过滤测序平台 | ILLUMINA, PACBIO_SMRT, OXFORD_NANOPORE |
| `layout` | 过滤文库布局 | PAIRED, SINGLE |

**API v2.0 返回（全部 12 个字段，输出表一个 API 拉满）**:
```json
{
  "accession": "DRR056670",
  "organism_name": "Oryza meyeriana",
  "taxon_id": 40149,
  "bioproject": "PRJDB4627",
  "project_title": "Genome sequencing of wild rice Oryza meyeriana accessions",
  "library_strategy": "WGS",
  "library_source": "GENOMIC",
  "library_layout": "PAIRED",
  "platform": "ILLUMINA",
  "instrument_model": "Illumina HiSeq 2000",
  "total_spots": 14000000,
  "total_bases": 4200000000
}
```

**关键流程**：
1. 对每个关键词变体调用 `dedup=false` + 合适的过滤参数
2. 按 `accession` 去重合并
3. 按 `bioproject` + `library_strategy` 分组整理
4. **直接输出 Markdown 表格** — 所有字段已齐！

---

## 输出格式（直接可用，无补全区段）

### 文件命名

```
{物种名}_{数据类型}_SRR_list_{日期}.md
```

### 输出模板

```markdown
# 🌿 植物 SRA 检索结果

## 检索信息

| 项目 | 内容 |
|------|------|
| **用户输入** | {用户原始需求} |
| **关键词变体** | {LLM 展开关键词} |
| **数据来源** | Plant SRA API v2.0 (47.95.117.10:8080) |
| **检索时间** | {YYYY-MM-DD} |

## 📊 BioProject 总览 (Phase 1)

| 类型 | BioProject | 物种 | Runs | 策略 | 平台 | 数据总量 |
|------|-----------|------|------|------|------|----------|
| 🧬 WGS | PRJDB4627 | Oryza meyeriana | 8 | WGS | ILLUMINA,PACBIO_SMRT | 120G |
| 📝 RNA | PRJNA720061 | Malus domestica | 12 | RNA-Seq | ILLUMINA | 48G |

> 🧬 WGS/Genome  📝 RNA-Seq/Transcriptome  🔬 Other
> 分类来源: API 返回的 `strategies` 字段（非 AI 猜测）

## 📋 完整 Accession 列表 (Phase 2)

### PRJDB4627 - Genome sequencing of wild rice Oryza meyeriana accessions

| Accession | 平台 | 数据量 (Spots/Bases) | 布局 | 策略 |
|-----------|------|---------------------|------|------|
| DRR056670 | Illumina HiSeq 2000 | 14.0M / 4.2G | PE | WGS |
| DRR056671 | PacBio Sequel II | 5.2M / 52G | SE | WGS |

*注: 以上所有字段均来自 API 直接返回，无需 NCBI Entrez 补全*

## 📥 数据下载

```bash
# 批量下载
prefetch --option-file SRA_Accession_List.txt
```

## 🔗 来源

- API: http://47.95.117.10:8080/search
- NCBI SRA: https://www.ncbi.nlm.nih.gov/sra/{ACCESSION}
```

---

## 错误处理与 Fallback

| 情况 | 处理方式 |
|------|----------|
| API 不可达 | → Fallback 到 `NCBIdb.md` (Entrez) |
| API 返回空结果 | → 尝试其他关键词变体；仍为空则 Fallback |
| API 结果过少 (<3) | → 同时查 API + Entrez，合并 |
| 非植物物种 | → 直接走 `NCBIdb.md` |
| 用户需要超精确筛选 (如 spots ≥ 1M) | → API 返回 total_spots 字段，**在客户端过滤即可**（无需再调 Entrez） |

## Fallback 决策树

```
API Health
  ├── 不可达 → NCBIdb.md
  └── 可达
        ├── count=0 全变体 → NCBIdb.md
        └── 有结果 → API 路径（2 Phase 即完成）
```

---

## 执行流程检查表

```
□ 1. API 健康检查
□ 2. LLM 展开 3-5 个搜索变体
□ 3. Phase 1: dedup=true → 获取 BioProject 总览 + strategies/platforms 摘要
□ 4. AI 根据 strategies 字段精准分类 WGS/RNA-Seq
□ 5. 向用户展示 BioProject 总览
□ 6. Phase 2: dedup=false + 适当过滤 → 直接拿到全部 12 字段
□ 7. 合并去重，按 BioProject 分组
□ 8. 写入 Markdown 文件（全部字段来自 API，无需 Entrez 补全）
```

---

## 与 NCBIdb.md 的关系

```
用户 SRA 查询
  ├── 植物物种 → PlantSRA_API.md 🚀 (本文件, 2 Phase)
  │     └── API 不可达 → NCBIdb.md (fallback only)
  └── 非植物物种 → NCBIdb.md
```

## 常见问题

| 问题 | 解决方案 |
|------|----------|
| WGS vs RNA-Seq 怎么区分？ | API 返回 `library_strategy` 字段，100% 准确 |
| API 数据与 NCBI 网页不一致？ | API 基于预处理快照；如需实时数据可 fallback Entrez |
| 过滤不生效？ | strategy/platform/layout 是精确匹配，检查值大小写（全大写） |
| 想要所有物种而非仅限植物？ | 走 `NCBIdb.md` (Entrez) |
