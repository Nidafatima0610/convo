import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_button.dart';
import '../../../../core/widgets/convo_card.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    setState(() => _errorMessage = null);
    ref.read(authControllerProvider.notifier).resetError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(email: _emailController.text.trim());

    if (mounted) {
      if (success) {
        setState(() => _isSubmitted = true);
      } else {
        final authState = ref.read(authControllerProvider);
        setState(() {
          _errorMessage =
              authState.error?.toString() ??
              'Could not send reset email. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Reset Password',
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _isSubmitted
                  ? _buildSuccessCard(context)
                  : _buildRequestForm(context, isLoading),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm(BuildContext context, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: AppSpacing.xl),
          if (_errorMessage != null) ...[
            _buildErrorBanner(context, _errorMessage!),
            const SizedBox(height: AppSpacing.lg),
          ],
          ConvoCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password Recovery',
                  style: AppTypography.headlineMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the email address associated with your ${AppConstants.appName} account and we will send you a reset link.',
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Email Address',
                  style: AppTypography.labelMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  enabled: !isLoading,
                  onFieldSubmitted: (_) => _handleReset(),
                  decoration: const InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                if (isLoading)
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.meshGradient,
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                else
                  ConvoButton(
                    label: 'Send Reset Link',
                    icon: Icons.send_rounded,
                    onPressed: _handleReset,
                    variant: ConvoButtonVariant.primaryGradient,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Sign In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_reset_rounded,
            color: context.colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const ConvoBadge(
          label: 'ACCOUNT SECURITY',
          variant: ConvoBadgeVariant.primary,
          icon: Icons.security_rounded,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context) {
    return ConvoCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Check Your Email',
            style: AppTypography.headlineMedium.copyWith(
              color: context.convoColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We have sent a secure password reset link to:',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: context.convoColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _emailController.text.trim(),
            style: AppTypography.titleMedium.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Click the link in the email to set a new password, then return here to sign in.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: context.convoColors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ConvoButton(
            label: 'Back to Sign In',
            icon: Icons.login_rounded,
            onPressed: () => context.pop(),
            variant: ConvoButtonVariant.primaryGradient,
          ),
        ],
      ),
    );
  }
}
