# NCBI SRA 数据检索技能

## 描述
自动化的 NCBI Sequence Read Archive (SRA) 数据检索智能体。根据用户提供的物种关键词，检索全基因组重测序(WGS)数据，返回符合条件的 SRR accession 列表及网页证据。

## 触发条件
当用户请求检索特定物种的 SRA 重测序数据时激活。

**示例请求**:
- "检索 O.meyeriana 的 SRA 数据"
- "搜索人类 WGS 数据"
- "找水稻的 resequencing 数据"

## 前置检查

### 1. 检查 agent-browser 是否可用

**首次使用必须执行此检查**:

```bash
agent-browser --help
```

### 2. 如未安装，执行安装:

```bash
npm install -g agent-browser
```

### 3. 确认安装成功后再继续

---

## 执行流程

### 步骤 1: 启动浏览器
```
agent-browser --headed
```

### 步骤 2: 访问 NCBI SRA 并执行初步检索
```
导航至: https://www.ncbi.nlm.nih.gov/sra/
```
按优先级尝试检索式：

| 优先级 | 检索式 | 适用情况 |
|--------|--------|----------|
| 1 | `{物种名}[Organism]` | NCBI 分类学语法（首选） |
| 2 | `{物种名} WGS` | 直接限定 WGS |
| 3 | `{物种名} resequencing` | 限定重测序 |
| 4 | `{物种名} genome sequencing` | 基因组测序 |

**示例**:
- 用户输入 "O.meyeriana" → 检索式: `Oryza meyeriana[Organism]`
- 用户输入 "human" → 检索式: `Homo sapiens[Organism]`

#### ⚠️ 关键技巧：直接导航到带参数的URL
**不要**尝试在浏览器中模拟输入搜索框，**直接使用URL导航**更可靠：

```bash
# 正确方式：直接导航到带参数的URL
agent-browser open "https://www.ncbi.nlm.nih.gov/sra/?term=Oryza+meridionalis%5BOrganism%5D+AND+WGS"

# 错误方式：尝试模拟输入搜索框（容易失败）
agent-browser type searchbox "xxx"  # ❌ 不推荐
```

**URL编码对照表**：
| 字符 | 编码 |
|------|------|
| `[` | %5B |
| `]` | %5D |
| ` ` (空格) | + 或 %20 |

**常用检索URL模板**：
```
# 基础搜索
https://www.ncbi.nlm.nih.gov/sra/?term={物种名}%5BOrganism%5D

# WGS限定搜索
https://www.ncbi.nlm.nih.gov/sra/?term={物种名}%5BOrganism%5D+AND+WGS

# 多条件组合
https://www.ncbi.nlm.nih.gov/sra/?term={物种名}%5BOrganism%5D+AND+WGS+AND+Illumina
```

### 步骤 3: 应用筛选器
在 SRA 结果页应用以下筛选：

| 筛选字段 | 目标值 | 说明 |
|----------|--------|------|
| Strategy | WGS | 全基因组测序 |
| Source | GENOMIC | 基因组来源 |
| Selection | RANDOM / size fractionation | 随机选择 |
| Platform | Illumina / PacBio / NovaSeq | 测序平台 |
| Layout | PAIRED (优先) | 双端测序优先 |

**排除项**:
- ❌ RNA-Seq
- ❌ Amplicon
- ❌ ChIP-Seq
- ❌ Hi-C
- ❌ Metagenome
- ❌ Transcriptome

### 步骤 4: 提取 SRR 详情
对每个候选 SRR，获取详细信息：

```
必须提取字段:
├── SRR/DRR accession (Run编号) ← 必须
├── Platform (测序平台) ← 必须
├── Spots / Bases (数据量) ← 必须
├── Bioproject ← 必须
├── SRX accession (Experiment编号)
├── Title (实验描述)
├── Layout (PE/SE)
├── Study (SRP)
└── Published date (发布日期)
```

### 步骤 5: 判断"合适大小"

| 指标 | 合格标准 |
|------|----------|
| Spots | ≥ 1,000,000 (1M) |
| Bases | ≥ 5,000,000,000 (5G) |
| Size | ≥ 500MB |
| Status | Released (已发布) |

### 步骤 6: 使用 Entrez API 获取完整 SRR 列表
**⚠️ 必须使用 API 获取所有数据**，浏览器结果可能不完整

#### ⚠️ 关键：URL编码是必须步骤
**curl命令中的方括号必须URL编码**，否则会报 `bad range in URL` 错误：

```bash
# ❌ 错误写法（方括号未编码）
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=Oryza+meridionalis[Organism]+AND+WGS&retmax=100"

# ✅ 正确写法（方括号URL编码）
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=Oryza%20meridionalis%5BOrganism%5D%20AND%20WGS&retmax=100&retmode=json"
```

**URL编码工具函数**：
| 原字符 | URL编码 |
|--------|---------|
| `[` | %5B |
| `]` | %5D |
| `:` | %3A |
| ` ` | %20 或 + |

#### 6.1 获取所有 SRX ID
```
https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term={物种名}[Organism]+AND+WGS&retmax=1000&retmode=json
```

**输出字段说明**：
- `count` → 总结果数
- `idlist` → SRX/ERX/DRX ID 列表（用于后续批量查询）

#### 6.2 批量获取详细信息（分批策略）
**⚠️ 必须分批获取**：esummary单次请求ID数量建议不超过20个，避免超时

```bash
# 分批获取示例（每批20个ID）
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=sra&id=ID1,ID2,...,ID20&retmode=json" -o batch1.json

curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=sra&id=ID21,ID22,...,ID40&retmode=json" -o batch2.json
```

**分批规则**：
- 每批 ID 数量：建议 15-20 个
- 每批间隔：至少 0.5 秒（尊重API限速）
- 超时处理：如遇超时，保存已获取数据后重试剩余部分

#### 6.3 提取关键字段
从 API 返回结果（expxml字段）中提取以下字段：
- `Run acc` → SRR/DRR/ERR accession（从 `<Run acc="SRRxxx">` 提取）
- `instrument_model` → 测序平台（从 `<Platform>` 提取）
- `total_spots` → 原始 Reads 数量（从 `<Statistics>` 提取）
- `total_bases` → 碱基总数（从 `<Statistics>` 提取）
- `Bioproject` → 项目编号（从 `<Bioproject>` 提取）
- `LIBRARY_LAYOUT` → PE/SE（从 `<LIBRARY_LAYOUT><PAIRED/>` 或 `<SINGLE/>` 提取）

**提取示例（PowerShell）**：
```powershell
# 从JSON中提取所有SRR号
$json = Get-Content 'esummary_result.json' -Raw
$srrs = [regex]::Matches($json, 'Run acc="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$srrs
```

---

## 输出格式

### ⚠️ 关键要求

1. **必须输出所有 SRR 号**: 禁止遗漏，必须使用 Entrez API 获取完整列表
2. **必须包含关键信息**: SRR、平台、数据量、Bioproject
3. **⚠️ 必须写入文件**: 所有结果必须保存到本地文件

### 结构化结果表

#### 摘要部分
```markdown
## 检索结果摘要

**物种关键词**: {用户输入}
**最终检索式**: {实际使用的检索式}
**筛选条件**: {应用的筛选器}
**检索时间**: {日期}
**结果数量**: X 条 SRR
```

#### 完整 SRR 列表 (必须包含所有数据)

**方式一: 紧凑列表 (适用于大量数据)**
```markdown
### 完整 SRR/DRR 列表 (共 N 条)

| 序号 | SRR/DRR | 平台 | 数据量 | Bioproject |
|-----|---------|------|--------|------------|
| 1 | SRRxxxxx | Illumina HiSeq 2000 | 13.9M / 4.2G | PRJNAxxxxx |
| 2 | SRRxxxxx | NovaSeq 6000 | 137M / 41.1G | PRJDBxxxxx |
| ... | ... | ... | ... | ... |
```

**方式二: 按项目分组 (适用于需要清晰展示来源)**
```markdown
### 按 Bioproject 分组

**PRJNAxxxxx - 项目名称**
| SRR/DRR | 平台 | 数据量(Spots/Bases) |
|---------|------|---------------------|
| SRRxxxxx | Illumina HiSeq 2000 | 13.9M / 4.2G |
| SRRxxxxx | NovaSeq 6000 | 137M / 41.1G |

**PRJDBxxxxx - 另一个项目**
| SRR/DRR | 平台 | 数据量(Spots/Bases) |
|---------|------|---------------------|
| SRRxxxxx | PacBio Sequel II | 5.2M / 52G |
```

### 输出文件要求

**⚠️ 必须将结果写入文件**，文件命名规范：
```
{物种名}_WGS_SRR_list_{日期}.md
```

**示例**:
```
Oryza_longistaminata_WGS_SRR_list_20260328.md
```

**文件必须包含**:
1. 检索摘要（物种、检索式、数量）
2. 完整 SRR 列表（包含平台、数据量、Bioproject）
3. 数据下载链接

### 网页证据模板

每个 SRR 必须包含：
1. **来源 URL**: `https://www.ncbi.nlm.nih.gov/sra/SRRxxxxx`
2. **页面关键信息**: Strategy, Source, Layout
3. **数据量证据**: spots/bases/size 数值

---

## 备选方案

| 情况 | 处理方式 |
|------|----------|
| 检索式无结果 | 自动尝试下一个检索式 |
| WGS 数据过少 | 放宽至包含 WGS 的 mixed strategy |
| 遇到登录弹窗 | 关闭/忽略，继续公开访问 |
| 页面加载超时 | 等待 5 秒后重试，最多 3 次 |
| API返回空ID列表 | 检查物种名拼写，尝试通用名/学名转换 |
| esummary超时 | 分成更小的批次（10-15个ID/批）重试 |
| curl报"bad range"错误 | 检查URL中的特殊字符是否已编码（特别是[]） |
| 浏览器搜索框定位失败 | 直接使用URL参数导航，不要模拟输入 |
| 数据量过大无法一次性获取 | 使用retstart分页获取全部数据 |

---

## 验证模型检查清单

在输出最终结果前，执行以下验证：

### 必检项（全部通过才能输出）

- [ ] **⚠️ API返回数量与网页一致**: `esearch`返回的`count`等于实际获取的SRR数量
- [ ] **⚠️ 已写入文件**: 结果已保存到本地 `.md` 文件
- [ ] **⚠️ URL编码检查**: curl命令中的特殊字符（特别是`[]`）已正确编码为`%5B%5D`

### 数据验证项

- [ ] 每个 SRR 确认来自目标物种（通过`ScientificName`字段验证）
- [ ] 每个 SRR 确认为 WGS/resequencing（通过`LIBRARY_STRATEGY`字段验证，应为`WGS`）
- [ ] 数据量符合"合适"标准（≥ 1M spots 或 ≥ 5G bases）
- [ ] 不满足条件的 SRR 已被排除（如RNA-Seq、Amplicon等）

### 完整性验证

- [ ] SRR 总数正确: `esearch count` = 输出的SRR数量
- [ ] 每个 SRR 都有对应的 Bioproject 编号
- [ ] 每个 SRR 都有对应的 SRX/ERX/DRX 实验编号

### 输出格式验证

- [ ] 文件包含：SRR/DRR/ERR 号
- [ ] 文件包含：测序平台（Platform）
- [ ] 文件包含：数据量（Spots/Bases）
- [ ] 文件包含：Bioproject 编号
- [ ] 文件包含：下载链接（NCBI SRA URL）
- [ ] 文件命名符合规范：`{物种名}_WGS_SRR_list_{日期}.md`

---

## 注意事项

1. **⚠️ 必须写入文件**: 检索结果必须保存到本地 .md 文件，不得仅输出到屏幕
2. **⚠️ 完整性**: 必须使用 Entrez API 获取所有数据，不得遗漏任何 SRR
3. **⚠️ URL编码**: curl命令中必须对特殊字符（`[]`等）进行URL编码，否则会报"bad range"错误
4. **⚠️ 分批获取**: esummary单次请求不要超过20个ID，避免超时
5. **浏览器先行**: 先用浏览器确认检索式和筛选条件，再用 API 获取完整列表
6. **直接导航**: 使用带参数的URL直接导航，不要尝试模拟输入搜索框
7. **通用性**: 本技能适用于任何物种，只需替换用户提供的关键词
8. **灵活性**: 检索式需根据物种名称特点适当调整（如学名/俗名）
9. **可追溯**: 所有 SRR 必须附带来源 URL 作为证据
10. **优先级**: 优先选择 Illumina PE 数据，其次 PacBio HiFi / Nanopore
11. **记录**: 记录所有尝试的检索式及结果数量
12. **尊重限速**: API请求间隔至少0.5秒，避免被封禁

---

## 快速参考

### 常用检索式模板
```
{物种名}[Organism]
{物种名}[Organism] AND WGS
{物种名}[Organism] AND resequencing
{物种名}[Organism] AND "genome sequencing"
```

### ⚠️ 关键：URL编码速查表

| 原字符 | URL编码 | 常见错误 |
|--------|---------|---------|
| `[` | %5B | ❌ 不编码会报bad range |
| `]` | %5D | ❌ 不编码会报bad range |
| `:` | %3A | ❌ 在路径中需编码 |
| ` ` (空格) | %20 或 + | 推荐用+ |
| `=` | %3D | API参数中常见 |

### Entrez API 使用示例

**搜索所有 WGS 数据（⚠️ 必须URL编码）**:
```bash
# ✅ 正确：方括号已编码
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=Oryza%20meridionalis%5BOrganism%5D%20AND%20WGS&retmax=100&retmode=json"

# ❌ 错误：方括号未编码（会报错）
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=Oryza meridionalis[Organism] AND WGS&retmax=100"
```

**获取详细信息（⚠️ 分批获取，每批不超过20个）**:
```bash
# 第一批：前20个ID
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=sra&id=40389184,37342360,21582005,21582004,15947556,15947555,15947554,15947553,15947552,15947551,15947550,15947549,15947548,15947547,15947546,15947545,15947543,15947542,15947541,15947540&retmode=json" -o batch1.json

# 等待0.5秒
sleep 0.5

# 第二批：接下来的20个ID
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=sra&id=15947539,15947536,15947535,15947534,12734905,11959108,11959107,4504418,4504417,4504416,4504415,4504414,4504413,4504412,4504411,4504410,4504409,4504408,4504407,4504406&retmode=json" -o batch2.json
```

**提取 SRR 号（PowerShell）**:
```powershell
# 从esummary结果中提取所有Run accession
$json = Get-Content 'esummary_result.json' -Raw
$srrs = [regex]::Matches($json, 'Run acc="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$srrs | ForEach-Object { Write-Host $_ }
```

**提取关键字段示例**:
```powershell
# 提取平台
[regex]::Match($json, 'instrument_model="([^"]+)"').Groups[1].Value

# 提取数据量
[regex]::Match($json, 'total_spots="([^"]+)"').Groups[1].Value
[regex]::Match($json, 'total_bases="([^"]+)"').Groups[1].Value

# 提取Bioproject
[regex]::Match($json, '<Bioproject>([^<]+)</Bioproject>').Groups[1].Value
```

### NCBI SRA 字段参考
- **Strategy**: WGS, WXS, RNA-Seq, Chip-Seq, AMPLICON...
- **Source**: GENOMIC, TRANSCRIPTOMIC, METAGENOMIC...
- **Selection**: RANDOM, PCR, size fractionation...
- **Layout**: PAIRED, SINGLE

### 常用物种别名参考
```
O.meyeriana → Oryza meyeriana
human → Homo sapiens
mouse → Mus musculus
rice → Oryza sativa
arabidopsis → Arabidopsis thaliana
```

---

## 常见错误与解决方案

### 1. curl: (3) bad range in URL position XX

**原因**: URL中的方括号`[]`未进行URL编码

**解决**:
```bash
# 将 [ 替换为 %5B
# 将 ] 替换为 %5D
# 例如：
# Oryza meridionalis[Organism] → Oryza%20meridionalis%5BOrganism%5D
```

### 2. esummary 请求超时

**原因**: 一次请求的ID数量过多

**解决**: 
- 每批减少到15-20个ID
- 增加请求间隔（至少0.5秒）
- 分多次获取

### 3. 浏览器搜索框定位失败

**原因**: 页面动态加载，元素选择器不稳定

**解决**: 
- 直接使用URL带参数访问
- 不尝试模拟输入/点击搜索框
- 使用 `agent-browser open "https://www.ncbi.nlm.nih.gov/sra/?term=xxx"`

### 4. API返回空结果

**原因**: 
- 物种名拼写错误
- 该物种暂无WGS数据
- 使用了错误的检索字段

**解决**:
- 验证物种拉丁名是否正确
- 尝试不使用WGS限定搜索
- 查看BioProject/Assembly确认该物种有数据

### 5. 数据量与预期不符

**原因**: 
- 浏览器显示结果有缓存延迟
- 使用了旧版API
- 部分数据需要申请访问

**解决**:
- 始终以esearch返回的count为准
- 检查数据是否为controlled access
- 刷新页面后重新获取

---

## 执行流程检查表（建议按顺序执行）

```
□ 1. 检查 agent-browser 可用性
□ 2. 使用浏览器确认检索式和结果数量
□ 3. 记录浏览器中的筛选条件
□ 4. 使用 esearch 获取完整ID列表
□ 5. 验证 ID 数量与浏览器一致
□ 6. 分批获取 esummary 详情（每批≤20个）
□ 7. 提取所有关键字段（SRR, Platform, Spots, Bases, Bioproject）
□ 8. 过滤不符合条件的数据（RNA-Seq等）
□ 9. 按Bioproject分组整理结果
□ 10. 写入Markdown文件
□ 11. 关闭浏览器
□ 12. 执行验证清单
```

---

## 输出文件模板（可直接复制使用）

```markdown
# 检索结果摘要

**物种关键词**: {用户输入}
**最终检索式**: {实际使用的检索式}
**筛选条件**: {应用的筛选器}
**检索时间**: {YYYY-MM-DD}
**结果数量**: X 条 SRR

---

## 数据概览

| 指标 | 数值 |
|------|------|
| 总样本数 | X |
| Illumina数据 | X |
| PacBio数据 | X |
| Nanopore数据 | X |
| 总数据量 | X G |

---

## 完整 SRR/DRR/ERR 列表

### 按 Bioproject 分组

**PRJNAxxxxx - 项目名称**
| SRR/DRR | 平台 | 数据量(Spots/Bases) | 布局 |
|---------|------|---------------------|------|
| SRRxxxxx | Illumina NovaSeq 6000 | 50M / 15G | PE |

---

## 数据下载链接

- NCBI SRA: https://www.ncbi.nlm.nih.gov/sra/{ACCESSION}

---

## 来源证据

- 检索URL: https://www.ncbi.nlm.nih.gov/sra/?term={检索式}
- API验证: esearch返回{count}条结果
```
