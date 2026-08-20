import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/account_recovery_service.dart';
import 'login_auth_field.dart';

enum _ForgotStep { gmail, verify, reset, done }

/// Unified Gmail OTP recovery for students, officers, and admins.
Future<String?> showForgotPasswordDialog(
  BuildContext context, {
  required AccountRecoveryService accountRecovery,
  String initialGmail = '',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _ForgotPasswordDialog(
        accountRecovery: accountRecovery,
        initialGmail: initialGmail,
      );
    },
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.accountRecovery,
    required this.initialGmail,
  });

  final AccountRecoveryService accountRecovery;
  final String initialGmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  _ForgotStep _step = _ForgotStep.gmail;
  final _gmailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _sendingCode = false;
  String? _error;
  String? _success;
  String? _codeMessage;
  String _displayName = '';
  String _maskedEmail = '';
  String _loginIdAfterReset = '';

  @override
  void initState() {
    super.initState();
    _gmailController.text = widget.initialGmail;
    _codeController.addListener(_onFieldChanged);
    _newPasswordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _codeController.removeListener(_onFieldChanged);
    _newPasswordController.removeListener(_onFieldChanged);
    _confirmPasswordController.removeListener(_onFieldChanged);
    _gmailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitSendCode() async {
    setState(() {
      _error = null;
      _success = null;
      _sendingCode = true;
    });

    final lookup = widget.accountRecovery.lookupAccountByGmail(_gmailController.text);
    if (!lookup.success) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = lookup.error;
      });
      return;
    }

    _displayName = lookup.displayName ?? '';
    _maskedEmail = lookup.maskedEmail ?? '';

    final result = await widget.accountRecovery.sendRecoveryCode(_gmailController.text);

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _sendingCode = false;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _sendingCode = false;
      _maskedEmail = result.maskedEmail ?? _maskedEmail;
      _codeMessage = 'A password reset email was sent to $_maskedEmail. Open the link, then paste it here.';
      _step = _ForgotStep.verify;
    });
  }

  Future<void> _submitVerify() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final result = await widget.accountRecovery.verifyRecoveryCode(
      _gmailController.text,
      _codeController.text,
    );

    if (!mounted) return;

    if (!result.valid) {
      setState(() {
        _submitting = false;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _step = _ForgotStep.reset;
    });
  }

  Future<void> _submitReset() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final result = await widget.accountRecovery.resetPassword(
      _gmailController.text,
      _codeController.text,
      _newPasswordController.text,
      _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _submitting = false;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _step = _ForgotStep.done;
      _success = 'Your password has been reset. You can now sign in with your new password.';
      _loginIdAfterReset = result.loginId ?? _gmailController.text.trim();
    });
  }

  void _finish() {
    Navigator.of(context).pop(
      _loginIdAfterReset.isNotEmpty ? _loginIdAfterReset : _gmailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.loginFieldBg,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recover account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step == _ForgotStep.gmail) ...[
                      Text(
                        'Enter your Gmail address. A password reset email will be sent to your inbox.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      LoginAuthField(
                        label: 'Gmail address',
                        controller: _gmailController,
                        hint: 'you@gmail.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                    if (_step == _ForgotStep.verify) ...[
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                          children: [
                            if (_displayName.isNotEmpty) ...[
                              const TextSpan(text: 'Account found for '),
                              TextSpan(
                                text: _displayName,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const TextSpan(text: '. Paste the reset link sent to '),
                            ] else
                              const TextSpan(text: 'Paste the reset link sent to '),
                            TextSpan(
                              text: _maskedEmail,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      if (_codeMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _codeMessage!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      LoginAuthField(
                        label: 'Reset link or code',
                        controller: _codeController,
                        hint: 'Paste link from email',
                        prefixIcon: Icons.mark_email_read_outlined,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _sendingCode ? null : _submitSendCode,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.loginRed.withValues(alpha: 0.95),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(_sendingCode ? 'Sending...' : 'Resend email'),
                        ),
                      ),
                    ],
                    if (_step == _ForgotStep.reset) ...[
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                          children: [
                            const TextSpan(text: 'Identity verified. Create a new password'),
                            if (_displayName.isNotEmpty) ...[
                              const TextSpan(text: ' for '),
                              TextSpan(
                                text: _displayName,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LoginAuthField(
                        label: 'New password',
                        controller: _newPasswordController,
                        hint: 'Min 8 characters',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureNew,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          icon: Icon(
                            _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white54,
                            size: 21,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LoginAuthField(
                        label: 'Confirm password',
                        controller: _confirmPasswordController,
                        hint: 'Re-enter new password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white54,
                            size: 21,
                          ),
                        ),
                      ),
                    ],
                    if (_step == _ForgotStep.done) ...[
                      Text(
                        _success ?? '',
                        style: TextStyle(
                          color: AppTheme.green.withValues(alpha: 0.95),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: AppTheme.loginRed.withValues(alpha: 0.95), fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_step == _ForgotStep.gmail) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _sendingCode || _gmailController.text.trim().isEmpty ? null : _submitSendCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(_sendingCode ? 'Sending...' : 'Send reset email'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.verify) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step = _ForgotStep.gmail),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting || _codeController.text.trim().length < 10 ? null : _submitVerify,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Verify link'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.reset) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => setState(() => _step = _ForgotStep.verify),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ||
                                _newPasswordController.text.length < 8 ||
                                _confirmPasswordController.text.length < 8
                            ? null
                            : _submitReset,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Reset password'),
                      ),
                    ),
                  ],
                  if (_step == _ForgotStep.done)
                    Expanded(
                      child: FilledButton(
                        onPressed: _finish,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.loginRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Back to login'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
