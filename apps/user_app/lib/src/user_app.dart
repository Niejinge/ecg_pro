import 'package:ecg_api/ecg_api.dart';
import 'package:ecg_ui/ecg_ui.dart';
import 'package:flutter/material.dart';

import 'user_repository.dart';

void runUserApp() {
  runApp(const UserApp());
}

class UserApp extends StatelessWidget {
  const UserApp({super.key, this.repository});

  final UserRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Pro User',
      debugShowCheckedModeBanner: false,
      theme: EcgAppTheme.light(),
      home: UserHomePage(
        repository:
            repository ??
            ApiUserRepository(
              EcgApiClient(
                baseUrl: const String.fromEnvironment(
                  'ECG_API_BASE_URL',
                  defaultValue: 'http://localhost:8000',
                ),
              ),
            ),
      ),
    );
  }
}

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key, required this.repository});

  final UserRepository repository;

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final TextEditingController _searchController = TextEditingController();

  List<CategoryItem> _categories = const [];
  PublicCaseListResponse? _caseResponse;
  String? _selectedCategoryId;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final categories = await widget.repository.fetchCategories();
      final cases = await widget.repository.fetchCases(
        keyword: _searchController.text.trim(),
        categoryId: _selectedCategoryId,
        isFeatured: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _caseResponse = cases;
      });
    } on EcgApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '学习内容加载失败，请检查接口服务是否可用。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCaseDetail(String caseId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FutureBuilder<CaseDetailItem>(
        future: widget.repository.fetchCaseDetail(caseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Dialog(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.lg),
                      Text('正在加载案例详情...'),
                    ],
                  ),
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return AlertDialog(
              title: const Text('详情加载失败'),
              content: const Text('请稍后重试。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          }

          return _CaseDetailDialog(detail: snapshot.data!);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EcgScaffold(
      title: 'ECG Pro 学习端',
      subtitle: '围绕真实心电图案例进行系统学习，先看图，再判断，再回顾诊断与临床处理。',
      actions: [
        IconButton(
          tooltip: '刷新案例',
          onPressed: _loading ? null : _loadInitialData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LearningHero(),
          const SizedBox(height: AppSpacing.xl),
          EcgSectionCard(
            title: '案例筛选',
            subtitle: '按类别和关键词快速收敛到你今天想练习的节律与诊断。',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wideLayout = constraints.maxWidth >= 820;
                final controls = [
                  SizedBox(
                    width: wideLayout ? 280 : double.infinity,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: '关键词',
                        hintText: '例如 房颤、宽 QRS、ST 抬高',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onSubmitted: (_) => _loadInitialData(),
                    ),
                  ),
                  SizedBox(
                    width: wideLayout ? 240 : double.infinity,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: '分类'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部分类'),
                        ),
                        ..._categories.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _loadInitialData,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('应用筛选'),
                  ),
                ];

                if (wideLayout) {
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: controls,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final control in controls) ...[
                      control,
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          EcgSectionCard(
            title: '示例学习案例',
            subtitle: _caseResponse == null
                ? '优先展示精选案例，帮助你从高频场景开始练习。'
                : '共 ${_caseResponse!.total} 个公开案例，当前页 ${_caseResponse!.items.length} 个。',
            child: _buildCaseSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseSection() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.brandSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.brand),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: Text(_errorMessage!)),
          ],
        ),
      );
    }

    final items = _caseResponse?.items ?? const <PublicCaseListItem>[];
    if (items.isEmpty) {
      return const Text('当前筛选下还没有公开案例，可以换个关键词再试试。');
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _CaseSummaryCard(
                item: item,
                onTap: () => _openCaseDetail(item.id),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LearningHero extends StatelessWidget {
  const _LearningHero();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFEFF), Color(0xFFEFF5FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.xl,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('清晰、轻量、适合持续学习'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '用结构化案例建立你的心电图判断路径',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '每个案例都整理了图像、诊断、关键导联、临床意义、风险等级、处理建议和记忆提示，适合从入门到进阶反复练习。',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 280, child: _HeroStats()),
        ],
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _StatTile(title: '学习路径', value: '先识别节律，再看风险与处理'),
        SizedBox(height: AppSpacing.lg),
        _StatTile(title: '案例结构', value: '图像 + 诊断 + 临床建议'),
        SizedBox(height: AppSpacing.lg),
        _StatTile(title: '适用终端', value: 'Web 与 Android 同步体验'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CaseSummaryCard extends StatelessWidget {
  const _CaseSummaryCard({required this.item, required this.onTap});

  final PublicCaseListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Badge(
                  text: item.categoryName ?? '未分类',
                  color: AppColors.brand,
                ),
                _Badge(
                  text: _difficultyLabel(item.difficulty),
                  color: AppColors.accent,
                ),
                _Badge(
                  text: _riskLabel(item.riskLevel),
                  color: _riskColor(item.riskLevel),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.diagnosis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  item.caseCode,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const Spacer(),
                const Text('查看详情'),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CaseDetailDialog extends StatelessWidget {
  const _CaseDetailDialog({required this.detail});

  final CaseDetailItem detail;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          detail.diagnosis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _Badge(
                          text: detail.category?.name ?? '未分类',
                          color: AppColors.brand,
                        ),
                        _Badge(
                          text: _difficultyLabel(detail.difficulty),
                          color: AppColors.accent,
                        ),
                        _Badge(
                          text: _riskLabel(detail.riskLevel),
                          color: _riskColor(detail.riskLevel),
                        ),
                      ],
                    ),
                    if (detail.summary != null &&
                        detail.summary!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _DetailBlock(title: '案例概览', content: detail.summary!),
                    ],
                    if (detail.images.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _ImageStrip(images: detail.images),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _DetailGrid(detail: detail),
                    if (detail.detailedDescription != null &&
                        detail.detailedDescription!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _DetailBlock(
                        title: '详细描述',
                        content: detail.detailedDescription!,
                      ),
                    ],
                    if (detail.treatmentPlan != null &&
                        detail.treatmentPlan!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _DetailBlock(
                        title: '治疗方案',
                        content: detail.treatmentPlan!,
                      ),
                    ],
                    if (detail.learningPoints.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _BulletBlock(title: '学习要点', items: detail.learningPoints),
                    ],
                    if (detail.interpretationSteps.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _BulletBlock(
                        title: '判读步骤',
                        items: detail.interpretationSteps,
                      ),
                    ],
                    if (detail.memoryTips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _BulletBlock(title: '记忆提示', items: detail.memoryTips),
                    ],
                    if (detail.commonMistakes.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _BulletBlock(title: '常见误区', items: detail.commonMistakes),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.detail});

  final CaseDetailItem detail;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[
      MapEntry('风险等级', _riskLabel(detail.riskLevel)),
      MapEntry('难度等级', _difficultyLabel(detail.difficulty)),
      if (detail.rhythmType != null && detail.rhythmType!.isNotEmpty)
        MapEntry('节律类型', detail.rhythmType!),
      if (detail.heartRate != null && detail.heartRate!.isNotEmpty)
        MapEntry('心率', detail.heartRate!),
      if (detail.axisDescription != null && detail.axisDescription!.isNotEmpty)
        MapEntry('电轴', detail.axisDescription!),
      if (detail.prDescription != null && detail.prDescription!.isNotEmpty)
        MapEntry('PR 间期', detail.prDescription!),
      if (detail.qrsDescription != null && detail.qrsDescription!.isNotEmpty)
        MapEntry('QRS 波群', detail.qrsDescription!),
      if (detail.stTDescription != null && detail.stTDescription!.isNotEmpty)
        MapEntry('ST-T 改变', detail.stTDescription!),
      if (detail.qtDescription != null && detail.qtDescription!.isNotEmpty)
        MapEntry('QT 间期', detail.qtDescription!),
      if (detail.urgentActions != null && detail.urgentActions!.isNotEmpty)
        MapEntry('紧急处理', detail.urgentActions!),
      if (detail.followUpRecommendations != null &&
          detail.followUpRecommendations!.isNotEmpty)
        MapEntry('随访建议', detail.followUpRecommendations!),
      if (detail.keyLeads.isNotEmpty)
        MapEntry('关键导联', detail.keyLeads.join('、')),
    ];

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: entries
          .map(
            (entry) => SizedBox(
              width: 260,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _BulletBlock extends StatelessWidget {
  const _BulletBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 8, color: AppColors.brand),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.images});

  final List<CaseImageItem> images;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '案例图像',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
            itemBuilder: (context, index) {
              final image = images[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 300,
                  child: ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: Image.network(
                      image.fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Text('图片预览不可用')),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _difficultyLabel(DifficultyLevel level) {
  switch (level) {
    case DifficultyLevel.beginner:
      return '入门';
    case DifficultyLevel.intermediate:
      return '进阶';
    case DifficultyLevel.advanced:
      return '高级';
  }
}

String _riskLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:
      return '低风险';
    case RiskLevel.medium:
      return '中风险';
    case RiskLevel.high:
      return '高风险';
    case RiskLevel.critical:
      return '危急';
  }
}

Color _riskColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:
      return AppColors.success;
    case RiskLevel.medium:
      return AppColors.warning;
    case RiskLevel.high:
      return const Color(0xFFE86C2E);
    case RiskLevel.critical:
      return AppColors.danger;
  }
}
