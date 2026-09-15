import 'package:flutter/material.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(
    text: 'admin@fotoboot.local',
  );
  final _passwordController = TextEditingController(
    text: 'admin1234',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go('/camera');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 72,
                          color: AppColors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fotoboot',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: AppColors.red,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Acceso del operador',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password requerido';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (widget.auth.error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.auth.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.redDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const Spacer(),
                        FilledButton(
                          onPressed: widget.auth.busy ? null : _submit,
                          child: widget.auth.busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
