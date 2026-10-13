import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import '../theme.dart';
import '../widgets/ui/primary_gradient_button.dart';

class NameOnboardingScreen extends StatefulWidget {
  const NameOnboardingScreen({
    required this.onContinue,
    super.key,
  });

  final ValueChanged<String> onContinue;

  @override
  State<NameOnboardingScreen> createState() => _NameOnboardingScreenState();
}

class _NameOnboardingScreenState extends State<NameOnboardingScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmedName => _controller.text.trim();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ForgeSpacing.lg),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduceMotion ? Duration.zero : ForgeMotion.cardEntry,
              curve: ForgeMotion.easeOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * ForgeMotion.entryOffset),
                  child: child,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: tokens.primaryGradient,
                        borderRadius: BorderRadius.circular(tokens.cardRadius),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: ForgeSpacing.lg),
                    Text(
                      'What should we call you?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: ForgeSpacing.xs),
                    Text(
                      'Your name will personalize your Forge dashboard.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: ForgeSpacing.lg),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLength: 20,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [LengthLimitingTextInputFormatter(20)],
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _continue(),
                    ),
                    const SizedBox(height: ForgeSpacing.md),
                    PrimaryGradientButton(
                      label: 'Continue',
                      expand: true,
                      onPressed: _trimmedName.isEmpty ? null : _continue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _continue() {
    final name = _trimmedName;
    if (name.isEmpty || !mounted) return;
    widget.onContinue(name);
  }
}
