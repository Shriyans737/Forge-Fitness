import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/ads_service.dart';
import '../services/gemini_api_key_resolver.dart';
import '../features/coach/coach_copy.dart';
import '../features/coach/services/coach_nudge_service.dart';
import 'friends_screen.dart';
import '../theme.dart';
import '../widgets/banner_ad_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const String kCodeGeminiApiKey = String.fromEnvironment(
  'FORGE_GEMINI_API_KEY',
  defaultValue: '',
);

class _SettingsScreenState extends State<SettingsScreen> {
  late final Box<dynamic> _settingsBox;
  late int _defaultRestSeconds;
  late int _compoundRestSeconds;
  late int _isolationRestSeconds;
  late ThemeMode _themeMode;
  late TextEditingController _geminiApiKeyController;
  late TextEditingController _displayNameController;
  late TextEditingController _caloriesGoalController;
  late TextEditingController _proteinGoalController;
  late TextEditingController _carbsGoalController;
  late TextEditingController _fatGoalController;
  late TextEditingController _sleepGoalController;
  late TextEditingController _ageController;
  late TextEditingController _maxHeartRateController;
  bool _isTestingGemini = false;
  String? _geminiConnectionMessage;
  bool get _coachNudgesEnabled =>
      _settingsBox.get('coachNudgesEnabled') == true;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box<dynamic>('settings');
    _defaultRestSeconds = _readIntSetting('defaultRestSeconds', 90);
    _compoundRestSeconds = _readIntSetting('compoundRestSeconds', 120);
    _isolationRestSeconds = _readIntSetting('isolationRestSeconds', 75);
    _themeMode = ForgeTheme.themeModeFromStorageValue(
      _settingsBox.get('themeMode', defaultValue: 'system'),
    );
    _geminiApiKeyController = TextEditingController(
      text: _readStringSetting('geminiApiKey'),
    );
    _displayNameController = TextEditingController(
      text: _readStringSetting('displayName'),
    );
    _caloriesGoalController = TextEditingController(
      text: _readOptionalSetting('nutritionGoalCalories'),
    );
    _proteinGoalController = TextEditingController(
      text: _readOptionalSetting('nutritionGoalProtein'),
    );
    _carbsGoalController = TextEditingController(
      text: _readOptionalSetting('nutritionGoalCarbs'),
    );
    _fatGoalController = TextEditingController(
      text: _readOptionalSetting('nutritionGoalFat'),
    );
    _sleepGoalController = TextEditingController(
      text: (_readIntSetting('sleepGoalMinutes', 480) / 60).toStringAsFixed(1),
    );
    _ageController = TextEditingController(text: _readOptionalSetting('age'));
    _maxHeartRateController = TextEditingController(
      text: _readOptionalSetting('maxHeartRate'),
    );
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _displayNameController.dispose();
    _caloriesGoalController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    _fatGoalController.dispose();
    _sleepGoalController.dispose();
    _ageController.dispose();
    _maxHeartRateController.dispose();
    super.dispose();
  }

  Future<void> _testGeminiConnection() async {
    final activeKey = resolveGeminiApiKey(
      savedValue: _geminiApiKeyController.text,
      compiledDefault: kCodeGeminiApiKey,
    ).key;

    if (activeKey == null || activeKey.isEmpty) {
      setState(() {
        _geminiConnectionMessage = 'No Gemini API key is available to test.';
      });
      return;
    }

    setState(() {
      _isTestingGemini = true;
      _geminiConnectionMessage = null;
    });

    try {
      final model = GenerativeModel(model: kGeminiModelName, apiKey: activeKey);
      final response = await model.generateContent([
        Content.text('Reply with only: OK'),
      ]);
      final text = response.text?.trim() ?? '';
      final passed = text.toUpperCase().contains('OK');

      if (!mounted) {
        return;
      }

      setState(() {
        _isTestingGemini = false;
        _geminiConnectionMessage = passed
            ? 'Gemini connection successful.'
            : 'Gemini responded, but the test response was unexpected.';
      });

      if (passed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gemini connection successful.')),
        );
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isTestingGemini = false;
        _geminiConnectionMessage = 'Gemini connection failed: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gemini connection failed: $error')),
      );
    }
  }

  int _readIntSetting(String key, int fallback) {
    final value = _settingsBox.get(key, defaultValue: fallback);
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  String _readStringSetting(String key) {
    final value = _settingsBox.get(key);
    if (value is String) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
    return '';
  }

  String _readOptionalSetting(String key) {
    final value = _settingsBox.get(key);
    if (value is num) {
      return value.toString();
    }
    if (value is String) {
      return value;
    }
    return '';
  }

  void _setDefaultRest(int seconds) {
    setState(() {
      _defaultRestSeconds = seconds;
    });
    _settingsBox.put('defaultRestSeconds', seconds);
  }

  void _setExerciseRest(String key, int seconds) {
    setState(() {
      if (key == 'compoundRestSeconds') {
        _compoundRestSeconds = seconds;
      } else {
        _isolationRestSeconds = seconds;
      }
    });
    _settingsBox.put(key, seconds);
  }

  void _saveNumericGoal(String key, TextEditingController controller) {
    final cleaned = controller.text.trim();
    if (cleaned.isEmpty) {
      _settingsBox.delete(key);
      return;
    }
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      _settingsBox.delete(key);
      return;
    }
    _settingsBox.put(key, parsed);
  }

  void _saveScoreSetting(
    String key,
    TextEditingController controller, {
    double multiplier = 1,
    bool optional = true,
  }) {
    final cleaned = controller.text.trim();
    if (cleaned.isEmpty) {
      if (optional) _settingsBox.delete(key);
      return;
    }
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0 || !parsed.isFinite) {
      return;
    }
    _settingsBox.put(key, (parsed * multiplier).round());
  }

  void _setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    _settingsBox.put(
      'themeMode',
      ForgeTheme.storageValueForThemeMode(themeMode),
    );
  }

  Future<void> _saveDisplayName() async {
    final name = _displayNameController.text.trim();
    if (name.isEmpty || name.length > 20) return;
    await _settingsBox.put('displayName', name);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name updated')));
      setState(() {});
    }
  }

  Future<void> _setCoachNudges(bool enabled) async {
      if (enabled) {
        final granted = await CoachNudgeService.instance.requestPermission();
        if (!mounted) return;
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(CoachCopy.nudgePermissionDenied)),
          );
          return;
        }
      }
      await _settingsBox.put('coachNudgesEnabled', enabled);
      if (!enabled) await CoachNudgeService.instance.cancelAll();
      if (mounted) {
        setState(() {});
        if (enabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(CoachCopy.nudgePermissionGranted)),
          );
        }
      }
  }

  Future<void> _setQuietTime(String key, int current) async {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      );
      if (time == null) return;
      await _settingsBox.put(key, time.hour * 60 + time.minute);
      if (mounted) setState(() {});
  }

  int _quietMinute(String key, int fallback) {
    final value = _settingsBox.get(key);
    return value is num ? value.toInt().clamp(0, 1439) : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final restMinutes = (_defaultRestSeconds / 60).floor();
    final restSeconds = _defaultRestSeconds % 60;
    final keyResolution = resolveGeminiApiKey(
      savedValue: _geminiApiKeyController.text,
      compiledDefault: kCodeGeminiApiKey,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Profile',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _displayNameController,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Name',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveDisplayName(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _displayNameController.text.trim().isEmpty
                    ? null
                    : _saveDisplayName,
                child: const Text('Save name'),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_alt_rounded),
              title: const Text('Friends'),
              subtitle: const Text('Create your profile and share your friend code'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/friends'),
                  builder: (_) => FriendsHomeScreen(
                    displayName: _displayNameController.text.trim(),
                  ),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Show chat button'),
              subtitle: const Text(
                'Keep a floating shortcut to your conversations on screen',
              ),
              value: _settingsBox.get('showChatButton', defaultValue: true)
                  as bool,
              onChanged: (enabled) async {
                await _settingsBox.put('showChatButton', enabled);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {_themeMode},
              onSelectionChanged: (selection) {
                _setThemeMode(selection.first);
              },
            ),
            const SizedBox(height: 16),
            const BannerAdWidget(adUnitId: AdsService.settingsBanner1),
            const SizedBox(height: 16),
            Text(
              'Default Rest Time',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '${restMinutes > 0 ? '${restMinutes}m ' : ''}${restSeconds > 0 || restMinutes == 0 ? '${restSeconds}s' : ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Slider(
              value: _defaultRestSeconds.toDouble(),
              min: 30,
              max: 300,
              divisions: ((300 - 30) ~/ 15),
              label: _formatSeconds(_defaultRestSeconds),
              onChanged: (value) {
                final rounded = (value / 15).round() * 15;
                _setDefaultRest(rounded.clamp(30, 300));
              },
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('30s'), Text('5m')],
            ),
            const SizedBox(height: 20),
            Text(
              'Workout rest presets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Compound · ${_formatSeconds(_compoundRestSeconds)}'),
            Slider(
              value: _compoundRestSeconds.toDouble(),
              min: 30,
              max: 300,
              divisions: 18,
              label: _formatSeconds(_compoundRestSeconds),
              onChanged: (value) => _setExerciseRest(
                'compoundRestSeconds',
                ((value / 15).round() * 15).clamp(30, 300),
              ),
            ),
            Text('Isolation · ${_formatSeconds(_isolationRestSeconds)}'),
            Slider(
              value: _isolationRestSeconds.toDouble(),
              min: 30,
              max: 300,
              divisions: 18,
              label: _formatSeconds(_isolationRestSeconds),
              onChanged: (value) => _setExerciseRest(
                'isolationRestSeconds',
                ((value / 15).round() * 15).clamp(30, 300),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Sleep, strain and recovery estimates',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Optional personal settings help Forge estimate sleep and heart-rate zones. Max heart rate overrides the age-based estimate.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _sleepGoalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Sleep goal (hours)',
                    ),
                    onChanged: (_) => _saveScoreSetting(
                      'sleepGoalMinutes',
                      _sleepGoalController,
                      multiplier: 60,
                      optional: false,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Age (years)',
                    ),
                    onChanged: (_) => _saveScoreSetting('age', _ageController),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _maxHeartRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Max HR override',
                    ),
                    onChanged: (_) => _saveScoreSetting(
                      'maxHeartRate',
                      _maxHeartRateController,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your age to use the 220 minus age max-heart-rate estimate. '
              'Until then, Forge uses a 190 bpm fallback; an override takes precedence.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 28),
            Text(
              'Nutrition goals',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _caloriesGoalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Calories',
                    ),
                    onChanged: (value) {
                      _saveNumericGoal(
                        'nutritionGoalCalories',
                        _caloriesGoalController,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _proteinGoalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Protein (g)',
                    ),
                    onChanged: (value) {
                      _saveNumericGoal(
                        'nutritionGoalProtein',
                        _proteinGoalController,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _carbsGoalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Carbs (g)',
                    ),
                    onChanged: (value) {
                      _saveNumericGoal(
                        'nutritionGoalCarbs',
                        _carbsGoalController,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _fatGoalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Fat (g)',
                    ),
                    onChanged: (value) {
                      _saveNumericGoal('nutritionGoalFat', _fatGoalController);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Optional. Leave any field blank to disable that goal.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 28),
            Text(
              'Gemini API Key',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (kCodeGeminiApiKey.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'API key is configured in code via FORGE_GEMINI_API_KEY. Save a new value in code to override the stored key.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              TextField(
                controller: _geminiApiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Paste your Gemini API key',
                ),
                onChanged: (value) {
                  final cleaned = value.trim();
                  if (cleaned.isEmpty) {
                    _settingsBox.delete('geminiApiKey');
                  } else {
                    _settingsBox.put('geminiApiKey', cleaned);
                  }
                  setState(() {});
                },
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Current source: ${keyResolution.source.label}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isTestingGemini || keyResolution.key == null
                    ? null
                    : _testGeminiConnection,
                icon: _isTestingGemini
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_error_rounded),
                label: Text(
                  _isTestingGemini ? 'Testing...' : 'Test connection',
                ),
              ),
            ),
            if (_geminiConnectionMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _geminiConnectionMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Add the value in code with --dart-define=FORGE_GEMINI_API_KEY=... or set the constant before running the app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const BannerAdWidget(adUnitId: AdsService.settingsBanner2),
            const SizedBox(height: 28),
            Text(
              CoachCopy.settingsCoach,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(CoachCopy.settingsCoachDescription),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(CoachCopy.enableNudges),
              subtitle: const Text(CoachCopy.maxNudgesLabel),
              value: _coachNudgesEnabled,
              onChanged: _setCoachNudges,
            ),
            for (final type in CoachNudgeType.values)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(CoachCopy.nudgeName(type.name)),
                value:
                    _settingsBox.get(
                      'coachNudge${type.name}',
                      defaultValue: true,
                    ) !=
                    false,
                onChanged: _coachNudgesEnabled
                    ? (value) async {
                        await _settingsBox.put('coachNudge${type.name}', value);
                        if (mounted) setState(() {});
                      }
                    : null,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(CoachCopy.quietHours),
              subtitle: const Text('No reminders during this window'),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () => _setQuietTime(
                      'coachQuietStartMinutes',
                      _quietMinute('coachQuietStartMinutes', 22 * 60),
                    ),
                    child: Text(
                      TimeOfDay(
                        hour:
                            _quietMinute('coachQuietStartMinutes', 22 * 60) ~/
                            60,
                        minute:
                            _quietMinute('coachQuietStartMinutes', 22 * 60) %
                            60,
                      ).format(context),
                    ),
                  ),
                  const Text('–'),
                  TextButton(
                    onPressed: () => _setQuietTime(
                      'coachQuietEndMinutes',
                      _quietMinute('coachQuietEndMinutes', 8 * 60),
                    ),
                    child: Text(
                      TimeOfDay(
                        hour:
                            _quietMinute('coachQuietEndMinutes', 8 * 60) ~/ 60,
                        minute:
                            _quietMinute('coachQuietEndMinutes', 8 * 60) % 60,
                      ).format(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes}m ${remainder}s';
  }
}
