import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;
  final AuthService? authService;

  const LoginScreen({super.key, this.onAuthenticated, this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isRegistrationDialogOpen = false;

  AuthService get _authService => widget.authService ?? AuthService.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSubmitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final validationError = _validateCredentials(email, password);
    if (validationError != null) {
      _showError(validationError);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _authService.login(email: email, password: password);
      if (mounted) widget.onAuthenticated?.call();
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createAccount() async {
    if (_isSubmitting || _isRegistrationDialogOpen) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final validationError = _validateCredentials(email, password);
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    _isRegistrationDialogOpen = true;
    final displayName = await _askForDisplayName();
    _isRegistrationDialogOpen = false;
    if (displayName == null || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (mounted) widget.onAuthenticated?.call();
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _forgotPassword() {
    _showError('Password reset is not available yet.');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String? _validateCredentials(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      return 'Enter your email and password.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (password.length > 128) {
      return 'Password must be 128 characters or fewer.';
    }
    return null;
  }

  Future<String?> _askForDisplayName() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _DisplayNameDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),

                // =========================
                // App Logo
                // =========================
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6F95EB),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.mic_none,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Audiary',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF151B2B),
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'AI-Powered Meeting Summarizer',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF737986),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // =========================
                // Welcome
                // =========================
                const Text(
                  'Welcome back 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF151B2B),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Sign in to access your summaries',
                  style: TextStyle(fontSize: 16, color: Color(0xFF737986)),
                ),

                const SizedBox(height: 28),

                // =========================
                // Email
                // =========================
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF303746),
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: const TextStyle(color: Color(0xFF9AA0AC)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E2E7),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF6F95EB),
                        width: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // =========================
                // Password
                // =========================
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF303746),
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(color: Color(0xFF9AA0AC)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),

                    // ปุ่มแสดง/ซ่อน password
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF737986),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E2E7),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF6F95EB),
                        width: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // =========================
                // Forgot Password
                // =========================
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F89E8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // =========================
                // Sign In Button
                // =========================
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F95EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Sign In'),
                  ),
                ),

                const SizedBox(height: 12),

                // =========================
                // Create Account
                // =========================
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F4FD),
                      foregroundColor: const Color(0xFF5F89E8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // =========================
                // Terms & Privacy
                // =========================
                Center(
                  child: Text(
                    'By signing in you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog();

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final displayName = _controller.text.trim();
    if (displayName.isEmpty) {
      setState(() => _errorText = 'Enter a display name.');
      return;
    }
    if (displayName.length > 100) {
      setState(
        () => _errorText = 'Display name must be 100 characters or fewer.',
      );
      return;
    }
    Navigator.of(context).pop(displayName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create account'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: 'Display name',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }
}
