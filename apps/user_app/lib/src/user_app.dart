import 'package:ecg_api/ecg_api.dart';
import 'package:ecg_ui/ecg_ui.dart';
import 'package:flutter/material.dart';

import 'user_repository.dart';

void runUserApp() {
  runApp(const UserApp());
}

class UserApp extends StatefulWidget {
  const UserApp({
    super.key,
    this.repository,
    this.sessionStore,
    this.initialSession,
  });

  final UserRepository? repository;
  final UserSessionStore? sessionStore;
  final UserSession? initialSession;

  @override
  State<UserApp> createState() => _UserAppState();
}

class _UserAppState extends State<UserApp> {
  late final UserRepository _repository =
      widget.repository ??
      ApiUserRepository(
        EcgApiClient(
          baseUrl: const String.fromEnvironment(
            'ECG_API_BASE_URL',
            defaultValue: 'http://localhost:8000',
          ),
        ),
      );
  late final UserSessionStore _sessionStore =
      widget.sessionStore ?? SharedPreferencesUserSessionStore();

  UserSession? _session;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (widget.initialSession != null) {
      setState(() {
        _session = widget.initialSession;
        _restoringSession = false;
      });
      return;
    }

    final restored = await _sessionStore.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = restored;
      _restoringSession = false;
    });
  }

  Future<void> _handleLogin(UserSession session) async {
    await _sessionStore.write(session);
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    await _sessionStore.clear();
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
      title: 'ECG Pro User',
      debugShowCheckedModeBanner: false,
      theme: EcgAppTheme.light(),
      home: _restoringSession
          ? const _UserBootPage()
          : UserHomePage(
              repository: _repository,
              session: _session,
              onLogin: _handleLogin,
              onLogout: _handleLogout,
            ),
    );
  }
}

class _UserBootPage extends StatelessWidget {
  const _UserBootPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text('正在恢复学习会话...'),
          ],
        ),
      ),
    );
  }
}

class UserHomePage extends StatefulWidget {
  const UserHomePage({
    super.key,
    required this.repository,
    required this.session,
    required this.onLogin,
    required this.onLogout,
  });

  final UserRepository repository;
  final UserSession? session;
  final ValueChanged<UserSession> onLogin;
  final Future<void> Function() onLogout;

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final TextEditingController _searchController = TextEditingController();

  List<CategoryItem> _categories = const [];
  PublicCaseListResponse? _caseResponse;
  List<LearningProgressItem> _progressItems = const [];
  List<FavoriteItem> _favorites = const [];
  List<WrongQuestionItem> _wrongQuestions = const [];
  String? _selectedCategoryId;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant UserHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.accessToken != widget.session?.accessToken) {
      _loadInitialData();
    }
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
      List<LearningProgressItem> progress = const [];
      List<FavoriteItem> favorites = const [];
      List<WrongQuestionItem> wrongQuestions = const [];
      if (widget.session != null) {
        progress = await widget.repository.fetchLearningProgress(
          widget.session!,
        );
        favorites = await widget.repository.fetchFavorites(widget.session!);
        wrongQuestions = await widget.repository.fetchWrongQuestions(
          widget.session!,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _caseResponse = cases;
        _progressItems = progress;
        _favorites = favorites;
        _wrongQuestions = wrongQuestions;
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

  Future<void> _openLoginDialog() async {
    final session = await showDialog<UserSession>(
      context: context,
      builder: (context) => _UserLoginDialog(repository: widget.repository),
    );
    if (session == null) {
      return;
    }
    widget.onLogin(session);
  }

  Future<void> _openCaseDetail(String caseId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CaseDetailPage(
          repository: widget.repository,
          session: widget.session,
          caseId: caseId,
        ),
      ),
    );
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return EcgScaffold(
      title: 'ECG Pro 学习端',
      subtitle: '围绕真实心电图案例进行系统学习，先看图，再判断，再回顾诊断与临床处理。',
      actions: [
        IconButton(
          tooltip: '刷新案例',
          onPressed: _loading ? null : _loadInitialData,
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (session == null)
          FilledButton.tonalIcon(
            onPressed: _openLoginDialog,
            icon: const Icon(Icons.person_rounded),
            label: const Text('登录学习'),
          )
        else ...[
          Chip(
            avatar: const Icon(Icons.verified_user_rounded, size: 18),
            label: Text(session.user.displayName),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: widget.onLogout, child: const Text('退出')),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LearningHero(session: session),
          const SizedBox(height: AppSpacing.xl),
          _LearningOverviewSection(
            session: session,
            progressItems: _progressItems,
            favorites: _favorites,
            wrongQuestions: _wrongQuestions,
            onLoginPressed: _openLoginDialog,
            onOpenCase: _openCaseDetail,
          ),
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
      return _InlineMessage(message: _errorMessage!);
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
                isFavorite: _favorites.any(
                  (favorite) => favorite.caseId == item.id,
                ),
                onTap: () => _openCaseDetail(item.id),
              ),
            ),
          )
          .toList(),
    );
  }
}

class CaseDetailPage extends StatefulWidget {
  const CaseDetailPage({
    super.key,
    required this.repository,
    required this.session,
    required this.caseId,
  });

  final UserRepository repository;
  final UserSession? session;
  final String caseId;

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  CaseDetailItem? _detail;
  List<PublicQuizQuestionItem> _quizQuestions = const [];
  bool _isFavorite = false;
  bool _loading = true;
  bool _favoriteLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final detail = await widget.repository.fetchCaseDetail(widget.caseId);
      final quizQuestions = await widget.repository.fetchQuizQuestions(
        widget.caseId,
      );
      var isFavorite = false;
      if (widget.session != null) {
        await widget.repository.markCaseViewed(widget.session!, widget.caseId);
        final favorites = await widget.repository.fetchFavorites(
          widget.session!,
        );
        isFavorite = favorites.any(
          (favorite) => favorite.caseId == widget.caseId,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _quizQuestions = quizQuestions;
        _isFavorite = isFavorite;
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
        _errorMessage = '案例详情加载失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final session = widget.session;
    if (session == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录后可收藏案例并同步学习记录。')));
      return;
    }

    setState(() {
      _favoriteLoading = true;
    });

    try {
      if (_isFavorite) {
        await widget.repository.removeFavorite(session, widget.caseId);
      } else {
        await widget.repository.addFavorite(session, widget.caseId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite = !_isFavorite;
      });
    } on EcgApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _favoriteLoading = false;
        });
      }
    }
  }

  Future<void> _startQuiz() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    if (widget.session == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录后可提交测验并记录成绩。')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => QuizPage(
          repository: widget.repository,
          session: widget.session!,
          detail: detail,
          questions: _quizQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('案例详情'),
        actions: [
          IconButton(
            tooltip: _isFavorite ? '取消收藏' : '收藏案例',
            onPressed: _favoriteLoading ? null : _toggleFavorite,
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 120),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _errorMessage != null
                ? _InlineMessage(message: _errorMessage!)
                : _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final detail = _detail!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                detail.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail.diagnosis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (detail.summary != null && detail.summary!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  detail.summary!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  FilledButton.icon(
                    onPressed: _quizQuestions.isEmpty ? null : _startQuiz,
                    icon: const Icon(Icons.quiz_rounded),
                    label: Text(
                      _quizQuestions.isEmpty
                          ? '暂无测验'
                          : '开始测验 (${_quizQuestions.length} 题)',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    label: Text(_isFavorite ? '已收藏' : '收藏案例'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (detail.images.isNotEmpty) ...[
          _ImageStrip(images: detail.images),
          const SizedBox(height: AppSpacing.xl),
        ],
        _DetailGrid(detail: detail),
        if (detail.detailedDescription != null &&
            detail.detailedDescription!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _DetailBlock(title: '详细描述', content: detail.detailedDescription!),
        ],
        if (detail.treatmentPlan != null &&
            detail.treatmentPlan!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _DetailBlock(title: '治疗方案', content: detail.treatmentPlan!),
        ],
        if (detail.learningPoints.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _BulletBlock(title: '学习要点', items: detail.learningPoints),
        ],
        if (detail.interpretationSteps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _BulletBlock(title: '判读步骤', items: detail.interpretationSteps),
        ],
        if (detail.memoryTips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _BulletBlock(title: '记忆提示', items: detail.memoryTips),
        ],
      ],
    );
  }
}

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.repository,
    required this.session,
    required this.detail,
    required this.questions,
  });

  final UserRepository repository;
  final UserSession session;
  final CaseDetailItem detail;
  final List<PublicQuizQuestionItem> questions;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final Map<String, Set<String>> _selectedAnswers = {};
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
    });
    try {
      final result = await widget.repository.submitQuiz(
        widget.session,
        QuizSubmissionInput(
          caseId: widget.detail.id,
          answers: widget.questions
              .map(
                (question) => QuizAnswerSubmissionInput(
                  questionId: question.id,
                  selectedOptionIds:
                      _selectedAnswers[question.id]?.toList() ?? const [],
                ),
              )
              .toList(),
        ),
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => QuizResultPage(
            detail: widget.detail,
            questions: widget.questions,
            result: result,
          ),
        ),
      );
    } on EcgApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _toggleOption(
    PublicQuizQuestionItem question,
    PublicQuizOptionItem option,
    bool selected,
  ) {
    final current = {...?_selectedAnswers[question.id]};
    if (question.questionType == QuestionType.multipleChoice) {
      if (selected) {
        current.add(option.id);
      } else {
        current.remove(option.id);
      }
    } else {
      current
        ..clear()
        ..add(option.id);
    }
    setState(() {
      _selectedAnswers[question.id] = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('案例测验')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              widget.detail.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '共 ${widget.questions.length} 题，提交后将记录本次成绩与错题。',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final question in widget.questions) ...[
              _QuizQuestionCard(
                question: question,
                selectedOptionIds: _selectedAnswers[question.id] ?? const {},
                onOptionChanged: (option, selected) =>
                    _toggleOption(question, option, selected),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(_submitting ? '提交中...' : '提交测验'),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizResultPage extends StatelessWidget {
  const QuizResultPage({
    super.key,
    required this.detail,
    required this.questions,
    required this.result,
  });

  final CaseDetailItem detail;
  final List<PublicQuizQuestionItem> questions;
  final QuizSubmissionResponse result;

  @override
  Widget build(BuildContext context) {
    final questionMap = {
      for (final question in questions) question.id: question,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('测验结果')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      _MetricCard(label: '本次得分', value: '${result.score}'),
                      _MetricCard(
                        label: '答对题数',
                        value:
                            '${result.correctCount}/${result.totalQuestions}',
                      ),
                      _MetricCard(
                        label: '提交结果',
                        value: result.correctCount == result.totalQuestions
                            ? '全部正确'
                            : '继续复习',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              '逐题解析',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final item in result.items) ...[
              _QuizResultCard(
                question: questionMap[item.questionId],
                resultItem: item,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserLoginDialog extends StatefulWidget {
  const _UserLoginDialog({required this.repository});

  final UserRepository repository;

  @override
  State<_UserLoginDialog> createState() => _UserLoginDialogState();
}

class _UserLoginDialogState extends State<_UserLoginDialog> {
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
      Navigator.of(context).pop(session);
    } on EcgApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = '登录失败，请检查账号和接口服务。';
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
    return AlertDialog(
      title: const Text('登录学习账户'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '用户名'),
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
                decoration: const InputDecoration(labelText: '密码'),
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
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '登录中...' : '登录'),
        ),
      ],
    );
  }
}

class _LearningHero extends StatelessWidget {
  const _LearningHero({required this.session});

  final UserSession? session;

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
                  child: Text(session == null ? '游客模式可浏览' : '已登录学习模式'),
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
                  '每个案例都整理了图像、诊断、关键导联、临床意义、风险等级、处理建议和记忆提示，登录后还能同步学习进度、收藏和测验成绩。',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 300,
            child: Column(
              children: const [
                _StatTile(title: '学习路径', value: '看图 -> 判读 -> 测验'),
                SizedBox(height: AppSpacing.lg),
                _StatTile(title: '案例结构', value: '图像 + 诊断 + 临床建议'),
                SizedBox(height: AppSpacing.lg),
                _StatTile(title: '终端支持', value: 'Web 与 Android 同步体验'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningOverviewSection extends StatelessWidget {
  const _LearningOverviewSection({
    required this.session,
    required this.progressItems,
    required this.favorites,
    required this.wrongQuestions,
    required this.onLoginPressed,
    required this.onOpenCase,
  });

  final UserSession? session;
  final List<LearningProgressItem> progressItems;
  final List<FavoriteItem> favorites;
  final List<WrongQuestionItem> wrongQuestions;
  final VoidCallback onLoginPressed;
  final ValueChanged<String> onOpenCase;

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return EcgSectionCard(
        title: '学习进度',
        subtitle: '登录后可记录浏览、收藏、错题和测验成绩。',
        trailing: FilledButton.tonal(
          onPressed: onLoginPressed,
          child: const Text('登录学习'),
        ),
        child: const Text('当前处于游客模式，你可以先浏览案例，准备好后再登录开始记录进度。'),
      );
    }

    final completedCount = progressItems
        .where((item) => item.status == LearningStatus.completed)
        .length;
    final bestScore = progressItems.isEmpty
        ? 0
        : progressItems
              .map((item) => item.bestScore)
              .reduce((value, element) => value > element ? value : element);

    return EcgSectionCard(
      title: '学习进度',
      subtitle: '已同步你的学习记录，可继续回顾已看案例并针对错题复习。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              _MetricCard(label: '已开始案例', value: '${progressItems.length}'),
              _MetricCard(label: '已完成案例', value: '$completedCount'),
              _MetricCard(label: '已收藏', value: '${favorites.length}'),
              _MetricCard(label: '错题数', value: '${wrongQuestions.length}'),
              _MetricCard(label: '最佳成绩', value: '$bestScore'),
            ],
          ),
          if (progressItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              '继续学习',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: progressItems
                  .take(3)
                  .map(
                    (item) => _ActionCard(
                      title: item.title,
                      subtitle:
                          '${item.diagnosis} · 完成度 ${item.completionRate}%',
                      buttonLabel: '继续学习',
                      onPressed: () => onOpenCase(item.caseId),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (wrongQuestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              '错题复习',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: wrongQuestions
                  .take(2)
                  .map(
                    (item) => _ActionCard(
                      title: item.caseTitle,
                      subtitle: '${item.stem} · 错误 ${item.wrongCount} 次',
                      buttonLabel: '复习案例',
                      onPressed: () => onOpenCase(item.caseId),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
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
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonal(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
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
  const _CaseSummaryCard({
    required this.item,
    required this.isFavorite,
    required this.onTap,
  });

  final PublicCaseListItem item;
  final bool isFavorite;
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
                if (isFavorite)
                  const _Badge(text: '已收藏', color: AppColors.danger),
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
                const Text('进入案例'),
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

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.question,
    required this.selectedOptionIds,
    required this.onOptionChanged,
  });

  final PublicQuizQuestionItem question;
  final Set<String> selectedOptionIds;
  final void Function(PublicQuizOptionItem option, bool selected)
  onOptionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第 ${question.sortOrder + 1} 题',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            question.stem,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: CheckboxListTile(
                value: selectedOptionIds.contains(option.id),
                onChanged: (selected) =>
                    onOptionChanged(option, selected ?? false),
                title: Text('${option.label}. ${option.content}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizResultCard extends StatelessWidget {
  const _QuizResultCard({required this.question, required this.resultItem});

  final PublicQuizQuestionItem? question;
  final QuizSubmissionResultItem resultItem;

  @override
  Widget build(BuildContext context) {
    final optionMap = {
      for (final option in question?.options ?? const <PublicQuizOptionItem>[])
        option.id: option,
    };
    final selectedLabels = resultItem.selectedOptionIds
        .map((id) => optionMap[id]?.label ?? id)
        .join('、');
    final correctLabels = resultItem.correctOptionIds
        .map((id) => optionMap[id]?.label ?? id)
        .join('、');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: resultItem.isCorrect ? AppColors.success : AppColors.warning,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question?.stem ?? '题目 ${resultItem.questionId}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _Badge(
                text: resultItem.isCorrect ? '回答正确' : '需要复习',
                color: resultItem.isCorrect
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '你的答案：${selectedLabels.isEmpty ? '未作答' : selectedLabels}',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '正确答案：$correctLabels',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          if (resultItem.explanation != null &&
              resultItem.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              resultItem.explanation!,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: Text(message)),
        ],
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
