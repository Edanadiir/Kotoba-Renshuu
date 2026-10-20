import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/models/assignment.dart';
import 'core/models/quiz_item.dart';
import 'core/models/subject.dart';
import 'core/models/user.dart';
import 'features/conjugation/presentation/conjugation_setup_screen.dart';
import 'features/onomatopoeia/presentation/onomatopoeia_screen.dart';
import 'features/particles/presentation/particle_quiz_screen.dart';
import 'features/transitivity/domain/learned_pairs.dart';
import 'features/transitivity/presentation/transitivity_screen.dart';
import 'features/quiz/domain/answer_matcher.dart';
import 'features/quiz/domain/quiz_config.dart';
import 'features/quiz/domain/quiz_engine.dart';
import 'features/quiz/presentation/kana_input_controller.dart';
import 'features/quiz/presentation/item_spread_card.dart';
import 'features/quiz/presentation/matching_card.dart';
import 'features/sync/data/wanikani_api_client.dart';
import 'shared/services/local_cache.dart';
import 'shared/services/audio_cache.dart';
import 'shared/services/audio_playback.dart';
import 'shared/services/secure_token_store.dart';
import 'shared/services/storage_usage.dart';

const _ink = Color(0xFF16212B);
const _paper = Color(0xFFF5F7F8);
const _muted = Color(0xFF73808A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(const ProviderScope(child: WaniKaniReviewerApp()));
}

class WaniKaniReviewerApp extends StatelessWidget {
  const WaniKaniReviewerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Wanikani Renshuu',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00AAFF)),
      fontFamily: 'Trebuchet MS',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const ReviewerShell(),
  );
}

class ReviewerShell extends StatefulWidget {
  const ReviewerShell({super.key});

  @override
  State<ReviewerShell> createState() => _ReviewerShellState();
}

class _ReviewerShellState extends State<ReviewerShell> {
  final controller = ReviewerController();

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
    controller.initialize();
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    unawaited(disposeAudioPlayback());
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final isAndroid = compact;
    final content = switch (controller.screen) {
      ReviewerScreen.dashboard => DashboardScreen(controller: controller),
      ReviewerScreen.setup => SetupScreen(controller: controller),
      ReviewerScreen.quiz => QuizScreen(
        controller: controller,
        config: controller.quizConfig,
      ),
      ReviewerScreen.summary => SummaryScreen(controller: controller),
      ReviewerScreen.settings => SettingsScreen(controller: controller),
      ReviewerScreen.conjugation => const ConjugationScreen(),
      ReviewerScreen.transitivity => TransitivityScreen(
        learnedWords:
            controller.subjects.isEmpty || controller.assignments.isEmpty
            ? null
            : learnedVocabulary(controller.subjects, controller.assignments),
      ),
      ReviewerScreen.particles => const ParticleQuizScreen(),
      ReviewerScreen.onomatopoeia => const OnomatopoeiaScreen(),
    };
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: compact
          ? AppBar(
              title: Text(
                _navDestinations[controller.navigationIndex.clamp(
                      0,
                      _navDestinations.length - 1,
                    )]
                    .label,
              ),
            )
          : null,
      body: SafeArea(
        child: isAndroid
            ? content
            : Row(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              extended: false,
                              groupAlignment: -0.8,
                              selectedIndex: controller.navigationIndex,
                              onDestinationSelected: controller.isSyncing
                                  ? null
                                  : (index) => _handleNavigation(index),
                              labelType: NavigationRailLabelType.all,
                              backgroundColor: _ink,
                              leading: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 22),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              destinations: const [
                                NavigationRailDestination(
                                  icon: Icon(Icons.dashboard_outlined),
                                  selectedIcon: Icon(Icons.dashboard),
                                  label: Text('Home'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.keyboard_alt_outlined),
                                  selectedIcon: Icon(Icons.keyboard_alt),
                                  label: Text('Typing'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.grid_view_outlined),
                                  selectedIcon: Icon(Icons.grid_view),
                                  label: Text('Choice'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.compare_arrows_outlined),
                                  selectedIcon: Icon(Icons.compare_arrows),
                                  label: Text('Matching'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.short_text_rounded),
                                  selectedIcon: Icon(Icons.short_text_rounded),
                                  label: Text('Context'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.transform_outlined),
                                  selectedIcon: Icon(Icons.transform),
                                  label: Text('Conjugation'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.swap_horiz_rounded),
                                  selectedIcon: Icon(Icons.swap_horiz_rounded),
                                  label: Text('Transitivity'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.spellcheck_outlined),
                                  selectedIcon: Icon(Icons.spellcheck),
                                  label: Text('Particles'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.record_voice_over_outlined),
                                  selectedIcon: Icon(Icons.record_voice_over),
                                  label: Text('Onomatopoeia'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.settings_outlined),
                                  selectedIcon: Icon(Icons.settings),
                                  label: Text('Settings'),
                                ),
                              ],
                              selectedIconTheme: const IconThemeData(
                                color: Colors.white,
                              ),
                              unselectedIconTheme: const IconThemeData(
                                color: Color(0xFF91A0AA),
                              ),
                              selectedLabelTextStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                              unselectedLabelTextStyle: const TextStyle(
                                color: Color(0xFF91A0AA),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
      ),
      drawer: compact
          ? NavigationDrawer(
              selectedIndex: controller.navigationIndex,
              onDestinationSelected: (index) {
                if (controller.isSyncing) return;
                Navigator.of(context).pop();
                _handleNavigation(index);
              },
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 20, 16, 10),
                  child: Text(
                    'WaniKani Reviewer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final d in _navDestinations)
                  NavigationDrawerDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            )
          : null,
    );
  }

  Future<void> _handleNavigation(int index) async {
    if (!controller.isQuizActive) {
      controller.navigate(index);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave current quiz?'),
        content: const Text('You can save your progress or discard it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard & Leave'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save & Leave'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return;
    if (choice == 'save') {
      await controller.saveAndExit();
    } else {
      await controller.exitQuiz();
    }
    if (mounted) controller.navigate(index);
  }
}

class _NavDestination {
  const _NavDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _navDestinations = [
  _NavDestination('Home', Icons.dashboard_outlined, Icons.dashboard),
  _NavDestination('Typing', Icons.keyboard_alt_outlined, Icons.keyboard_alt),
  _NavDestination('Choice', Icons.grid_view_outlined, Icons.grid_view),
  _NavDestination(
    'Matching',
    Icons.compare_arrows_outlined,
    Icons.compare_arrows,
  ),
  _NavDestination(
    'Context',
    Icons.short_text_rounded,
    Icons.short_text_rounded,
  ),
  _NavDestination('Conjugation', Icons.transform_outlined, Icons.transform),
  _NavDestination(
    'Transitivity',
    Icons.swap_horiz_rounded,
    Icons.swap_horiz_rounded,
  ),
  _NavDestination('Particles', Icons.spellcheck_outlined, Icons.spellcheck),
  _NavDestination(
    'Onomatopoeia',
    Icons.record_voice_over_outlined,
    Icons.record_voice_over,
  ),
  _NavDestination('Settings', Icons.settings_outlined, Icons.settings),
];

enum ReviewerScreen {
  dashboard,
  setup,
  quiz,
  summary,
  settings,
  conjugation,
  transitivity,
  particles,
  onomatopoeia,
}

enum StudyMode { typing, multipleChoice, matching, context }

enum QuestionScope { both, meaning, reading }

class ReviewerController extends ChangeNotifier {
  ReviewerController({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<Subject> subjects = [];
  final List<Assignment> assignments = [];
  final LocalCache _cache = LocalCache();
  ReviewerScreen screen = ReviewerScreen.dashboard;
  int navigationIndex = 0;
  StudyMode studyMode = StudyMode.typing;
  QuestionScope scope = QuestionScope.both;
  QuestionScope matchingPairType = QuestionScope.meaning;
  final Map<StudyMode, int> sessionSizes = {
    for (final mode in StudyMode.values) mode: 10,
  };
  RangeValues levels = const RangeValues(1, 1);
  Set<SrsStage> stages = SrsStage.values.toSet();
  Set<SubjectType> subjectTypes = SubjectType.values.toSet();
  bool showSuccessDetails = true;
  bool revealOnSecondMistake = true;
  bool multipleChoiceElimination = false;
  bool revealCorrectOnMiss = true;
  bool contextElimination = false;
  bool contextRevealOnMiss = true;
  bool showEnglishByDefault = false;
  bool audioAutoplay = false;
  QuizConfig quizConfig = const QuizConfig();
  String preferredVoice = 'female';
  WaniKaniUser? user;
  QuizEngine? engine;
  List<QuizItem> quizItems = const [];
  List<Subject> quizPool = const [];
  String? token;
  bool isSyncing = false;
  double syncProgress = 0;
  String syncStatus = 'No local WaniKani data yet.';
  DateTime? get lastSync => _cache.lastSync;
  Object? syncError;
  bool isQuizActive = false;
  bool savedSessionAvailable = false;

  int get maxUnlockedSubjectLevel => subjects.isEmpty
      ? 1
      : subjects.map((item) => item.level).reduce((a, b) => a > b ? a : b);

  int get userLevel => user?.level ?? 1;
  int get sessionSize {
    final maximum = availableItemCount;
    return maximum == 0 ? 0 : (sessionSizes[studyMode] ?? 10).clamp(1, maximum);
  }

  int get availableItemCount {
    final pool = filteredSubjects(studyMode);
    if (studyMode == StudyMode.typing && scope == QuestionScope.both) {
      return pool.length;
    }
    return QuizEngine.buildItems(
      pool,
      includeMeanings: studyMode == StudyMode.matching
          ? matchingPairType != QuestionScope.reading
          : studyMode == StudyMode.context || scope != QuestionScope.reading,
      includeReadings: studyMode == StudyMode.matching
          ? matchingPairType == QuestionScope.reading
          : studyMode != StudyMode.context && scope != QuestionScope.meaning,
      separateKanjiReadingTypes: studyMode == StudyMode.typing,
    ).length;
  }

  double get progress =>
      quizItems.isEmpty ? 0 : (engine?.completedItems ?? 0) / quizItems.length;
  double get accuracy => engine?.accuracy ?? 0;
  QuizItem? get currentItem => engine?.current;
  List<QuizItem> get matchingItems {
    final byId = {for (final item in quizItems) item.id: item};
    return (engine?.remainingIds ?? const <String>[])
        .take(5)
        .map((id) => byId[id])
        .whereType<QuizItem>()
        .toList();
  }

  bool get hasSavedSession => savedSessionAvailable;

  Map<SrsStage, Map<SubjectType, int>> get itemSpread => stats.spread;

  DashboardStats? _stats;

  /// Computed once per data change (single pass) and reused by build().
  DashboardStats get stats {
    final cached = _stats;
    if (cached != null && (!_statsDirty || isSyncing)) return cached;
    _statsDirty = false;
    return _stats = DashboardStats.compute(subjects, assignments);
  }

  bool _statsDirty = true;

  @override
  void notifyListeners() {
    if (!isSyncing) _statsDirty = true;
    super.notifyListeners();
  }

  Future<void> initialize() async {
    await _cache.initialize();
    token = await const SecureTokenStore().read();
    preferredVoice = _cache.readPreferredVoice();
    user = _cache.readUser();
    final loadedSubjects = await _cache.readSubjectsAsync();
    final loadedAssignments = await _cache.readAssignmentsAsync();
    subjects
      ..clear()
      ..addAll(loadedSubjects);
    assignments
      ..clear()
      ..addAll(loadedAssignments);
    levels = RangeValues(1, userLevel.toDouble());
    savedSessionAvailable = _cache.readQuizSession() != null;
    syncStatus = subjects.isEmpty
        ? 'Sync your WaniKani account to begin.'
        : 'Loaded local WaniKani data.';
    notifyListeners();
  }

  void navigate(int index) {
    navigationIndex = index;
    if (index >= 1 && index <= StudyMode.values.length) {
      studyMode = StudyMode.values[index - 1];
      screen = ReviewerScreen.setup;
    } else {
      screen = switch (index) {
        5 => ReviewerScreen.conjugation,
        6 => ReviewerScreen.transitivity,
        7 => ReviewerScreen.particles,
        8 => ReviewerScreen.onomatopoeia,
        9 => ReviewerScreen.settings,
        _ => ReviewerScreen.dashboard,
      };
    }
    notifyListeners();
  }

  List<Subject> filteredSubjects(StudyMode mode) {
    final assignmentsBySubject = {
      for (final assignment in assignments) assignment.subjectId: assignment,
    };
    return subjects.where((subject) {
      final assignment = assignmentsBySubject[subject.id];
      if (assignment == null) return false;
      if (mode == StudyMode.context &&
          (subject.type != SubjectType.vocabulary ||
              subject.contextSentences.isEmpty)) {
        return false;
      }
      final isReadingOnly =
          mode == StudyMode.typing && scope == QuestionScope.reading;
      final typeIsAllowed =
          subjectTypes.contains(subject.type) &&
          !(isReadingOnly && subject.type == SubjectType.radical);
      return subject.level >= levels.start &&
          subject.level <= levels.end &&
          typeIsAllowed &&
          stages.contains(assignment.srsStage);
    }).toList();
  }

  void setSessionSize(int value) {
    final maximum = availableItemCount;
    sessionSizes[studyMode] = maximum == 0 ? 0 : value.clamp(1, maximum);
    notifyListeners();
  }

  void startQuiz() {
    final available = availableItemCount;
    if (available == 0) {
      quizPool = const [];
      quizItems = const [];
      engine = null;
      isQuizActive = false;
      notifyListeners();
      return;
    }
    quizConfig = QuizConfig(
      revealOnSecondMiss: revealOnSecondMistake,
      showOther: showSuccessDetails,
      showEnglishByDefault: showEnglishByDefault,
    );
    quizPool = filteredSubjects(studyMode)..shuffle(_random);
    final selectedPool =
        studyMode == StudyMode.typing && scope == QuestionScope.both
        ? quizPool.take(sessionSize).toList()
        : quizPool;
    quizItems = QuizEngine.buildItems(
      selectedPool,
      includeMeanings: studyMode == StudyMode.matching
          ? matchingPairType != QuestionScope.reading
          : studyMode == StudyMode.context || scope != QuestionScope.reading,
      includeReadings: studyMode == StudyMode.matching
          ? matchingPairType == QuestionScope.reading
          : studyMode != StudyMode.context && scope != QuestionScope.meaning,
      separateKanjiReadingTypes: studyMode == StudyMode.typing,
      limit: studyMode == StudyMode.typing && scope == QuestionScope.both
          ? null
          : sessionSize.clamp(1, available),
    );
    engine = QuizEngine(quizItems, config: quizConfig);
    isQuizActive = true;
    screen = ReviewerScreen.quiz;
    notifyListeners();
  }

  void answer(bool correct, {String? wrongAnswer}) {
    if (correct) {
      engine?.completeCurrent();
    } else {
      engine?.recordWrongAnswer(wrongAnswer ?? '');
    }
    if (engine?.current == null) {
      isQuizActive = false;
      screen = ReviewerScreen.summary;
    }
    notifyListeners();
  }

  void failTypingAndRecycle(String answer) {
    engine?.failAndRecycleCurrent(answer);
    notifyListeners();
  }

  void recordRevealedChoiceMiss(String answer) {
    engine?.recordWrongAnswer(answer);
    notifyListeners();
  }

  void answerMultipleChoice(bool correct, {bool disableIncorrect = false}) {
    if (!correct && disableIncorrect) {
      engine?.recordMistake();
    } else {
      engine?.submitAndRecycle(correct);
    }
    if (engine?.current == null) {
      isQuizActive = false;
      screen = ReviewerScreen.summary;
    }
    notifyListeners();
  }

  /// Missed Multiple Choice cards only return to the queue when the answer
  /// was never shown to the learner.
  bool get multipleChoiceRequeues =>
      !multipleChoiceElimination && !revealCorrectOnMiss;

  bool get contextRequeues => !contextElimination && !contextRevealOnMiss;

  void answerChoice(String answer, bool correct, {bool requeueOnMiss = true}) {
    if (correct) {
      engine?.submitAndRecycle(true);
    } else {
      engine?.recordWrongAnswer(answer);
      if (requeueOnMiss) {
        engine?.submitAndRecycle(false);
      } else {
        engine?.completeCurrent();
      }
    }
    if (engine?.current == null) {
      isQuizActive = false;
      screen = ReviewerScreen.summary;
    }
    notifyListeners();
  }

  void nextAfterFeedback(bool correct) {
    if (correct) {
      engine?.completeCurrent();
    } else {
      engine?.submitAndRecycle(false);
    }
    if (engine?.current == null) {
      isQuizActive = false;
      screen = ReviewerScreen.summary;
    }
    notifyListeners();
  }

  Future<void> saveAndExit() async {
    final currentEngine = engine;
    if (currentEngine == null) return;
    await _cache.saveQuizSession({
      'study_mode': studyMode.name,
      'scope': scope.name,
      'session_size': sessionSize,
      'all_ids': quizItems.map((item) => item.id).toList(),
      'remaining_ids': currentEngine.remainingIds,
      'completed_ids': currentEngine.completedIds.toList(),
      'missed_ids': currentEngine.missedIds.toList(),
      'first_attempt_correct_ids': currentEngine.firstAttemptCorrectIds
          .toList(),
      'wrong_answers': currentEngine.wrongAnswersSnapshot,
      'incorrect_attempts': currentEngine.incorrectAttemptsSnapshot,
      'quiz_config': quizConfig.toJson(),
    });
    savedSessionAvailable = true;
    isQuizActive = false;
    screen = ReviewerScreen.dashboard;
    navigationIndex = 0;
    notifyListeners();
  }

  Future<void> exitQuiz() async {
    isQuizActive = false;
    engine = null;
    quizItems = const [];
    quizPool = const [];
    screen = ReviewerScreen.dashboard;
    navigationIndex = 0;
    notifyListeners();
  }

  Future<void> resumeSavedSession() async {
    final saved = _cache.readQuizSession();
    if (saved == null) return;
    final byId = {for (final subject in subjects) subject.id: subject};
    final allItems = <QuizItem>[];
    final allIds =
        (saved['all_ids'] as List<dynamic>? ??
                saved['remaining_ids'] as List<dynamic>? ??
                [])
            .map((id) => id.toString());
    final itemKinds = <String, QuestionKind>{};
    for (final subject in subjects) {
      itemKinds['${subject.id}:meaning'] = QuestionKind.meaning;
      itemKinds['${subject.id}:reading'] = QuestionKind.reading;
      if (subject.hasTypedReadings) {
        itemKinds['${subject.id}:onyomi'] = QuestionKind.onyomi;
        itemKinds['${subject.id}:kunyomi'] = QuestionKind.kunyomi;
      }
    }
    for (final id in allIds) {
      final parts = id.split(':');
      final subject = int.tryParse(parts.first) == null
          ? null
          : byId[int.parse(parts.first)];
      final kind = itemKinds[id];
      if (subject != null && kind != null) {
        allItems.add(QuizItem(id: id, subject: subject, kind: kind));
      }
    }
    if (allItems.isEmpty) return;
    final byItemId = {for (final item in allItems) item.id: item};
    final remainingItems = ((saved['remaining_ids'] as List<dynamic>? ?? [])
        .map((id) => byItemId[id.toString()])
        .whereType<QuizItem>()
        .toList());
    quizItems = allItems;
    final assignedSubjectIds = assignments
        .map((assignment) => assignment.subjectId)
        .toSet();
    quizPool = subjects
        .where((subject) => assignedSubjectIds.contains(subject.id))
        .toList();
    studyMode = StudyMode.values.byName(
      saved['study_mode']?.toString() ?? StudyMode.typing.name,
    );
    final savedConfig = saved['quiz_config'];
    quizConfig = QuizConfig.fromJson(
      savedConfig is Map ? Map<String, dynamic>.from(savedConfig) : null,
    );
    engine = QuizEngine.restore(
      queue: remainingItems,
      completed: _stringSet(saved['completed_ids']),
      missed: _stringSet(saved['missed_ids']),
      firstAttemptCorrect: _stringSet(saved['first_attempt_correct_ids']),
      wrongAnswers: _wrongAnswersMap(saved['wrong_answers']),
      incorrectAttempts: _intMap(saved['incorrect_attempts']),
      config: quizConfig,
    );
    isQuizActive = true;
    screen = ReviewerScreen.quiz;
    await _cache.clearQuizSession();
    savedSessionAvailable = false;
    notifyListeners();
  }

  Set<String> _stringSet(dynamic value) =>
      (value is List ? value : const []).map((item) => item.toString()).toSet();

  Map<String, Set<String>> _wrongAnswersMap(dynamic value) {
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): _stringSet(entry.value),
    };
  }

  Map<String, int> _intMap(dynamic value) {
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): int.tryParse(entry.value.toString()) ?? 0,
    };
  }

  void answerMany(int count) {
    for (var index = 0; index < count && engine?.current != null; index++) {
      engine?.completeCurrent();
    }
    if (engine?.current == null) {
      isQuizActive = false;
      screen = ReviewerScreen.summary;
    }
    notifyListeners();
  }

  void retryMissed() {
    final ids = engine?.missedIds ?? {};
    final items = quizItems.where((item) => ids.contains(item.id)).toList();
    if (items.isEmpty) return;
    quizItems = items;
    engine = QuizEngine(items);
    screen = ReviewerScreen.quiz;
    notifyListeners();
  }

  void selectMode(StudyMode mode) {
    studyMode = mode;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  Future<void> setPreferredVoice(String voice) async {
    preferredVoice = voice;
    await _cache.savePreferredVoice(voice);
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    await _cache.clearLocalData();
    await clearCachedAudioFiles();
    subjects.clear();
    assignments.clear();
    user = null;
    levels = const RangeValues(1, 1);
    savedSessionAvailable = false;
    syncStatus = 'Local WaniKani data cleared.';
    notifyListeners();
  }

  Future<void> saveToken(String value) async {
    token = value.trim();
    if (token!.isNotEmpty) {
      await const SecureTokenStore().write(token!);
      await sync();
    }
    notifyListeners();
  }

  Future<void> sync() async {
    final savedToken = token ?? await const SecureTokenStore().read();
    if (savedToken == null || savedToken.isEmpty) {
      syncError = 'Enter a WaniKani API token before syncing.';
      syncStatus = syncError.toString();
      notifyListeners();
      return;
    }
    isSyncing = true;
    syncProgress = 0;
    syncError = null;
    syncStatus = 'Fetching subjects...';
    notifyListeners();
    try {
      final api = WaniKaniApiClient(token: savedToken);
      syncProgress = 0.05;
      syncStatus = 'Validating token...';
      notifyListeners();
      user = await api.validateToken();
      await _cache.saveUser(user!);
      syncProgress = 0.15;
      levels = RangeValues(1, user!.level.toDouble());
      syncStatus = 'Connected as: ${user!.username} (level ${user!.level})';
      notifyListeners();
      final fetchedSubjects = await api.fetchSubjects(
        onPage: (page) {
          syncProgress = (0.15 + page * 0.08).clamp(0.15, 0.5);
          syncStatus = 'Fetching subjects (page $page)...';
          notifyListeners();
        },
      );
      for (final subject in fetchedSubjects.where(
        (item) => item.type == SubjectType.vocabulary,
      )) {
        print(
          'Audio URLs found for subject ${subject.characters}:${subject.pronunciationAudios.length}',
        );
      }
      syncProgress = 0.55;
      syncStatus = 'Fetching user progress...';
      notifyListeners();
      final fetchedAssignments = await api.fetchAssignments(
        onPage: (page) {
          syncProgress = (0.55 + page * 0.08).clamp(0.55, 0.78);
          syncStatus = 'Fetching assignments (page $page)...';
          notifyListeners();
        },
      );
      syncProgress = 0.8;
      syncStatus = 'Saving to local database...';
      notifyListeners();
      await _cache.saveSubjects(fetchedSubjects);
      await _cache.saveAssignments(fetchedAssignments);
      final verifiedSubjects = _cache.readSubjects();
      final countWithAudio = verifiedSubjects
          .where(
            (subject) =>
                subject.type == SubjectType.vocabulary &&
                subject.pronunciationAudios.any(
                  (audio) => audio.url.trim().isNotEmpty,
                ),
          )
          .length;
      print('SYNC VERIFY: Total vocabularies with audio URLs: $countWithAudio');
      syncProgress = 0.95;
      subjects
        ..clear()
        ..addAll(verifiedSubjects);
      assignments
        ..clear()
        ..addAll(fetchedAssignments);
      await _cache.setLastSync(DateTime.now());
      syncStatus =
          'Synced ${subjects.length} subjects and ${assignments.length} assignments.';
      syncProgress = 1;
    } catch (error) {
      if (error is DioException) {
        final details = [
          'DioException',
          'Type: ${error.type}',
          'Status: ${error.response?.statusCode ?? 'none'}',
          'Response: ${error.response?.data ?? 'none'}',
          'Message: ${error.message ?? 'none'}',
        ].join('\n');
        syncError = details;
        syncStatus = details;
      } else {
        final details = error.toString();
        syncError = details;
        syncStatus = details;
      }
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: defaultTargetPlatform == TargetPlatform.android
        ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
        : const EdgeInsets.fromLTRB(42, 38, 42, 48),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 15)),
            const SizedBox(height: 30),
            child,
          ],
        ),
      ),
    ),
  );
}

class DashboardStats {
  const DashboardStats(this.spread, this.burned, this.guruPlus, this.assigned);

  factory DashboardStats.compute(
    List<Subject> subjects,
    List<Assignment> assignments,
  ) {
    final spread = {
      for (final stage in SrsStage.values)
        stage: {for (final type in SubjectType.values) type: 0},
    };
    final typeById = {for (final s in subjects) s.id: s.type};
    var burned = 0;
    var guruPlus = 0;
    for (final assignment in assignments) {
      if (assignment.srsStage == SrsStage.burned) burned++;
      if (assignment.srsStage != SrsStage.apprentice) guruPlus++;
      final type = typeById[assignment.subjectId];
      if (type != null) {
        final row = spread[assignment.srsStage]!;
        row[type] = row[type]! + 1;
      }
    }
    return DashboardStats(spread, burned, guruPlus, assignments.length);
  }

  final Map<SrsStage, Map<SubjectType, int>> spread;
  final int burned;
  final int guruPlus;
  final int assigned;
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.controller, super.key});
  final ReviewerController controller;

  @override
  Widget build(BuildContext context) {
    final stats = controller.stats;
    final burned = stats.burned;
    final guruPlus = stats.guruPlus;
    final assigned = stats.assigned;
    final user = controller.user;
    return PageFrame(
      title: user == null
          ? 'Review with intention.'
          : 'Welcome back, ${user.username}!',
      subtitle: user == null
          ? 'Sync your WaniKani data in Settings to see your progress.'
          : 'Level ${user.level} · overview of your progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 600 ? 2 : 4;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  StatTile(
                    width: width,
                    label: 'Level',
                    value: '${user?.level ?? '–'}',
                    icon: Icons.stairs_rounded,
                    color: const Color(0xFFAA00FF),
                  ),
                  StatTile(
                    width: width,
                    label: 'Synced items',
                    value: '${controller.subjects.length}',
                    icon: Icons.layers_outlined,
                    color: const Color(0xFF00AAFF),
                  ),
                  StatTile(
                    width: width,
                    label: 'Guru or higher',
                    value: assigned == 0
                        ? '–'
                        : '${(guruPlus * 100 / assigned).round()}%',
                    icon: Icons.insights_outlined,
                    color: const Color(0xFF4C7A00),
                  ),
                  StatTile(
                    width: width,
                    label: 'Burned',
                    value: '$burned',
                    icon: Icons.local_fire_department_outlined,
                    color: const Color(0xFFFF7043),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          ItemSpreadCard(controller: controller),
          if (controller.hasSavedSession) ...[
            const SizedBox(height: 20),
            Card(
              color: const Color(0xFFE8F5D0),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: const Text('Resume Saved Session'),
                subtitle: const Text(
                  'Continue where your previous review stopped.',
                ),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: controller.resumeSavedSession,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({required this.controller, super.key});
  final ReviewerController controller;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController sessionSizeInput;
  final FocusNode sessionSizeFocus = FocusNode();
  StudyMode? displayedMode;
  int? displayedSize;

  ReviewerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    sessionSizeInput = TextEditingController();
  }

  @override
  void dispose() {
    sessionSizeInput.dispose();
    sessionSizeFocus.dispose();
    super.dispose();
  }

  void applyCustomSize(String value) {
    final customSize = int.tryParse(value);
    if (customSize == null || controller.availableItemCount == 0) return;
    controller.setSessionSize(customSize);
    sessionSizeInput.text = '${controller.sessionSize}';
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = controller.availableItemCount;
    final quickSizes = {
      for (final size in [10, 25, 50, 100])
        if (availableCount > 0) size.clamp(1, availableCount),
    }.toList()..sort();
    if ((displayedMode != controller.studyMode ||
            displayedSize != controller.sessionSize) &&
        !sessionSizeFocus.hasFocus) {
      sessionSizeInput.text = '${controller.sessionSize}';
    }
    displayedMode = controller.studyMode;
    displayedSize = controller.sessionSize;
    return PageFrame(
      title: '${_modeName(controller.studyMode)} setup',
      subtitle: 'Tune this study mode, then start a focused session.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'SRS stages',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final stage in SrsStage.values)
                  FilterChip(
                    label: Text(_stageName(stage)),
                    selected: controller.stages.contains(stage),
                    onSelected: (selected) {
                      if (selected) {
                        controller.stages.add(stage);
                      } else {
                        controller.stages.remove(stage);
                      }
                      controller.refresh();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Item types',
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final type in SubjectType.values)
                  FilterChip(
                    label: Text(_subjectTypeName(type)),
                    selected: controller.subjectTypes.contains(type),
                    onSelected: (selected) {
                      if (selected) {
                        controller.subjectTypes.add(type);
                      } else {
                        controller.subjectTypes.remove(type);
                      }
                      controller.refresh();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Level range',
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final int maxLevel = controller.user?.level ?? 1;
                    final currentStart = controller.levels.start
                        .clamp(1, maxLevel)
                        .toInt();
                    final currentEnd = controller.levels.end
                        .clamp(1, maxLevel)
                        .toInt();
                    return RangeSlider(
                      min: 1.0,
                      max: maxLevel.toDouble() > 1.0
                          ? maxLevel.toDouble()
                          : 2.0,
                      values: RangeValues(
                        currentStart.toDouble(),
                        currentEnd.clamp(1, maxLevel).toDouble(),
                      ),
                      divisions: maxLevel > 1 ? maxLevel - 1 : 1,
                      labels: RangeLabels(
                        'Level $currentStart',
                        'Level $currentEnd',
                      ),
                      onChanged: (value) {
                        controller.levels = RangeValues(
                          value.start.clamp(1, maxLevel).toDouble(),
                          value.end.clamp(1, maxLevel).toDouble(),
                        );
                        controller.refresh();
                      },
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level ${controller.levels.start.clamp(1, controller.userLevel).round()}',
                    ),
                    Text(
                      'Level ${controller.levels.end.clamp(1, controller.userLevel).round()}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (controller.studyMode != StudyMode.context)
            SectionCard(
              title: controller.studyMode == StudyMode.matching
                  ? 'Pairing type'
                  : 'Question types',
              child: SegmentedButton<QuestionScope>(
                segments: controller.studyMode == StudyMode.matching
                    ? const [
                        ButtonSegment(
                          value: QuestionScope.meaning,
                          label: Text('Item <-> Meaning'),
                        ),
                        ButtonSegment(
                          value: QuestionScope.reading,
                          label: Text('Item <-> Reading'),
                        ),
                      ]
                    : const [
                        ButtonSegment(
                          value: QuestionScope.both,
                          label: Text('Meanings + Readings'),
                        ),
                        ButtonSegment(
                          value: QuestionScope.meaning,
                          label: Text('Meanings'),
                        ),
                        ButtonSegment(
                          value: QuestionScope.reading,
                          label: Text('Readings'),
                        ),
                      ],
                selected: {
                  controller.studyMode == StudyMode.matching
                      ? controller.matchingPairType
                      : controller.scope,
                },
                onSelectionChanged: (value) {
                  if (controller.studyMode == StudyMode.matching) {
                    controller.matchingPairType = value.first;
                  } else {
                    controller.scope = value.first;
                  }
                  controller.refresh();
                },
              ),
            ),
          if (controller.studyMode == StudyMode.typing) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Typing feedback',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show details after success'),
                    value: controller.showSuccessDetails,
                    onChanged: (value) {
                      controller.showSuccessDetails = value;
                      controller.refresh();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reveal answer after 2 mistakes'),
                    value: controller.revealOnSecondMistake,
                    onChanged: (value) {
                      controller.revealOnSecondMistake = value;
                      controller.refresh();
                    },
                  ),
                ],
              ),
            ),
          ],
          if (controller.studyMode == StudyMode.multipleChoice) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Answer Options',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Eliminate incorrect answers'),
                    subtitle: const Text(
                      'A wrong choice is only greyed out; keep trying until '
                      'you find the right one.',
                    ),
                    value: controller.multipleChoiceElimination,
                    onChanged: (value) {
                      controller.multipleChoiceElimination = value;
                      controller.refresh();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reveal correct answer on miss'),
                    subtitle: const Text(
                      'Highlight the right option and show it after a mistake.',
                    ),
                    value: controller.revealCorrectOnMiss,
                    onChanged: (value) {
                      controller.revealCorrectOnMiss = value;
                      controller.refresh();
                    },
                  ),
                ],
              ),
            ),
          ],
          if (controller.studyMode == StudyMode.context) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Context options',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show English translation by default'),
                    value: controller.showEnglishByDefault,
                    onChanged: (value) {
                      controller.showEnglishByDefault = value;
                      controller.refresh();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Eliminate incorrect options'),
                    subtitle: const Text(
                      'A wrong choice is only greyed out; keep trying until '
                      'you find the right one.',
                    ),
                    value: controller.contextElimination,
                    onChanged: (value) {
                      controller.contextElimination = value;
                      controller.refresh();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reveal correct answer on miss'),
                    subtitle: const Text(
                      'Highlight the right option and show it after a mistake.',
                    ),
                    value: controller.contextRevealOnMiss,
                    onChanged: (value) {
                      controller.contextRevealOnMiss = value;
                      controller.refresh();
                    },
                  ),
                ],
              ),
            ),
          ],
          SectionCard(
            title: 'Session size',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final size in quickSizes)
                      ChoiceChip(
                        label: Text('$size'),
                        selected: controller.sessionSize == size,
                        onSelected: (_) => controller.setSessionSize(size),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: sessionSizeInput,
                    focusNode: sessionSizeFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: applyCustomSize,
                    decoration: const InputDecoration(
                      labelText: 'Custom count',
                      helperText: 'Press Enter to apply',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  availableCount == 0
                      ? 'Available ${controller.studyMode == StudyMode.context
                            ? 'sentence cards'
                            : controller.studyMode == StudyMode.matching
                            ? 'pairs'
                            : 'items'}: 0'
                      : 'Available ${controller.studyMode == StudyMode.context
                            ? 'sentence cards'
                            : controller.studyMode == StudyMode.matching
                            ? 'pairs'
                            : 'items'}: $availableCount',
                  style: TextStyle(
                    color: availableCount == 0
                        ? const Color(0xFFB42318)
                        : _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: availableCount == 0 ? null : controller.startQuiz,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Padding(
                padding: EdgeInsets.all(5),
                child: Text('Start review'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({required this.controller, required this.config, super.key});
  final ReviewerController controller;
  final QuizConfig config;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final input = KanaInputController();
  final focus = FocusNode();
  final keyboardFocus = FocusNode(debugLabel: 'quiz keyboard shortcuts');
  String? feedbackItemId;
  bool feedbackShown = false;
  bool lastAnswerCorrect = false;
  bool slightTypoAccepted = false;
  bool answerRevealed = false;
  int mistakeCount = 0;
  String? audioDebugCardId;

  @override
  void initState() {
    super.initState();
    print(
      'QUIZ CONFIG DEBUG: revealOnSecondMiss = ${widget.config.revealOnSecondMiss}, '
      'showOther =${widget.config.showOther}',
    );
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> playPronunciation(
    Subject subject, {
    String? successfulAnswerItemId,
  }) async {
    final currentItem = widget.controller.currentItem;
    final manuallyAllowed =
        currentItem?.subject.id == subject.id &&
        ((feedbackShown && lastAnswerCorrect) || answerRevealed);
    final autoplayAllowed =
        successfulAnswerItemId != null &&
        widget.controller.quizItems.any(
          (item) =>
              item.id == successfulAnswerItemId &&
              item.subject.id == subject.id &&
              item.kind == QuestionKind.reading,
        );
    if (!manuallyAllowed && !autoplayAllowed) {
      print(
        'AUDIO BLOCKED: ${subject.characters} is still an unanswered active card.',
      );
      return;
    }
    print('AUDIO CHECK: Requested playback for subject: ${subject.characters}');
    print(
      'AUDIO CHECK: Available audio URLs count: ${subject.pronunciationAudios.length}',
    );
    debugPrint('Subject type: ${subject.type.name}');
    if (subject.type != SubjectType.vocabulary) {
      debugPrint('[audio] skipped: subject is not vocabulary');
      return;
    }
    try {
      if (subject.pronunciationAudios.isEmpty) {
        throw StateError('Vocabulary has no pronunciation audio URLs');
      }
      final audio = subject.pronunciationAudioForVoice(
        widget.controller.preferredVoice,
      );
      if (audio == null) {
        throw StateError('Vocabulary has no valid HTTPS audio URL');
      }
      final url = audio.url;
      print('AUDIO CHECK: Target URL: $url');
      print('DEBUG AUDIO: Playing [${subject.characters}] from URL:$url');
      print('Playing audio for vocabulary: ${subject.characters}');
      print('Audio URL: $url');
      final cachedPath = await cacheAudioFile(
        url,
        '${subject.id}_${audio.gender ?? widget.controller.preferredVoice}_${audio.voiceActorId ?? 0}',
      );
      final localPath = cachedPath;
      print('AUDIO CHECK: Target local cache path: $localPath');
      if (localPath == null) {
        print('AUDIO CHECK: Dispatching remote URL to playback service: $url');
        await playRemoteAudio(url);
      } else {
        print(
          'AUDIO CHECK: Dispatching local file to playback service: $localPath',
        );
        await playLocalAudio(localPath);
      }
    } catch (error, stackTrace) {
      print('AUDIO CHECK ERROR: $error');
      print('AUDIO CHECK STACK: $stackTrace');
      print('AUDIO LOG ERROR: $error');
      print('AUDIO LOG STACK: $stackTrace');
      print('DEBUG AUDIO ERROR: $error');
      print(stackTrace);
      debugPrint('[audio] playback failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // A missing or unavailable pronunciation should not interrupt a review.
    }
  }

  void evaluateChoice(String answer, bool correct) {
    final item = widget.controller.currentItem;
    if (correct &&
        widget.controller.audioAutoplay &&
        item?.subject.type == SubjectType.vocabulary &&
        item?.kind == QuestionKind.reading) {
      triggerPronunciation(item!.subject, successfulAnswerItemId: item.id);
    }
  }

  void answerChoice(String answer, bool correct) {
    final item = widget.controller.currentItem;
    if (correct &&
        widget.controller.audioAutoplay &&
        item?.subject.type == SubjectType.vocabulary &&
        item?.kind == QuestionKind.reading) {
      triggerPronunciation(item!.subject, successfulAnswerItemId: item.id);
    }
    widget.controller.answerChoice(answer, correct);
  }

  void triggerPronunciation(Subject subject, {String? successfulAnswerItemId}) {
    print(
      'UI AUDIO TRIGGER: Clicked or Autoplay triggered for item: ${subject.characters}',
    );
    print('UI AUDIO TRIGGER: Subject type is: ${subject.type.value}');
    print(
      'UI AUDIO TRIGGER: Pronunciation audios list: ${subject.pronunciationAudios.map((audio) => audio.url).toList()}',
    );
    unawaited(
      playPronunciation(
        subject,
        successfulAnswerItemId: successfulAnswerItemId,
      ),
    );
  }

  void submitTyping() {
    final item = widget.controller.currentItem;
    if (item == null) return;
    if (feedbackItemId != item.id) {
      feedbackItemId = item.id;
      answerRevealed = false;
      slightTypoAccepted = false;
      mistakeCount =
          widget.controller.engine?.incorrectAttemptsFor(item.id) ?? 0;
    }
    if (feedbackShown) {
      widget.controller.nextAfterFeedback(lastAnswerCorrect);
      input.clear();
      feedbackShown = false;
      answerRevealed = false;
      mistakeCount = 0;
      feedbackItemId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && focus.canRequestFocus) focus.requestFocus();
      });
      return;
    }
    final value = item.kind != QuestionKind.meaning
        ? input.normalizeForSubmission()
        : input.text.trim().toLowerCase();
    final acceptedAnswers = QuizEngine.subjectAnswers(item.subject, item.kind);
    final exactMatch = acceptedAnswers.any(
      (answer) => AnswerMatcher.matches(answer, value),
    );
    slightTypoAccepted =
        !exactMatch &&
        item.kind == QuestionKind.meaning &&
        acceptedAnswers.any(
          (answer) => AnswerMatcher.matches(answer, value, allowTypo: true),
        );
    final accepted = exactMatch || slightTypoAccepted;
    lastAnswerCorrect = accepted;
    feedbackShown = true;
    if (accepted) {
      input.clear();
      if (widget.controller.audioAutoplay &&
          item.subject.type == SubjectType.vocabulary &&
          item.kind == QuestionKind.reading) {
        triggerPronunciation(item.subject);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && keyboardFocus.canRequestFocus) {
          keyboardFocus.requestFocus();
        }
      });
    } else {
      input.clear();
      final nextMissCount =
          (widget.controller.engine?.incorrectAttemptsFor(item.id) ?? 0) + 1;
      mistakeCount = nextMissCount;
      widget.controller.answer(false, wrongAnswer: value);
      if (widget.config.revealOnSecondMiss && nextMissCount >= 2) {
        answerRevealed = true;
      }
    }
    feedbackShown = true;
    widget.controller.refresh();
    if (!accepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && keyboardFocus.canRequestFocus) {
          keyboardFocus.requestFocus();
        }
      });
    }
  }

  KeyEventResult handleKeyboard(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        widget.controller.studyMode == StudyMode.typing &&
        feedbackShown) {
      submitTyping();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void revealAnswer() {
    answerRevealed = true;
    widget.controller.refresh();
  }

  Future<void> confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text(
          'Are you sure you want to exit? Unsaved progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit Quiz'),
          ),
        ],
      ),
    );
    if (shouldExit == true) await widget.controller.exitQuiz();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final item = widget.controller.currentItem;
    if (item == null) return const SizedBox.shrink();
    if (item.subject.type == SubjectType.vocabulary &&
        audioDebugCardId != item.id) {
      audioDebugCardId = item.id;
      print(
        'CARD AUDIO DEBUG: ${item.subject.characters} has${item.subject.pronunciationAudios.length} audio tracks',
      );
    }
    return Focus(
      focusNode: keyboardFocus,
      onKeyEvent: (_, event) => handleKeyboard(event),
      child: PageFrame(
        title: _modeName(widget.controller.studyMode),
        subtitle:
            widget.controller.studyMode == StudyMode.multipleChoice &&
                    !widget.controller.multipleChoiceRequeues ||
                widget.controller.studyMode == StudyMode.context &&
                    !widget.controller.contextRequeues
            ? 'Answer every card once. Missed cards are counted but not repeated.'
            : 'Answer every card correctly. Missed cards return to the queue.',
        child: Column(
          crossAxisAlignment: isAndroid
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: widget.controller.audioAutoplay
                          ? 'Audio autoplay on'
                          : 'Audio autoplay off',
                      onPressed: () {
                        widget.controller.audioAutoplay =
                            !widget.controller.audioAutoplay;
                        widget.controller.refresh();
                      },
                      icon: Icon(
                        widget.controller.audioAutoplay
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                      ),
                    ),
                  ],
                ),
                if (isAndroid) ...[
                  IconButton(
                    tooltip: 'Save & Exit',
                    onPressed: () => widget.controller.saveAndExit(),
                    icon: const Icon(Icons.pause_rounded),
                  ),
                  IconButton(
                    tooltip: 'Exit Quiz',
                    onPressed: confirmExit,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () => widget.controller.saveAndExit(),
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Save & Exit'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: confirmExit,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Exit Quiz'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: widget.controller.progress,
                      minHeight: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Text(
                  'Accuracy: ${(widget.controller.accuracy * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (widget.controller.studyMode == StudyMode.typing)
              _TypingCard(
                item: item,
                input: input,
                focus: focus,
                onChanged: (value) {
                  if (item.kind != QuestionKind.meaning) {
                    input.normalizeLive(value);
                  }
                },
                onSubmitted: (_) => submitTyping(),
                feedbackShown: feedbackShown,
                correct: lastAnswerCorrect,
                slightTypoAccepted: slightTypoAccepted,
                revealed: answerRevealed,
                onShowAnswer: revealAnswer,
                locked: feedbackShown || answerRevealed,
                onPlayAudio: () => triggerPronunciation(item.subject),
                showOther: widget.config.showOther,
              ),
            if (widget.controller.studyMode == StudyMode.multipleChoice)
              _MultipleChoiceCard(
                item: item,
                pool: widget.controller.quizPool,
                onEvaluated: evaluateChoice,
                onAnswer: (answer, correct) => widget.controller.answerChoice(
                  answer,
                  correct,
                  requeueOnMiss: widget.controller.multipleChoiceRequeues,
                ),
                eliminateIncorrect: widget.controller.multipleChoiceElimination,
                revealCorrectOnMiss: widget.controller.revealCorrectOnMiss,
              ),
            if (widget.controller.studyMode == StudyMode.matching)
              MatchingCard(
                items: widget.controller.matchingItems,
                onMatched: (item) {
                  if (widget.controller.audioAutoplay &&
                      item.subject.type == SubjectType.vocabulary &&
                      item.kind == QuestionKind.reading) {
                    triggerPronunciation(
                      item.subject,
                      successfulAnswerItemId: item.id,
                    );
                  }
                },
                onComplete: () => widget.controller.answerMany(
                  widget.controller.matchingItems.length,
                ),
              ),
            if (widget.controller.studyMode == StudyMode.context)
              _ContextCard(
                item: item,
                pool: widget.controller.quizPool,
                onEvaluated: evaluateChoice,
                onAnswer: (answer, correct) => widget.controller.answerChoice(
                  answer,
                  correct,
                  requeueOnMiss: widget.controller.contextRequeues,
                ),
                showEnglishByDefault: widget.config.showEnglishByDefault,
                eliminateIncorrect: widget.controller.contextElimination,
                revealCorrectOnMiss: widget.controller.contextRevealOnMiss,
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingCard extends StatelessWidget {
  const _TypingCard({
    required this.item,
    required this.input,
    required this.focus,
    required this.onChanged,
    required this.onSubmitted,
    required this.feedbackShown,
    required this.correct,
    required this.slightTypoAccepted,
    required this.revealed,
    required this.onShowAnswer,
    required this.locked,
    required this.onPlayAudio,
    required this.showOther,
  });
  final QuizItem item;
  final TextEditingController input;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool feedbackShown;
  final bool correct;
  final bool slightTypoAccepted;
  final bool revealed;
  final VoidCallback onShowAnswer;
  final bool locked;
  final VoidCallback onPlayAudio;
  final bool showOther;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: revealed ? const Color(0xFFFFF8F7) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: revealed
            ? const BorderSide(color: Color(0xFFB42318))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(38),
        child: Column(
          children: [
            Text(
              _questionLabel(item),
              style: TextStyle(
                color: _subjectColor(item.subject.type),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              item.prompt,
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.subject.type.name.toUpperCase(),
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 34),
            TextField(
              controller: input,
              focusNode: focus,
              autofocus: true,
              readOnly: locked,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: item.kind != QuestionKind.meaning
                    ? 'Type romaji or kana and press Enter'
                    : 'Type an English answer and press Enter',
                suffixIcon: IconButton(
                  tooltip: feedbackShown ? 'Next item' : 'Check answer',
                  onPressed: () => onSubmitted(input.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            if (feedbackShown) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: correct
                    ? const Color(0xFFE8F5D0)
                    : const Color(0xFFFFE4E0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct
                          ? slightTypoAccepted
                                ? 'Slight typo, but accepted. Press Enter for the next item.'
                                : 'Correct. Press Enter for the next item.'
                          : revealed
                          ? 'Answer revealed. Press Enter to continue.'
                          : 'Incorrect. Press Enter to continue.',
                      style: TextStyle(
                        color: correct
                            ? const Color(0xFF4C7A00)
                            : const Color(0xFFB42318),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (revealed || (correct && showOther)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.kind == QuestionKind.meaning
                                  ? 'Meanings: ${item.subject.meanings.join(', ')}'
                                  : 'Readings: ${QuizEngine.subjectAnswers(item.subject, item.kind).join(', ')}',
                            ),
                          ),
                          if (item.kind == QuestionKind.reading &&
                              item.subject.type == SubjectType.vocabulary &&
                              item.subject.hasPronunciationAudioUrls)
                            IconButton(
                              tooltip: 'Play pronunciation',
                              onPressed: onPlayAudio,
                              icon: const Icon(Icons.volume_up_rounded),
                            ),
                        ],
                      ),
                    ] else if (!correct)
                      TextButton(
                        onPressed: onShowAnswer,
                        child: const Text('Show Answer'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MultipleChoiceCard extends StatefulWidget {
  const _MultipleChoiceCard({
    required this.item,
    required this.pool,
    required this.onEvaluated,
    required this.onAnswer,
    required this.eliminateIncorrect,
    required this.revealCorrectOnMiss,
  });
  final QuizItem item;
  final List<Subject> pool;
  final void Function(String answer, bool correct) onEvaluated;
  final void Function(String answer, bool correct) onAnswer;
  final bool eliminateIncorrect;
  final bool revealCorrectOnMiss;

  @override
  State<_MultipleChoiceCard> createState() => _MultipleChoiceCardState();
}

class _MultipleChoiceCardState extends State<_MultipleChoiceCard> {
  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];
  static const _numpadKeys = [
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
  ];

  final focusNode = FocusNode(debugLabel: 'multiple choice shortcuts');
  // Set once the card is finished and only "Next" remains.
  String? finalAnswer;
  final Set<String> eliminated = {};
  String? lastWrong;
  late List<String> currentOptions;

  bool get answered => finalAnswer != null;
  bool get hadMiss => lastWrong != null;

  void _resetCard() {
    finalAnswer = null;
    lastWrong = null;
    eliminated.clear();
    currentOptions = _createOptions();
  }

  @override
  void didUpdateWidget(covariant _MultipleChoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.item, widget.item) ||
        oldWidget.item.id != widget.item.id) {
      _resetCard();
      _refocus();
    }
  }

  @override
  void initState() {
    super.initState();
    currentOptions = _createOptions();
    _refocus();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && focusNode.canRequestFocus) focusNode.requestFocus();
    });
  }

  String get _correctAnswer =>
      QuizEngine.subjectAnswers(
        widget.item.subject,
        widget.item.kind,
      ).firstOrNull ??
      '';

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (answered) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _next();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    for (var i = 0; i < currentOptions.length && i < 4; i++) {
      if (key == _digitKeys[i] || key == _numpadKeys[i]) {
        final option = currentOptions[i];
        if (!eliminated.contains(option)) choose(option);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _next() {
    final answer = finalAnswer;
    if (answer == null) return;
    // A card with any miss counts as incorrect, even if later solved.
    final wrongAnswer = lastWrong;
    _resetCard();
    setState(() {});
    if (wrongAnswer != null) {
      widget.onAnswer(wrongAnswer, false);
    } else {
      widget.onAnswer(answer, true);
    }
    _refocus();
  }

  List<String> _createOptions() {
    final correct =
        QuizEngine.subjectAnswers(
          widget.item.subject,
          widget.item.kind,
        ).firstOrNull ??
        '';
    final distractors = QuizEngine.distractors(
      widget.item.subject,
      widget.pool,
      kind: widget.item.kind,
    ).where((answer) => answer != correct).toList()..shuffle();
    return [correct, ...distractors.take(3)]..shuffle();
  }

  void choose(String answer) {
    if (answered || eliminated.contains(answer)) return;
    final isCorrect = answer == _correctAnswer;
    setState(() {
      if (isCorrect) {
        finalAnswer = answer;
        return;
      }
      lastWrong = answer;
      if (!widget.eliminateIncorrect) {
        finalAnswer = answer;
        return;
      }
      eliminated.add(answer);
      final wrongLeft = currentOptions.any(
        (option) => option != _correctAnswer && !eliminated.contains(option),
      );
      // Only the right option is left, so the card ends as a miss.
      if (!wrongLeft) finalAnswer = answer;
    });
    widget.onEvaluated(answer, isCorrect);
    _refocus();
  }

  bool get _showCorrect {
    final answer = finalAnswer;
    if (answer == null) return false;
    return answer == _correctAnswer || widget.revealCorrectOnMiss;
  }

  @override
  Widget build(BuildContext context) {
    final correct = _correctAnswer;
    final failed = answered && hadMiss;
    return Focus(
      focusNode: focusNode,
      onKeyEvent: _handleKey,
      child: Card(
        color: failed ? const Color(0xFFFFF8F7) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: failed
              ? const BorderSide(color: Color(0xFFB42318))
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(38),
          child: Column(
            children: [
              Text(
                _questionLabel(widget.item),
                style: TextStyle(
                  color: _subjectColor(widget.item.subject.type),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.item.prompt,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 28),
              for (final entry in currentOptions.asMap().entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: Opacity(
                      opacity: eliminated.contains(entry.value) && !answered
                          ? 0.45
                          : 1,
                      child: OutlinedButton(
                        onPressed: answered || eliminated.contains(entry.value)
                            ? null
                            : () => choose(entry.value),
                        style: _optionStyle(entry.value, correct),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${entry.key + 1}   ${entry.value}'),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!answered && hadMiss) ...[
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Incorrect – try another option.',
                    style: TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (answered) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    !hadMiss
                        ? 'Correct!'
                        : finalAnswer == correct
                        ? 'Found it, but counted as a miss.'
                        : widget.revealCorrectOnMiss
                        ? 'Correct answer: $correct. '
                              '${widget.item.subject.meanings.join(', ')}'
                        : 'Incorrect.',
                    style: TextStyle(
                      color: !hadMiss
                          ? const Color(0xFF16866A)
                          : const Color(0xFFB42318),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle? _optionStyle(String option, String correct) {
    final isWrongPick =
        eliminated.contains(option) || (answered && option == finalAnswer);
    if (option == correct && _showCorrect) {
      return OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFDDF3E8),
        foregroundColor: const Color(0xFF16866A),
        disabledBackgroundColor: const Color(0xFFDDF3E8),
        disabledForegroundColor: const Color(0xFF16866A),
      );
    }
    if (isWrongPick && option != correct) {
      return OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFFFE4E0),
        foregroundColor: const Color(0xFFB42318),
        disabledBackgroundColor: const Color(0xFFFFE4E0),
        disabledForegroundColor: const Color(0xFFB42318),
      );
    }
    return null;
  }
}

class _ContextCard extends StatefulWidget {
  const _ContextCard({
    required this.item,
    required this.pool,
    required this.onEvaluated,
    required this.onAnswer,
    required this.showEnglishByDefault,
    required this.eliminateIncorrect,
    required this.revealCorrectOnMiss,
  });
  final QuizItem item;
  final List<Subject> pool;
  final void Function(String answer, bool correct) onEvaluated;
  final void Function(String answer, bool correct) onAnswer;
  final bool showEnglishByDefault;
  final bool eliminateIncorrect;
  final bool revealCorrectOnMiss;
  @override
  State<_ContextCard> createState() => _ContextCardState();
}

class _ContextCardState extends State<_ContextCard> {
  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];
  static const _numpadKeys = [
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
  ];

  final focusNode = FocusNode(debugLabel: 'context shortcuts');
  // Set once the card is finished and only "Next" remains.
  String? finalAnswer;
  String? lastWrong;
  final Set<String> eliminated = {};
  late bool englishRevealed;
  late List<String> currentOptions;

  bool get answered => finalAnswer != null;
  bool get hadMiss => lastWrong != null;
  String get _correct => widget.item.subject.characters;

  @override
  void didUpdateWidget(covariant _ContextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _resetCard();
      _refocus();
    }
  }

  @override
  void initState() {
    super.initState();
    _resetCard();
    _refocus();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void _resetCard() {
    finalAnswer = null;
    lastWrong = null;
    eliminated.clear();
    englishRevealed = widget.showEnglishByDefault;
    currentOptions = _createOptions();
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && focusNode.canRequestFocus) focusNode.requestFocus();
    });
  }

  List<String> _createOptions() {
    final correct = _correct;
    final distractors =
        widget.pool
            .where(
              (subject) =>
                  subject.id != widget.item.subject.id &&
                  subject.type == SubjectType.vocabulary,
            )
            .map((subject) => subject.characters)
            .where((value) => value != correct)
            .toSet()
            .toList()
          ..shuffle();
    return [correct, ...distractors.take(3)]..shuffle();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (answered) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _next();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    for (var i = 0; i < currentOptions.length && i < 4; i++) {
      if (key == _digitKeys[i] || key == _numpadKeys[i]) {
        choose(currentOptions[i]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void choose(String answer) {
    if (answered || eliminated.contains(answer)) return;
    final isCorrect = answer == _correct;
    setState(() {
      if (isCorrect) {
        finalAnswer = answer;
        return;
      }
      lastWrong = answer;
      if (!widget.eliminateIncorrect) {
        finalAnswer = answer;
        return;
      }
      eliminated.add(answer);
      final wrongLeft = currentOptions.any(
        (option) => option != _correct && !eliminated.contains(option),
      );
      // Only the right option is left, so the card ends as a miss.
      if (!wrongLeft) finalAnswer = answer;
    });
    widget.onEvaluated(answer, isCorrect);
    _refocus();
  }

  bool get _showCorrect {
    final answer = finalAnswer;
    if (answer == null) return false;
    return answer == _correct || widget.revealCorrectOnMiss;
  }

  void _next() {
    final answer = finalAnswer;
    if (answer == null) return;
    // Any miss on the card counts as incorrect, even if solved later.
    final wrongAnswer = lastWrong;
    if (wrongAnswer != null) {
      widget.onAnswer(wrongAnswer, false);
    } else {
      widget.onAnswer(answer, true);
    }
  }

  ButtonStyle? _optionStyle(String option) {
    if (option == _correct && _showCorrect) {
      return OutlinedButton.styleFrom(
        disabledBackgroundColor: const Color(0xFFDDF3E8),
        disabledForegroundColor: const Color(0xFF16866A),
      );
    }
    if (option != _correct &&
        (eliminated.contains(option) || (answered && option == finalAnswer))) {
      return OutlinedButton.styleFrom(
        disabledBackgroundColor: const Color(0xFFFFE4E0),
        disabledForegroundColor: const Color(0xFFB42318),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sentence = widget.item.subject.contextSentences.firstOrNull;
    final correct = _correct;
    final wrong = answered && hadMiss;
    return Focus(
      focusNode: focusNode,
      onKeyEvent: _handleKey,
      child: Card(
        color: wrong ? const Color(0xFFFFF8F7) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: wrong
              ? const BorderSide(color: Color(0xFFB42318))
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(38),
          child: Column(
            children: [
              const Text(
                'FILL IN THE CONTEXT',
                style: TextStyle(
                  color: Color(0xFF00AAFF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 26),
              Text(
                sentence?.ja.replaceAll(correct, '[ ___ ]') ?? '[ ___ ]',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              if (englishRevealed || answered)
                Text(
                  sentence?.en ?? 'Choose the missing vocabulary item.',
                  style: const TextStyle(color: _muted),
                )
              else
                TextButton.icon(
                  onPressed: () => setState(() => englishRevealed = true),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Reveal English translation'),
                ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in currentOptions.asMap().entries)
                    OutlinedButton(
                      onPressed: answered || eliminated.contains(entry.value)
                          ? null
                          : () => choose(entry.value),
                      style: _optionStyle(entry.value),
                      child: Text('${entry.key + 1}   ${entry.value}'),
                    ),
                ],
              ),
              if (!answered && hadMiss) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Incorrect – try another option.',
                    style: TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (answered) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    !hadMiss
                        ? 'Correct!'
                        : finalAnswer == correct
                        ? 'Found it, but counted as a miss.'
                        : widget.revealCorrectOnMiss
                        ? 'Correct answer: $correct '
                              '(${widget.item.subject.meanings.join(', ')})'
                        : 'Incorrect.',
                    style: TextStyle(
                      color: !hadMiss
                          ? const Color(0xFF16866A)
                          : const Color(0xFFB42318),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    autofocus: true,
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next  (Enter)'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({required this.controller, super.key});
  final ReviewerController controller;
  @override
  Widget build(BuildContext context) {
    final missed = controller.engine?.missedIds.length ?? 0;
    return PageFrame(
      title: 'Session complete.',
      subtitle: 'A clear view of what landed on the first attempt.',
      child: Column(
        children: [
          Card(
            color: _ink,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'First-attempt accuracy',
                        style: TextStyle(color: Color(0xFFB9C7CF)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(controller.accuracy * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 50,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$missed missed',
                    style: const TextStyle(
                      color: Color(0xFFFFA38E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              if (controller.studyMode != StudyMode.matching) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.retryMissed,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Retry missed'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      controller.navigate(controller.studyMode.index + 1),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('New session'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.navigate(0),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Home'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatLastSync(DateTime? value) {
  if (value == null) return 'Never';
  final date = value.toLocal();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});
  final ReviewerController controller;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final token = TextEditingController();
  bool isTestingAudio = false;
  String audioTestStatus = '';
  StorageUsage? storageUsage;

  @override
  void initState() {
    super.initState();
    token.text = widget.controller.token ?? '';
    refreshStorageUsage();
  }

  Future<void> refreshStorageUsage() async {
    final usage = await measureStorageUsage();
    if (mounted) setState(() => storageUsage = usage);
  }

  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  Future<void> testAudioPlayback() async {
    final candidates = widget.controller.subjects.where((subject) {
      if (subject.type != SubjectType.vocabulary) return false;
      return subject.hasPronunciationAudioUrls;
    }).toList();
    if (candidates.isEmpty) {
      setState(() {
        audioTestStatus =
            'No Vocabulary audio URLs found. Sync WaniKani data first.';
      });
      return;
    }

    final subject = candidates.first;
    final audio = subject.pronunciationAudioForVoice(
      widget.controller.preferredVoice,
    )!;
    print(
      'UI AUDIO TRIGGER: Clicked or Autoplay triggered for item: ${subject.characters}',
    );
    print('UI AUDIO TRIGGER: Subject type is: ${subject.type.value}');
    print(
      'UI AUDIO TRIGGER: Pronunciation audios list: ${subject.pronunciationAudios.map((item) => item.url).toList()}',
    );
    setState(() {
      isTestingAudio = true;
      audioTestStatus = 'Playing ${subject.characters}...';
    });

    try {
      final localPath = await cacheAudioFile(
        audio.url,
        '${subject.id}_${audio.gender ?? widget.controller.preferredVoice}_${audio.voiceActorId ?? 0}',
      );
      if (localPath == null) {
        throw StateError('Audio file is missing or empty after download.');
      }
      await playLocalAudio(localPath);
      print(
        'Settings audio test completed: ${subject.characters} from $localPath',
      );
      if (mounted) {
        setState(() => audioTestStatus = 'Success: ${subject.characters}');
      }
    } catch (error, stackTrace) {
      print('Settings audio test error: $error');
      print('Settings audio test stack: $stackTrace');
      if (mounted) setState(() => audioTestStatus = 'Audio error: $error');
    } finally {
      if (mounted) setState(() => isTestingAudio = false);
    }
  }

  Future<void> confirmClearLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear local data?'),
        content: const Text(
          'Cached WaniKani subjects, assignments, and downloaded audio will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear data'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.clearLocalData();
      await refreshStorageUsage();
    }
  }

  Future<void> openExternal(String url, String name) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open $name.')));
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'API settings.',
    subtitle: 'Your token is stored locally in platform secure storage.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'WaniKani API v2',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: token,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Personal API token',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.controller.isSyncing) ...[
                LinearProgressIndicator(value: widget.controller.syncProgress),
                const SizedBox(height: 8),
                Text('${(widget.controller.syncProgress * 100).round()}%'),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: widget.controller.isSyncing
                        ? null
                        : () async {
                            await widget.controller.saveToken(token.text);
                          },
                    icon: widget.controller.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: const Text('Save token and sync'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.controller.isSyncing)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(
                    child: SelectableText(
                      widget.controller.syncStatus,
                      style: TextStyle(
                        color: widget.controller.syncError == null
                            ? _muted
                            : const Color(0xFFFF3333),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Preferred sync voice',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: widget.controller.preferredVoice,
                decoration: const InputDecoration(
                  labelText: 'Vocabulary audio',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'female',
                    child: Text('Kyoko - Female'),
                  ),
                  DropdownMenuItem(
                    value: 'male',
                    child: Text('Kenichi - Male'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) widget.controller.setPreferredVoice(value);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: isTestingAudio ? null : testAudioPlayback,
                    icon: isTestingAudio
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up_rounded),
                    label: const Text('Test Audio Playback'),
                  ),
                  if (audioTestStatus.isNotEmpty)
                    SelectableText(audioTestStatus),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Database and cache',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last sync: ${_formatLastSync(widget.controller.lastSync)}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              if (storageUsage == null)
                const Text(
                  'Calculating storage…',
                  style: TextStyle(color: _muted),
                )
              else ...[
                Text(
                  'Database: ${formatBytes(storageUsage!.databaseBytes)}',
                  style: const TextStyle(color: _muted),
                ),
                Text(
                  'Cache: ${formatBytes(storageUsage!.cacheBytes)}',
                  style: const TextStyle(color: _muted),
                ),
                Text(
                  'Total Storage: ${formatBytes(storageUsage!.totalBytes)}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: confirmClearLocalData,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear local database and audio cache'),
              ),
              const SizedBox(height: 8),
              const Text('App version 0.96.4', style: TextStyle(color: _muted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Community & Support',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join the community, share feedback and get help.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () =>
                    openExternal('https://discord.gg/Wuft2mmfUJ', 'Discord'),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Join Discord Server'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enjoying the reviewer? Your support helps keep the project going.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () =>
                    openExternal('https://ko-fi.com/edanadiir', 'Ko-fi'),
                icon: const Icon(Icons.favorite_rounded),
                label: const Text('Support on Ko-fi'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.child, super.key});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.width = 220,
    super.key,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            Text(label, style: const TextStyle(color: _muted)),
          ],
        ),
      ),
    ),
  );
}

class ModeCard extends StatelessWidget {
  const ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Card(
      color: Colors.white,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: _muted, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _modeName(StudyMode mode) => switch (mode) {
  StudyMode.typing => 'Classic Typing',
  StudyMode.multipleChoice => 'Multiple Choice',
  StudyMode.matching => 'Matching Pairs',
  StudyMode.context => 'Context',
};
String _stageName(SrsStage stage) =>
    stage.name[0].toUpperCase() + stage.name.substring(1);
String _subjectTypeName(SubjectType type) => switch (type) {
  SubjectType.radical => 'Radical',
  SubjectType.kanji => 'Kanji',
  SubjectType.vocabulary => 'Vocabulary',
};
String _questionLabel(QuizItem item) => switch (item.kind) {
  QuestionKind.meaning => 'WHAT DOES THIS MEAN?',
  QuestionKind.onyomi => "KANJI ON'YOMI READING",
  QuestionKind.kunyomi => 'KANJI KUN\'YOMI READING',
  QuestionKind.reading =>
    item.subject.type == SubjectType.vocabulary
        ? 'VOCABULARY READING'
        : 'HOW IS THIS READ?',
};
Color _subjectColor(SubjectType type) => switch (type) {
  SubjectType.radical => const Color(0xFF00AAFF),
  SubjectType.kanji => const Color(0xFFFF00AA),
  SubjectType.vocabulary => const Color(0xFFAA00FF),
};
