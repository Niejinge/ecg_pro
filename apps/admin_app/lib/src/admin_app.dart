import 'package:ecg_api/ecg_api.dart';
import 'package:ecg_ui/ecg_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'admin_repository.dart';

enum _AdminSection { dashboard, taxonomy, cases }

class AdminApp extends StatefulWidget {
  AdminApp({
    super.key,
    AdminRepository? repository,
    AdminSessionStore? sessionStore,
    this.initialSession,
  }) : repository =
           repository ??
           ApiAdminRepository(
             EcgApiClient(
               baseUrl: const String.fromEnvironment(
                 'ECG_API_BASE_URL',
                 defaultValue: 'http://localhost:8000',
               ),
             ),
           ),
       sessionStore = sessionStore ?? SharedPreferencesAdminSessionStore();

  final AdminRepository repository;
  final AdminSessionStore sessionStore;
  final AdminSession? initialSession;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  AdminSession? _session;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final initialSession = widget.initialSession;
    if (initialSession != null) {
      setState(() {
        _session = initialSession;
        _restoringSession = false;
      });
      return;
    }

    final restored = await widget.sessionStore.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = restored;
      _restoringSession = false;
    });
  }

  Future<void> _handleLogin(AdminSession session) async {
    await widget.sessionStore.write(session);
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    await widget.sessionStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Pro Admin',
      debugShowCheckedModeBanner: false,
      theme: EcgAppTheme.light(),
      home: _restoringSession
          ? const _AdminBootPage()
          : _session == null
          ? _AdminLoginPage(
              repository: widget.repository,
              onLogin: _handleLogin,
            )
          : _AdminShell(
              repository: widget.repository,
              session: _session!,
              onLogout: _handleLogout,
            ),
    );
  }
}

class _AdminBootPage extends StatelessWidget {
  const _AdminBootPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text('正在恢复后台会话...'),
          ],
        ),
      ),
    );
  }
}

class _AdminLoginPage extends StatefulWidget {
  const _AdminLoginPage({required this.repository, required this.onLogin});

  final AdminRepository repository;
  final ValueChanged<AdminSession> onLogin;

  @override
  State<_AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<_AdminLoginPage> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'Admin123456');
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.repository.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      widget.onLogin(session);
    } on EcgApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = '登录失败，请检查接口服务和账号信息。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFF), Color(0xFFEFF4FF)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  const Expanded(child: _LoginHero()),
                  const SizedBox(width: AppSpacing.xl),
                  SizedBox(
                    width: 420,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '管理员登录',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                '登录后可管理案例、分类标签、题目与图片资源。',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: '用户名',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '请输入用户名';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              TextFormField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: '密码',
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.length < 6) {
                                    return '密码至少 6 位';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.danger),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submitting ? null : _submit,
                                  child: Text(_submitting ? '登录中...' : '进入后台'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                child: Text(
                                  '默认演示账号会由后端引导脚本创建：`admin / Admin123456`。',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'ECG Pro Admin',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '心电图内容管理后台',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '用清晰、轻量的界面维护教学案例，快速完成分类、标签、题目和图片管理。',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: const [
            Chip(label: Text('案例录入')),
            Chip(label: Text('题目维护')),
            Chip(label: Text('图片管理')),
            Chip(label: Text('发布下线')),
          ],
        ),
      ],
    );
  }
}

class _AdminShell extends StatefulWidget {
  const _AdminShell({
    required this.repository,
    required this.session,
    required this.onLogout,
  });

  final AdminRepository repository;
  final AdminSession session;
  final VoidCallback onLogout;

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  _AdminSection _section = _AdminSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 250,
              margin: const EdgeInsets.all(AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ECG Pro',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '管理端',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SidebarItem(
                    title: '数据概览',
                    subtitle: '查看后台基础统计',
                    selected: _section == _AdminSection.dashboard,
                    onTap: () {
                      setState(() {
                        _section = _AdminSection.dashboard;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SidebarItem(
                    title: '分类与标签',
                    subtitle: '维护内容结构',
                    selected: _section == _AdminSection.taxonomy,
                    onTap: () {
                      setState(() {
                        _section = _AdminSection.taxonomy;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SidebarItem(
                    title: '案例管理',
                    subtitle: '编辑案例、题目和图片',
                    selected: _section == _AdminSection.cases,
                    onTap: () {
                      setState(() {
                        _section = _AdminSection.cases;
                      });
                    },
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.user.displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.session.user.username,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.onLogout,
                            child: const Text('退出登录'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildSection(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _AdminSection.dashboard:
        return _PageFrame(
          key: const ValueKey('dashboard'),
          title: '数据概览',
          subtitle: '快速查看当前后台案例、题目与用户规模。',
          child: _DashboardPage(
            repository: widget.repository,
            session: widget.session,
          ),
        );
      case _AdminSection.taxonomy:
        return _PageFrame(
          key: const ValueKey('taxonomy'),
          title: '分类与标签',
          subtitle: '维护后台案例归类所需的内容结构。',
          child: _TaxonomyPage(
            repository: widget.repository,
            session: widget.session,
          ),
        );
      case _AdminSection.cases:
        return _PageFrame(
          key: const ValueKey('cases'),
          title: '案例管理',
          subtitle: '支持筛选、编辑、题目配置、图片上传和发布下线。',
          child: _CasesPage(
            repository: widget.repository,
            session: widget.session,
          ),
        );
    }
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.brand : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({required this.repository, required this.session});

  final AdminRepository repository;
  final AdminSession session;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  late Future<DashboardSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.repository.fetchDashboardSummary(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EcgSectionCard(
            title: '加载失败',
            subtitle: '请检查后端服务是否已启动。',
            child: Text(
              snapshot.error.toString(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
            ),
          );
        }

        final summary = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                _StatCard(
                  title: '案例总数',
                  value: '${summary.totalCases}',
                  hint: '已录入案例',
                ),
                _StatCard(
                  title: '已发布案例',
                  value: '${summary.publishedCases}',
                  hint: '前台可学习',
                ),
                _StatCard(
                  title: '题目总数',
                  value: '${summary.totalQuestions}',
                  hint: '测验题累计',
                ),
                _StatCard(
                  title: '用户总数',
                  value: '${summary.totalUsers}',
                  hint: '当前注册用户',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            EcgSectionCard(
              title: '后台推进建议',
              subtitle: '建议优先补齐高频录入链路，再做统计和体验增强。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _BulletLine('优先录入分类、标签和演示案例，方便前后端联调。'),
                  _BulletLine('发布前先补题目和主图，确保用户端体验闭环。'),
                  _BulletLine('复杂字段建议先按结构化文本录入，后续再做更细分组件。'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaxonomyPage extends StatefulWidget {
  const _TaxonomyPage({required this.repository, required this.session});

  final AdminRepository repository;
  final AdminSession session;

  @override
  State<_TaxonomyPage> createState() => _TaxonomyPageState();
}

class _TaxonomyPageState extends State<_TaxonomyPage> {
  bool _loading = true;
  String? _error;
  List<CategoryItem> _categories = const [];
  List<TagItem> _tags = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.repository.fetchCategories(
        widget.session,
      );
      final tags = await widget.repository.fetchTags(widget.session);
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _tags = tags;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _editCategory([CategoryItem? item]) async {
    final input = await showDialog<CategoryUpsertInput>(
      context: context,
      builder: (context) => _CategoryDialog(category: item),
    );
    if (input == null) {
      return;
    }

    try {
      if (item == null) {
        await widget.repository.createCategory(widget.session, input);
      } else {
        await widget.repository.updateCategory(widget.session, item.id, input);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(item == null ? '分类已创建' : '分类已更新')));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分类保存失败：$error')));
    }
  }

  Future<void> _editTag([TagItem? item]) async {
    final input = await showDialog<TagUpsertInput>(
      context: context,
      builder: (context) => _TagDialog(tag: item),
    );
    if (input == null) {
      return;
    }

    try {
      if (item == null) {
        await widget.repository.createTag(widget.session, input);
      } else {
        await widget.repository.updateTag(widget.session, item.id, input);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(item == null ? '标签已创建' : '标签已更新')));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('标签保存失败：$error')));
    }
  }

  Future<void> _deleteCategory(CategoryItem item) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: '删除分类',
      content: '确认删除分类“${item.name}”？',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteCategory(widget.session, item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分类已删除')));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除分类失败：$error')));
    }
  }

  Future<void> _deleteTag(TagItem item) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: '删除标签',
      content: '确认删除标签“${item.name}”？',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteTag(widget.session, item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签已删除')));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除标签失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EcgSectionCard(
        title: '加载失败',
        subtitle: '分类和标签接口暂时不可用。',
        child: Text(
          _error!,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            _StatCard(
              title: '分类数量',
              value: '${_categories.length}',
              hint: '当前可用分类',
            ),
            _StatCard(title: '标签数量', value: '${_tags.length}', hint: '当前可用标签'),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        EcgSectionCard(
          title: '分类管理',
          subtitle: '用于组织案例的主结构。',
          trailing: FilledButton(
            onPressed: _editCategory,
            child: const Text('新增分类'),
          ),
          child: _buildCategoryTable(),
        ),
        const SizedBox(height: AppSpacing.xl),
        EcgSectionCard(
          title: '标签管理',
          subtitle: '用于补充案例的主题和风险维度。',
          trailing: FilledButton(
            onPressed: _editTag,
            child: const Text('新增标签'),
          ),
          child: _buildTagTable(),
        ),
      ],
    );
  }

  Widget _buildCategoryTable() {
    if (_categories.isEmpty) {
      return const _EmptyState(
        title: '还没有分类',
        description: '先创建分类，后续案例编辑时就可以直接选择。',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('名称')),
          DataColumn(label: Text('Slug')),
          DataColumn(label: Text('排序')),
          DataColumn(label: Text('可见')),
          DataColumn(label: Text('操作')),
        ],
        rows: _categories
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.name)),
                  DataCell(Text(item.slug)),
                  DataCell(Text('${item.sortOrder}')),
                  DataCell(Text(item.isVisible ? '是' : '否')),
                  DataCell(
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed: () => _editCategory(item),
                          child: const Text('编辑'),
                        ),
                        TextButton(
                          onPressed: () => _deleteCategory(item),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTagTable() {
    if (_tags.isEmpty) {
      return const _EmptyState(
        title: '还没有标签',
        description: '建议先补齐高危、急诊、基础等常用标签。',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('名称')),
          DataColumn(label: Text('Slug')),
          DataColumn(label: Text('描述')),
          DataColumn(label: Text('操作')),
        ],
        rows: _tags
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.name)),
                  DataCell(Text(item.slug)),
                  DataCell(Text(item.description ?? '-')),
                  DataCell(
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed: () => _editTag(item),
                          child: const Text('编辑'),
                        ),
                        TextButton(
                          onPressed: () => _deleteTag(item),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CasesPage extends StatefulWidget {
  const _CasesPage({required this.repository, required this.session});

  final AdminRepository repository;
  final AdminSession session;

  @override
  State<_CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<_CasesPage> {
  final _keywordController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<CategoryItem> _categories = const [];
  List<TagItem> _tags = const [];
  AdminCaseListResponse? _cases;
  int _page = 1;
  final int _pageSize = 10;
  String? _categoryId;
  CaseStatus? _status;
  DifficultyLevel? _difficulty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.repository.fetchCategories(
        widget.session,
      );
      final tags = await widget.repository.fetchTags(widget.session);
      final cases = await widget.repository.fetchCases(
        widget.session,
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        categoryId: _categoryId,
        status: _status,
        difficulty: _difficulty,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _tags = tags;
        _cases = cases;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditor([String? caseId]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CaseEditorDialog(
        repository: widget.repository,
        session: widget.session,
        categories: _categories,
        tags: _tags,
        caseId: caseId,
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _publish(AdminCaseListItem item) async {
    try {
      await widget.repository.publishCase(widget.session, item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('案例“${item.title}”已发布')));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发布失败：$error')));
    }
  }

  Future<void> _offline(AdminCaseListItem item) async {
    try {
      await widget.repository.offlineCase(widget.session, item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('案例“${item.title}”已下线')));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下线失败：$error')));
    }
  }

  Future<void> _delete(AdminCaseListItem item) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: '删除案例',
      content: '确认删除案例“${item.title}”？此操作不可恢复。',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteCase(widget.session, item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('案例已删除')));
      if (_page > 1 && (_cases?.items.length ?? 0) == 1) {
        _page -= 1;
      }
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return EcgSectionCard(
        title: '案例加载失败',
        subtitle: '请确认后端服务正常运行。',
        child: Text(
          _error!,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
      );
    }

    final response = _cases!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EcgSectionCard(
          title: '筛选与检索',
          subtitle: '先按分类和状态过滤，再进入案例编辑。',
          trailing: FilledButton(
            onPressed: () => _openEditor(),
            child: const Text('新增案例'),
          ),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '关键词',
                    hintText: '案例标题 / 诊断 / 编号',
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('case-filter-category-$_categoryId'),
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部分类'),
                    ),
                    ..._categories.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _categoryId = value;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<CaseStatus?>(
                  key: ValueKey('case-filter-status-$_status'),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: '状态'),
                  items: const [
                    DropdownMenuItem<CaseStatus?>(
                      value: null,
                      child: Text('全部状态'),
                    ),
                    DropdownMenuItem<CaseStatus?>(
                      value: CaseStatus.draft,
                      child: Text('草稿'),
                    ),
                    DropdownMenuItem<CaseStatus?>(
                      value: CaseStatus.published,
                      child: Text('已发布'),
                    ),
                    DropdownMenuItem<CaseStatus?>(
                      value: CaseStatus.offline,
                      child: Text('已下线'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _status = value;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<DifficultyLevel?>(
                  key: ValueKey('case-filter-difficulty-$_difficulty'),
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: '难度'),
                  items: const [
                    DropdownMenuItem<DifficultyLevel?>(
                      value: null,
                      child: Text('全部难度'),
                    ),
                    DropdownMenuItem<DifficultyLevel?>(
                      value: DifficultyLevel.beginner,
                      child: Text('入门'),
                    ),
                    DropdownMenuItem<DifficultyLevel?>(
                      value: DifficultyLevel.intermediate,
                      child: Text('进阶'),
                    ),
                    DropdownMenuItem<DifficultyLevel?>(
                      value: DifficultyLevel.advanced,
                      child: Text('高级'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _difficulty = value;
                    });
                  },
                ),
              ),
              FilledButton(
                onPressed: () {
                  _page = 1;
                  _load();
                },
                child: const Text('查询'),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _keywordController.clear();
                    _categoryId = null;
                    _status = null;
                    _difficulty = null;
                    _page = 1;
                  });
                  _load();
                },
                child: const Text('重置'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        EcgSectionCard(
          title: '案例列表',
          subtitle: '共 ${response.total} 条记录，当前第 ${response.page} 页。',
          child: response.items.isEmpty
              ? const _EmptyState(
                  title: '暂无案例',
                  description: '先创建一个案例，然后继续补图片和题目。',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('编号')),
                          DataColumn(label: Text('标题')),
                          DataColumn(label: Text('分类')),
                          DataColumn(label: Text('难度')),
                          DataColumn(label: Text('风险')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('更新时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: response.items
                            .map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(Text(item.caseCode)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 220,
                                      ),
                                      child: Text(item.title),
                                    ),
                                  ),
                                  DataCell(Text(item.categoryName ?? '-')),
                                  DataCell(
                                    Text(_difficultyLabel(item.difficulty)),
                                  ),
                                  DataCell(
                                    _Badge(
                                      label: _riskLabel(item.riskLevel),
                                      color: _riskColor(item.riskLevel),
                                    ),
                                  ),
                                  DataCell(
                                    _Badge(
                                      label: _statusLabel(item.status),
                                      color: _statusColor(item.status),
                                    ),
                                  ),
                                  DataCell(Text(_formatDate(item.updatedAt))),
                                  DataCell(
                                    Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.sm,
                                      children: [
                                        TextButton(
                                          onPressed: () => _openEditor(item.id),
                                          child: const Text('编辑'),
                                        ),
                                        if (item.status != CaseStatus.published)
                                          TextButton(
                                            onPressed: () => _publish(item),
                                            child: const Text('发布'),
                                          ),
                                        if (item.status == CaseStatus.published)
                                          TextButton(
                                            onPressed: () => _offline(item),
                                            child: const Text('下线'),
                                          ),
                                        TextButton(
                                          onPressed: () => _delete(item),
                                          child: const Text('删除'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Text(
                          '第 ${response.page} 页 / 每页 ${response.pageSize} 条',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: response.page > 1
                              ? () {
                                  _page -= 1;
                                  _load();
                                }
                              : null,
                          child: const Text('上一页'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        FilledButton(
                          onPressed: response.hasNext
                              ? () {
                                  _page += 1;
                                  _load();
                                }
                              : null,
                          child: const Text('下一页'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final CategoryItem? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sortOrderController;
  late bool _isVisible;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _slugController = TextEditingController(text: widget.category?.slug ?? '');
    _descriptionController = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _sortOrderController = TextEditingController(
      text: '${widget.category?.sortOrder ?? 0}',
    );
    _isVisible = widget.category?.isVisible ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? '新增分类' : '编辑分类'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入分类名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(labelText: 'Slug'),
                validator: (value) {
                  final slug = value?.trim() ?? '';
                  if (slug.isEmpty) {
                    return '请输入分类 slug';
                  }
                  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) {
                    return 'slug 仅支持小写字母、数字和连字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '描述'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _sortOrderController,
                decoration: const InputDecoration(labelText: '排序'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入排序值';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return '排序必须是整数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('前台可见'),
                value: _isVisible,
                onChanged: (value) {
                  setState(() {
                    _isVisible = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              CategoryUpsertInput(
                name: _nameController.text.trim(),
                slug: _slugController.text.trim(),
                description: _nullIfEmpty(_descriptionController.text),
                sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
                isVisible: _isVisible,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({this.tag});

  final TagItem? tag;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _slugController = TextEditingController(text: widget.tag?.slug ?? '');
    _descriptionController = TextEditingController(
      text: widget.tag?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tag == null ? '新增标签' : '编辑标签'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入标签名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(labelText: 'Slug'),
                validator: (value) {
                  final slug = value?.trim() ?? '';
                  if (slug.isEmpty) {
                    return '请输入标签 slug';
                  }
                  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) {
                    return 'slug 仅支持小写字母、数字和连字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '描述'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              TagUpsertInput(
                name: _nameController.text.trim(),
                slug: _slugController.text.trim(),
                description: _nullIfEmpty(_descriptionController.text),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _CaseEditorDialog extends StatefulWidget {
  const _CaseEditorDialog({
    required this.repository,
    required this.session,
    required this.categories,
    required this.tags,
    this.caseId,
  });

  final AdminRepository repository;
  final AdminSession session;
  final List<CategoryItem> categories;
  final List<TagItem> tags;
  final String? caseId;

  @override
  State<_CaseEditorDialog> createState() => _CaseEditorDialogState();
}

class _CaseEditorDialogState extends State<_CaseEditorDialog> {
  late final TextEditingController _caseCodeController;
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _diagnosisController;
  late final TextEditingController _rhythmTypeController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _axisController;
  late final TextEditingController _prController;
  late final TextEditingController _qrsController;
  late final TextEditingController _sttController;
  late final TextEditingController _qtController;
  late final TextEditingController _keyLeadsController;
  late final TextEditingController _clinicalSignificanceController;
  late final TextEditingController _differentialDiagnosisController;
  late final TextEditingController _treatmentPlanController;
  late final TextEditingController _urgentActionsController;
  late final TextEditingController _followUpController;
  late final TextEditingController _detailController;
  late final TextEditingController _interpretationStepsController;
  late final TextEditingController _learningPointsController;
  late final TextEditingController _commonMistakesController;
  late final TextEditingController _memoryTipsController;

  final Set<String> _tagIds = <String>{};

  bool _loading = false;
  bool _saving = false;
  bool _uploadingImage = false;
  DifficultyLevel _difficulty = DifficultyLevel.beginner;
  RiskLevel _riskLevel = RiskLevel.low;
  String? _categoryId;
  bool _isFeatured = false;
  String? _currentCaseId;
  CaseDetailItem? _detail;
  List<AdminQuizQuestionItem> _questions = const [];

  @override
  void initState() {
    super.initState();
    _caseCodeController = TextEditingController();
    _titleController = TextEditingController();
    _summaryController = TextEditingController();
    _diagnosisController = TextEditingController();
    _rhythmTypeController = TextEditingController();
    _heartRateController = TextEditingController();
    _axisController = TextEditingController();
    _prController = TextEditingController();
    _qrsController = TextEditingController();
    _sttController = TextEditingController();
    _qtController = TextEditingController();
    _keyLeadsController = TextEditingController();
    _clinicalSignificanceController = TextEditingController();
    _differentialDiagnosisController = TextEditingController();
    _treatmentPlanController = TextEditingController();
    _urgentActionsController = TextEditingController();
    _followUpController = TextEditingController();
    _detailController = TextEditingController();
    _interpretationStepsController = TextEditingController();
    _learningPointsController = TextEditingController();
    _commonMistakesController = TextEditingController();
    _memoryTipsController = TextEditingController();
    _currentCaseId = widget.caseId;

    if (_currentCaseId != null) {
      _loadExistingCase();
    }
  }

  @override
  void dispose() {
    _caseCodeController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _diagnosisController.dispose();
    _rhythmTypeController.dispose();
    _heartRateController.dispose();
    _axisController.dispose();
    _prController.dispose();
    _qrsController.dispose();
    _sttController.dispose();
    _qtController.dispose();
    _keyLeadsController.dispose();
    _clinicalSignificanceController.dispose();
    _differentialDiagnosisController.dispose();
    _treatmentPlanController.dispose();
    _urgentActionsController.dispose();
    _followUpController.dispose();
    _detailController.dispose();
    _interpretationStepsController.dispose();
    _learningPointsController.dispose();
    _commonMistakesController.dispose();
    _memoryTipsController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingCase() async {
    setState(() {
      _loading = true;
    });
    try {
      final detail = await widget.repository.fetchCaseDetail(
        widget.session,
        _currentCaseId!,
      );
      final questions = await widget.repository.fetchQuestions(
        widget.session,
        _currentCaseId!,
      );
      if (!mounted) {
        return;
      }
      _applyDetail(detail);
      setState(() {
        _detail = detail;
        _questions = questions;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyDetail(CaseDetailItem detail) {
    _caseCodeController.text = detail.caseCode;
    _titleController.text = detail.title;
    _summaryController.text = detail.summary ?? '';
    _diagnosisController.text = detail.diagnosis;
    _rhythmTypeController.text = detail.rhythmType ?? '';
    _heartRateController.text = detail.heartRate ?? '';
    _axisController.text = detail.axisDescription ?? '';
    _prController.text = detail.prDescription ?? '';
    _qrsController.text = detail.qrsDescription ?? '';
    _sttController.text = detail.stTDescription ?? '';
    _qtController.text = detail.qtDescription ?? '';
    _keyLeadsController.text = detail.keyLeads.join('\n');
    _clinicalSignificanceController.text = detail.clinicalSignificance ?? '';
    _differentialDiagnosisController.text = detail.differentialDiagnosis ?? '';
    _treatmentPlanController.text = detail.treatmentPlan ?? '';
    _urgentActionsController.text = detail.urgentActions ?? '';
    _followUpController.text = detail.followUpRecommendations ?? '';
    _detailController.text = detail.detailedDescription ?? '';
    _interpretationStepsController.text = detail.interpretationSteps.join('\n');
    _learningPointsController.text = detail.learningPoints.join('\n');
    _commonMistakesController.text = detail.commonMistakes.join('\n');
    _memoryTipsController.text = detail.memoryTips.join('\n');
    _difficulty = detail.difficulty;
    _riskLevel = detail.riskLevel;
    _categoryId = detail.category?.id;
    _isFeatured = detail.isFeatured;
    _tagIds
      ..clear()
      ..addAll(detail.tags.map((item) => item.id));
  }

  Future<void> _refreshCaseAssets() async {
    if (_currentCaseId == null) {
      return;
    }

    final detail = await widget.repository.fetchCaseDetail(
      widget.session,
      _currentCaseId!,
    );
    final questions = await widget.repository.fetchQuestions(
      widget.session,
      _currentCaseId!,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _detail = detail;
      _questions = questions;
    });
  }

  Future<void> _saveCase() async {
    final caseCode = _caseCodeController.text.trim();
    final title = _titleController.text.trim();
    final diagnosis = _diagnosisController.text.trim();
    if (caseCode.isEmpty || title.isEmpty || diagnosis.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('案例编号、标题和诊断是必填项。')));
      return;
    }
    if (_parseListField(_keyLeadsController.text).isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少填写一个关键导联。')));
      return;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请为案例选择一个分类。')));
      return;
    }

    final input = AdminCaseUpsertInput(
      caseCode: caseCode,
      title: title,
      diagnosis: diagnosis,
      summary: _nullIfEmpty(_summaryController.text),
      rhythmType: _nullIfEmpty(_rhythmTypeController.text),
      heartRate: _nullIfEmpty(_heartRateController.text),
      axisDescription: _nullIfEmpty(_axisController.text),
      prDescription: _nullIfEmpty(_prController.text),
      qrsDescription: _nullIfEmpty(_qrsController.text),
      stTDescription: _nullIfEmpty(_sttController.text),
      qtDescription: _nullIfEmpty(_qtController.text),
      keyLeads: _parseListField(_keyLeadsController.text),
      clinicalSignificance: _nullIfEmpty(_clinicalSignificanceController.text),
      differentialDiagnosis: _nullIfEmpty(
        _differentialDiagnosisController.text,
      ),
      treatmentPlan: _nullIfEmpty(_treatmentPlanController.text),
      urgentActions: _nullIfEmpty(_urgentActionsController.text),
      followUpRecommendations: _nullIfEmpty(_followUpController.text),
      detailedDescription: _nullIfEmpty(_detailController.text),
      interpretationSteps: _parseListField(_interpretationStepsController.text),
      learningPoints: _parseListField(_learningPointsController.text),
      commonMistakes: _parseListField(_commonMistakesController.text),
      memoryTips: _parseListField(_memoryTipsController.text),
      difficulty: _difficulty,
      riskLevel: _riskLevel,
      categoryId: _categoryId,
      tagIds: _tagIds.toList(),
      isFeatured: _isFeatured,
    );

    setState(() {
      _saving = true;
    });
    try {
      final detail = _currentCaseId == null
          ? await widget.repository.createCase(widget.session, input)
          : await widget.repository.updateCase(
              widget.session,
              _currentCaseId!,
              input,
            );
      if (!mounted) {
        return;
      }
      _applyDetail(detail);
      setState(() {
        _detail = detail;
        _currentCaseId = detail.id;
      });
      await _refreshCaseAssets();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_currentCaseId == widget.caseId ? '案例已更新' : '案例已创建'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('案例保存失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_currentCaseId == null || _uploadingImage) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      return;
    }

    setState(() {
      _uploadingImage = true;
    });
    try {
      await widget.repository.uploadCaseImage(
        widget.session,
        caseId: _currentCaseId!,
        bytes: bytes,
        fileName: file.name,
        contentType: _guessMimeType(file.name),
        isPrimary: (_detail?.images.isEmpty ?? true),
        sortOrder: _detail?.images.length ?? 0,
      );
      await _refreshCaseAssets();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片已上传')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片上传失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _setPrimaryImage(CaseImageItem image) async {
    try {
      await widget.repository.updateCaseImage(
        widget.session,
        image.id,
        const UpdateCaseImageInput(isPrimary: true),
      );
      await _refreshCaseAssets();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('主图设置失败：$error')));
    }
  }

  Future<void> _moveImage(CaseImageItem image, int offset) async {
    final images = List<CaseImageItem>.from(_detail?.images ?? const []);
    final index = images.indexWhere((item) => item.id == image.id);
    final newIndex = index + offset;
    if (index < 0 || newIndex < 0 || newIndex >= images.length) {
      return;
    }
    final moved = images.removeAt(index);
    images.insert(newIndex, moved);

    try {
      await widget.repository.reorderCaseImages(
        widget.session,
        caseId: _currentCaseId!,
        items: [
          for (var i = 0; i < images.length; i++)
            ReorderCaseImageItemInput(imageId: images[i].id, sortOrder: i),
        ],
      );
      await _refreshCaseAssets();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片排序失败：$error')));
    }
  }

  Future<void> _deleteImage(CaseImageItem image) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: '删除图片',
      content: '确认删除图片“${image.fileName}”？',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteCaseImage(widget.session, image.id);
      await _refreshCaseAssets();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片删除失败：$error')));
    }
  }

  Future<void> _editQuestion([AdminQuizQuestionItem? question]) async {
    final input = await showDialog<AdminQuizQuestionUpsertInput>(
      context: context,
      builder: (context) => _QuestionEditorDialog(
        question: question,
        nextSortOrder: question?.sortOrder ?? (_questions.length + 1),
      ),
    );
    if (input == null || _currentCaseId == null) {
      return;
    }

    try {
      if (question == null) {
        await widget.repository.createQuestion(
          widget.session,
          _currentCaseId!,
          input,
        );
      } else {
        await widget.repository.updateQuestion(
          widget.session,
          question.id,
          input,
        );
      }
      await _refreshCaseAssets();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(question == null ? '题目已新增' : '题目已更新')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('题目保存失败：$error')));
    }
  }

  Future<void> _deleteQuestion(AdminQuizQuestionItem question) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: '删除题目',
      content: '确认删除题目“${question.stem}”？',
    );
    if (!confirmed) {
      return;
    }

    try {
      await widget.repository.deleteQuestion(widget.session, question.id);
      await _refreshCaseAssets();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除题目失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAssets = _currentCaseId != null;
    final tabCount = hasAssets ? 3 : 1;

    return Dialog.fullscreen(
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : DefaultTabController(
                length: tabCount,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xl,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.caseId == null ? '新增案例' : '编辑案例',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  hasAssets
                                      ? '案例基础信息已保存，可继续维护图片和题目。'
                                      : '先保存案例基础信息，再补充图片和题目。',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('关闭'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          FilledButton(
                            onPressed: _saving ? null : _saveCase,
                            child: Text(_saving ? '保存中...' : '保存案例'),
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        const Tab(text: '案例信息'),
                        if (hasAssets) const Tab(text: '图片管理'),
                        if (hasAssets) const Tab(text: '题目管理'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCaseForm(),
                          if (hasAssets) _buildImagesTab(),
                          if (hasAssets) _buildQuestionsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCaseForm() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        EcgSectionCard(
          title: '基础信息',
          subtitle: '录入案例最核心的标识信息和展示元数据。',
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              _fieldBox(
                260,
                TextField(
                  controller: _caseCodeController,
                  decoration: const InputDecoration(labelText: '案例编号 *'),
                ),
              ),
              _fieldBox(
                320,
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '案例标题 *'),
                ),
              ),
              _fieldBox(
                320,
                TextField(
                  controller: _diagnosisController,
                  decoration: const InputDecoration(labelText: '诊断 *'),
                ),
              ),
              _fieldBox(
                260,
                DropdownButtonFormField<String?>(
                  key: ValueKey('editor-category-$_categoryId'),
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('未分类'),
                    ),
                    ...widget.categories.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _categoryId = value;
                    });
                  },
                ),
              ),
              _fieldBox(
                200,
                DropdownButtonFormField<DifficultyLevel>(
                  key: ValueKey('editor-difficulty-$_difficulty'),
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: '难度'),
                  items: const [
                    DropdownMenuItem(
                      value: DifficultyLevel.beginner,
                      child: Text('入门'),
                    ),
                    DropdownMenuItem(
                      value: DifficultyLevel.intermediate,
                      child: Text('进阶'),
                    ),
                    DropdownMenuItem(
                      value: DifficultyLevel.advanced,
                      child: Text('高级'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _difficulty = value;
                    });
                  },
                ),
              ),
              _fieldBox(
                200,
                DropdownButtonFormField<RiskLevel>(
                  key: ValueKey('editor-risk-$_riskLevel'),
                  initialValue: _riskLevel,
                  decoration: const InputDecoration(labelText: '风险等级'),
                  items: const [
                    DropdownMenuItem(value: RiskLevel.low, child: Text('低')),
                    DropdownMenuItem(value: RiskLevel.medium, child: Text('中')),
                    DropdownMenuItem(value: RiskLevel.high, child: Text('高')),
                    DropdownMenuItem(
                      value: RiskLevel.critical,
                      child: Text('危急'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _riskLevel = value;
                    });
                  },
                ),
              ),
              _fieldBox(
                220,
                TextField(
                  controller: _rhythmTypeController,
                  decoration: const InputDecoration(labelText: '节律类型'),
                ),
              ),
              _fieldBox(
                220,
                TextField(
                  controller: _heartRateController,
                  decoration: const InputDecoration(labelText: '心率'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        EcgSectionCard(
          title: '标签与摘要',
          subtitle: '帮助前台建立更明确的检索和学习提示。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: widget.tags
                    .map(
                      (tag) => FilterChip(
                        label: Text(tag.name),
                        selected: _tagIds.contains(tag.id),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _tagIds.add(tag.id);
                            } else {
                              _tagIds.remove(tag.id);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _summaryController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '案例摘要',
                  hintText: '用于列表页的简短描述。',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('设为精选案例'),
                subtitle: const Text('精选案例会在列表中优先展示。'),
                value: _isFeatured,
                onChanged: (value) {
                  setState(() {
                    _isFeatured = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        EcgSectionCard(
          title: '判读结构',
          subtitle: '按照心电图分析流程维护关键字段。',
          child: Column(
            children: [
              TextField(
                controller: _axisController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '电轴描述'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _prController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'PR 描述'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _qrsController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'QRS 描述'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _sttController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ST-T 描述'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _qtController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'QT 描述'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _keyLeadsController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '关键导联',
                  hintText: '每行一个，或用逗号分隔。',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        EcgSectionCard(
          title: '临床内容',
          subtitle: '补充诊断意义、鉴别和治疗建议。',
          child: Column(
            children: [
              TextField(
                controller: _clinicalSignificanceController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '临床意义'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _differentialDiagnosisController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '鉴别诊断'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _treatmentPlanController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '治疗方案'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _urgentActionsController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '紧急处理'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _followUpController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '随访建议'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _detailController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '详细描述'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        EcgSectionCard(
          title: '教学要点',
          subtitle: '建议以每行一条的形式维护，方便前台拆块展示。',
          child: Column(
            children: [
              TextField(
                controller: _interpretationStepsController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '判读步骤'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _learningPointsController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '学习要点'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _commonMistakesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '常见误区'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _memoryTipsController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '记忆提示'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagesTab() {
    final images = _detail?.images ?? const [];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: EcgSectionCard(
        title: '图片管理',
        subtitle: '上传案例图、切换主图并调整顺序。',
        trailing: FilledButton(
          onPressed: _uploadingImage ? null : _uploadImage,
          child: Text(_uploadingImage ? '上传中...' : '上传图片'),
        ),
        child: images.isEmpty
            ? const _EmptyState(
                title: '还没有图片',
                description: '建议先上传一张标准心电图图片作为主图。',
              )
            : Column(
                children: images
                    .map(
                      (image) => Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.network(
                                image.fileUrl,
                                width: 160,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 160,
                                      height: 110,
                                      color: AppColors.surface,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.image_outlined),
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    image.fileName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      _Badge(
                                        label: image.isPrimary ? '主图' : '附图',
                                        color: image.isPrimary
                                            ? AppColors.success
                                            : AppColors.textMuted,
                                      ),
                                      _Badge(
                                        label: '排序 ${image.sortOrder}',
                                        color: AppColors.brand,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      OutlinedButton(
                                        onPressed: image.isPrimary
                                            ? null
                                            : () => _setPrimaryImage(image),
                                        child: const Text('设为主图'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _moveImage(image, -1),
                                        child: const Text('上移'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _moveImage(image, 1),
                                        child: const Text('下移'),
                                      ),
                                      TextButton(
                                        onPressed: () => _deleteImage(image),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Widget _buildQuestionsTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: EcgSectionCard(
        title: '题目管理',
        subtitle: '围绕当前案例维护测验题和选项。',
        trailing: FilledButton(
          onPressed: _editQuestion,
          child: const Text('新增题目'),
        ),
        child: _questions.isEmpty
            ? const _EmptyState(
                title: '还没有题目',
                description: '建议每个案例先补 1-3 道题，方便前台联调。',
              )
            : Column(
                children: _questions
                    .map(
                      (question) => Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    question.stem,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _editQuestion(question),
                                  child: const Text('编辑'),
                                ),
                                TextButton(
                                  onPressed: () => _deleteQuestion(question),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _Badge(
                                  label: _questionTypeLabel(
                                    question.questionType,
                                  ),
                                  color: AppColors.brand,
                                ),
                                _Badge(
                                  label: _difficultyLabel(question.difficulty),
                                  color: AppColors.accent,
                                ),
                                _Badge(
                                  label: question.isActive ? '启用中' : '停用中',
                                  color: question.isActive
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                ),
                              ],
                            ),
                            if (question.explanation != null &&
                                question.explanation!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                question.explanation!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            ...question.options.map(
                              (option) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      option.isCorrect
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: option.isCorrect
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        '${option.label}. ${option.content}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Widget _fieldBox(double width, Widget child) {
    return SizedBox(width: width, child: child);
  }
}

class _QuestionEditorDialog extends StatefulWidget {
  const _QuestionEditorDialog({required this.nextSortOrder, this.question});

  final AdminQuizQuestionItem? question;
  final int nextSortOrder;

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  late final TextEditingController _stemController;
  late final TextEditingController _explanationController;
  late final TextEditingController _sortOrderController;
  late QuestionType _questionType;
  late DifficultyLevel _difficulty;
  late bool _isActive;
  late List<_QuestionOptionDraft> _options;

  @override
  void initState() {
    super.initState();
    _stemController = TextEditingController(text: widget.question?.stem ?? '');
    _explanationController = TextEditingController(
      text: widget.question?.explanation ?? '',
    );
    _sortOrderController = TextEditingController(
      text: '${widget.question?.sortOrder ?? widget.nextSortOrder}',
    );
    _questionType = widget.question?.questionType ?? QuestionType.singleChoice;
    _difficulty = widget.question?.difficulty ?? DifficultyLevel.beginner;
    _isActive = widget.question?.isActive ?? true;
    _options = widget.question == null
        ? [_QuestionOptionDraft(), _QuestionOptionDraft()]
        : widget.question!.options
              .map(
                (option) => _QuestionOptionDraft(
                  content: option.content,
                  isCorrect: option.isCorrect,
                ),
              )
              .toList();
  }

  @override
  void dispose() {
    _stemController.dispose();
    _explanationController.dispose();
    _sortOrderController.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  void _setCorrect(int index, bool value) {
    setState(() {
      if (_questionType == QuestionType.singleChoice ||
          _questionType == QuestionType.trueFalse) {
        for (var i = 0; i < _options.length; i++) {
          _options[i].isCorrect = i == index ? value : false;
        }
      } else {
        _options[index].isCorrect = value;
      }
    });
  }

  void _changeQuestionType(QuestionType value) {
    setState(() {
      _questionType = value;
      if (_questionType == QuestionType.singleChoice ||
          _questionType == QuestionType.trueFalse) {
        final firstCorrectIndex = _options.indexWhere((item) => item.isCorrect);
        for (var i = 0; i < _options.length; i++) {
          _options[i].isCorrect =
              i == (firstCorrectIndex >= 0 ? firstCorrectIndex : 0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? '新增题目' : '编辑题目'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _stemController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '题干'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _explanationController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '解析'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<QuestionType>(
                      key: ValueKey('question-type-$_questionType'),
                      initialValue: _questionType,
                      decoration: const InputDecoration(labelText: '题型'),
                      items: const [
                        DropdownMenuItem(
                          value: QuestionType.singleChoice,
                          child: Text('单选题'),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.multipleChoice,
                          child: Text('多选题'),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.trueFalse,
                          child: Text('判断题'),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.imageRecognition,
                          child: Text('图像识别'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        _changeQuestionType(value);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: DropdownButtonFormField<DifficultyLevel>(
                      key: ValueKey('question-difficulty-$_difficulty'),
                      initialValue: _difficulty,
                      decoration: const InputDecoration(labelText: '难度'),
                      items: const [
                        DropdownMenuItem(
                          value: DifficultyLevel.beginner,
                          child: Text('入门'),
                        ),
                        DropdownMenuItem(
                          value: DifficultyLevel.intermediate,
                          child: Text('进阶'),
                        ),
                        DropdownMenuItem(
                          value: DifficultyLevel.advanced,
                          child: Text('高级'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _difficulty = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _sortOrderController,
                      decoration: const InputDecoration(labelText: '排序'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用该题'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Text(
                    '选项',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _options.add(_QuestionOptionDraft());
                      });
                    },
                    child: const Text('新增选项'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ...List.generate(_options.length, (index) {
                final option = _options[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: option.contentController,
                          decoration: const InputDecoration(labelText: '选项内容'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Checkbox(
                        value: option.isCorrect,
                        onChanged: (value) =>
                            _setCorrect(index, value ?? false),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: _options.length <= 2
                            ? null
                            : () {
                                setState(() {
                                  final removed = _options.removeAt(index);
                                  removed.dispose();
                                });
                              },
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final stem = _stemController.text.trim();
            final options = _options
                .where((item) => item.contentController.text.trim().isNotEmpty)
                .toList();
            final correctCount = options.where((item) => item.isCorrect).length;
            final sortOrder = int.tryParse(_sortOrderController.text.trim());
            if (stem.isEmpty || options.length < 2 || correctCount == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请完善题干、至少两个选项，并设置正确答案。')),
              );
              return;
            }
            if (_options.any(
              (item) =>
                  item.contentController.text.trim().isEmpty && item.isCorrect,
            )) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('正确答案对应的选项内容不能为空。')));
              return;
            }
            if (sortOrder == null || sortOrder <= 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('题目排序必须是大于 0 的整数。')));
              return;
            }
            if ((_questionType == QuestionType.singleChoice ||
                    _questionType == QuestionType.trueFalse) &&
                correctCount != 1) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('单选题和判断题必须且只能有一个正确答案。')),
              );
              return;
            }
            Navigator.of(context).pop(
              AdminQuizQuestionUpsertInput(
                stem: stem,
                explanation: _nullIfEmpty(_explanationController.text),
                questionType: _questionType,
                difficulty: _difficulty,
                sortOrder: sortOrder,
                isActive: _isActive,
                options: [
                  for (var i = 0; i < options.length; i++)
                    AdminQuizOptionUpsertInput(
                      label: String.fromCharCode(65 + i),
                      content: options[i].contentController.text.trim(),
                      isCorrect: options[i].isCorrect,
                      sortOrder: i + 1,
                    ),
                ],
              ),
            );
          },
          child: const Text('保存题目'),
        ),
      ],
    );
  }
}

class _QuestionOptionDraft {
  _QuestionOptionDraft({String content = '', this.isCorrect = false})
    : contentController = TextEditingController(text: content);

  final TextEditingController contentController;
  bool isCorrect;

  void dispose() {
    contentController.dispose();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.hint,
  });

  final String title;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: EcgMetricCard(label: title, value: value, supportingText: hint),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EcgBadge(label: label, color: color);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return EcgEmptyState(title: title, message: description);
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _parseListField(String value) {
  return value
      .split(RegExp(r'[\n,，]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

Future<bool> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认'),
        ),
      ],
    ),
  );
  return result ?? false;
}

String _difficultyLabel(DifficultyLevel value) {
  switch (value) {
    case DifficultyLevel.beginner:
      return '入门';
    case DifficultyLevel.intermediate:
      return '进阶';
    case DifficultyLevel.advanced:
      return '高级';
  }
}

String _riskLabel(RiskLevel value) {
  switch (value) {
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

Color _riskColor(RiskLevel value) {
  switch (value) {
    case RiskLevel.low:
      return AppColors.success;
    case RiskLevel.medium:
      return AppColors.warning;
    case RiskLevel.high:
      return const Color(0xFFE56B2E);
    case RiskLevel.critical:
      return AppColors.danger;
  }
}

String _statusLabel(CaseStatus value) {
  switch (value) {
    case CaseStatus.draft:
      return '草稿';
    case CaseStatus.published:
      return '已发布';
    case CaseStatus.offline:
      return '已下线';
  }
}

Color _statusColor(CaseStatus value) {
  switch (value) {
    case CaseStatus.draft:
      return AppColors.warning;
    case CaseStatus.published:
      return AppColors.success;
    case CaseStatus.offline:
      return AppColors.textMuted;
  }
}

String _questionTypeLabel(QuestionType value) {
  switch (value) {
    case QuestionType.singleChoice:
      return '单选题';
    case QuestionType.multipleChoice:
      return '多选题';
    case QuestionType.trueFalse:
      return '判断题';
    case QuestionType.imageRecognition:
      return '图像识别';
  }
}

String _guessMimeType(String fileName) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lowerName.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lowerName.endsWith('.gif')) {
    return 'image/gif';
  }
  return 'image/png';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
